// Execute Anonymous Apex Script to Remove User Access and Deactivate User
Id userId = '005bm00000Cpq8v'; // Replace with actual User Id

// Fetch User fields dynamically
Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get('User').getDescribe().fields.getMap();

// Query all fields (except non-updatable ones)
String fieldsToQuery = '';
for (String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldName).getDescribe();
    if (fieldDesc.isUpdateable()) {
        fieldsToQuery += fieldName + ', ';
    }
}
fieldsToQuery = fieldsToQuery.substring(0, fieldsToQuery.length() - 2); // Remove trailing comma

// Fetch User record
User user = (User)Database.query('SELECT ' + fieldsToQuery + ' FROM User WHERE Id = :userId');

// Set all checkbox fields to false and other fields to null
for (String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldName).getDescribe();
    if (fieldDesc.isUpdateable() && fieldName != 'FirstName' && fieldName != 'LastName') {
        if (fieldDesc.getType() == Schema.DisplayType.Boolean) {
            user.put(fieldName, false);
        } else if (!fieldDesc.isNillable()) {
            continue; // Skip required fields
        } else {
            user.put(fieldName, null);
        }
    }
}

user.IsActive = false;
user.ProfileId = [SELECT Id FROM Profile WHERE Name = 'Read Only' LIMIT 1].Id;
user.UserPreferencesContentNoEmail = true; // Disables Salesforce CRM Content Email Alerts
user.UserPreferencesContentEmailAsAndWhen = false; // Disables Salesforce CRM Content Alerts
user.UserPreferencesDisableAllFeedsEmail = false; // Disables email notifications for feed activity

// Update User
update user;

// Unassign only independent Permission Sets (not assigned via Profile)
List<PermissionSetAssignment> psaList = [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :userId AND PermissionSet.IsOwnedByProfile = FALSE];
delete psaList;

// Remove Permission Set License Assignments
List<PermissionSetLicenseAssign> pslaList = [SELECT Id FROM PermissionSetLicenseAssign WHERE AssigneeId = :userId];
delete pslaList;

// Remove from Public Groups
List<GroupMember> gmList = [SELECT Id FROM GroupMember WHERE UserOrGroupId = :userId];
delete gmList;

// Remove from Queues
List<GroupMember> queueMembers = [SELECT Id FROM GroupMember WHERE UserOrGroupId = :userId AND Group.Type = 'Queue'];
delete queueMembers;

// Query the UserTerritory2Association to find territories assigned to the current user
List<UserTerritory2Association> territoryAssignments = [SELECT Id FROM UserTerritory2Association WHERE UserId = :userId];
if (!territoryAssignments.isEmpty()) {
    // Remove the territory assignments
    delete territoryAssignments;
    System.debug('Territory assignments removed for the user.');
} else {
    System.debug('No territory assignments found for the user.');
}
