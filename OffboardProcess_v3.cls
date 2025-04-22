// === Step 1: Admin-provided list of User IDs ===
// Enter one or more Salesforce User IDs below. Make sure each ID is enclosed in quotes and separated by commas.
// Note: Do NOT add a comma after the last User ID.

List<Id> userIds = new List<Id>{
    '005bm00000Cpq8v', 
    '005bm00000DJxkr',
    '005bm00000DKsPm' // <-- no comma after the last ID
};
    
//***********************************************************************************************//

// 1. Permission Sets from Managed Packages
List<PermissionSetAssignment> permSetAssignments = [
    SELECT Id, AssigneeId, Assignee.Name, PermissionSet.Name
    FROM PermissionSetAssignment
    WHERE AssigneeId IN :userIds 
];

// 2. Permission Set Licenses (often linked to installed packages)
List<PermissionSetLicenseAssign> licenseAssignments = [
    SELECT Id, AssigneeId, Assignee.Name, PermissionSetLicense.MasterLabel
    FROM PermissionSetLicenseAssign
    WHERE AssigneeId IN :userIds 
];

// 3. General info from installed package licenses (org-wide, not per-user, for awareness)
List<PackageLicense> allPackages = [
    SELECT Id, NamespacePrefix, AllowedLicenses, UsedLicenses
    FROM PackageLicense
];

// Output results
System.debug('--- Managed Package Permission Sets ---');
for (PermissionSetAssignment psa : permSetAssignments) {
    System.debug('User: ' + psa.Assignee.Name + ' | PermSet: ' + psa.PermissionSet.Name );
}

System.debug('--- Managed Package Licenses Assigned ---');
for (PermissionSetLicenseAssign psla : licenseAssignments) {
    System.debug('User: ' + psla.Assignee.Name + ' | PSL: ' + psla.PermissionSetLicense.MasterLabel );
}

System.debug('--- Installed Packages in Org ---');
for (PackageLicense pkg : allPackages) {
    System.debug('Package: ' + pkg.NamespacePrefix + ' | Used/Total: ' + pkg.UsedLicenses + '/' + pkg.AllowedLicenses);
}    

Map<Id, User> userNameMap = new Map<Id, User>(
    [SELECT Id, FirstName, LastName FROM User WHERE Id IN :userIds]
);
    
// Check third party account links
for (Id uid : userIds) {
    List<ThirdPartyAccountLink> links = [
        SELECT Id, SsoProviderName 
        FROM ThirdPartyAccountLink 
        WHERE UserId = :uid
    ];
    
    String fullName = userNameMap.containsKey(uid)
        ? userNameMap.get(uid).FirstName + ' ' + userNameMap.get(uid).LastName
        : 'Unknown';
    
    if (links.isEmpty()) {
         System.debug('No third-party account links for user: ' + fullName + ' (' + uid + ')');
    } else {
        for (ThirdPartyAccountLink link : links) {
            System.debug('User ' + fullName + ' (' + uid + ') has Third-Party Link via: ' + link.SsoProviderName);
        }
    }
}
    
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
