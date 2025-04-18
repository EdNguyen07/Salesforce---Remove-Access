// === Step 1: Admin-provided list of User IDs ===
// Enter one or more Salesforce User IDs below. Make sure each ID is enclosed in quotes and separated by commas.
// Note: Do NOT add a comma after the last User ID.

List<Id> userIds = new List<Id>{
    '005bm00000Cpq8v', 
    '005bm00000DJxkr',
    '005bm00000DKsPm' // <-- no comma after the last ID
};
    
//***********************************************************************************************//

List<User> users = [
    SELECT Id, Name, IsActive, ProfileId, FederationIdentifier, EmployeeNumber,profile.name 
    FROM User 
    WHERE Id IN :userIds
];

// Fetch User fields dynamically
Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get('User').getDescribe().fields.getMap();

// Build list of updateable fields to query
String fieldsToQuery = '';
for (String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult fieldDesc = fieldMap.get(fieldName).getDescribe();
    if (fieldDesc.isUpdateable()) {
        fieldsToQuery += fieldName + ', ';
    }
}
fieldsToQuery = fieldsToQuery.substring(0, fieldsToQuery.length() - 2); // Remove trailing comma

// Collect updated users
String fullQuery = 'SELECT ' + fieldsToQuery + ', Name, Profile.Name FROM User WHERE Id IN :userIds';
List<User> fullUsers = Database.query(fullQuery);

Map<Id, User> fullUserMap = new Map<Id, User>();
for (User u : fullUsers) {
    fullUserMap.put(u.Id, u);
}

List<User> usersToUpdate = new List<User>();
Id readOnlyProfileId = [SELECT Id FROM Profile WHERE Name = 'Read Only' LIMIT 1].Id;

for (User baseUser : users) {
    User user = fullUserMap.get(baseUser.Id);

    // Set all checkbox fields to false and other updatable fields to null
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

    user.IsActive = false; // Deactivate user
    user.ProfileId = readOnlyProfileId; // Assign 'Read Only' profile
    user.UserPreferencesContentNoEmail = true; // Disable content email notifications
    user.UserPreferencesContentEmailAsAndWhen = false; // Disable CRM content alerts
    user.UserPreferencesDisableAllFeedsEmail = false; // Disable feed activity email notifications
    usersToUpdate.add(user);
}
update usersToUpdate;

for (Id uid : userIds) {
    // Remove independent Permission Sets
    List<PermissionSetAssignment> psas = [
        SELECT Id 
        FROM PermissionSetAssignment 
        WHERE AssigneeId = :uid AND PermissionSet.IsOwnedByProfile = FALSE
    ];
    delete psas;

    // Remove Permission Set License Assignments
    List<PermissionSetLicenseAssign> pslas = [
        SELECT Id 
        FROM PermissionSetLicenseAssign 
        WHERE AssigneeId = :uid
    ];
    delete pslas;

    // Remove from Public Groups and Queues
    List<GroupMember> groupMembers = [
        SELECT Id 
        FROM GroupMember 
        WHERE UserOrGroupId = :uid
    ];
    delete groupMembers;

    // Remove Territory Assignments
    List<UserTerritory2Association> territories = [
        SELECT Id 
        FROM UserTerritory2Association 
        WHERE UserId = :uid
    ];
    delete territories;
}

// Print out the User IDs and Names for the users processed
List<User> updatedUsers = [
    SELECT Id, Name, Profile.Name 
    FROM User 
    WHERE Id IN :userIds
];

for (User u : updatedUsers) {
    System.debug('Access removed for User - ID: ' + u.Id + ' | Name: ' + u.Name + ' | New Profile: ' + u.Profile.Name);
}
   
