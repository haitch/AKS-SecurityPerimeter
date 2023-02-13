param id_prefix string = 'id-'
param identity_region string = 'westus2'

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${id_prefix}${uniqueString(resourceGroup().id, identity_region, id_prefix)}'
  location: identity_region
}

output resource_id string = identity.id
output principal_id string = identity.properties.principalId


