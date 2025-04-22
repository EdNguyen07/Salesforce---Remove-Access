Id userId = '005bm00000ALSpz'; 

List<ThirdPartyAccountLink> thirdPartyLinks = [
    SELECT Id, SsoProviderId, RemoteIdentifier, UserId
    FROM ThirdPartyAccountLink
    WHERE UserId = :userId 
];

//Get related AuthProvider info
Set<Id> authProviderIds = new Set<Id>();
for (ThirdPartyAccountLink link : thirdPartyLinks) {
    authProviderIds.add(link.SsoProviderId);
}

Map<Id, AuthProvider> authProviderMap = new Map<Id, AuthProvider>(
    [SELECT Id, DeveloperName FROM AuthProvider WHERE Id IN :authProviderIds]
);

// Step 3: Revoke access
for (ThirdPartyAccountLink link : thirdPartyLinks) {
    if (authProviderMap.containsKey(link.SsoProviderId)) {
        AuthProvider provider = authProviderMap.get(link.SsoProviderId);

            Auth.AuthToken.revokeAccess(link.SsoProviderId, provider.DeveloperName, link.UserId, link.RemoteIdentifier);
            System.debug('Revoked access for: ' + link.RemoteIdentifier + ' from Provider: ' + provider.DeveloperName);
      
    }
}
