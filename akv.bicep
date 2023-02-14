param key_vault_name_prefix string = 'akv-'
param key_vault_location string = 'northcentralus'
param public_network_access string = 'SecuredByPerimeter'
param k8s_identity_id string 
param deploy_secret bool = false

resource securedKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: '${key_vault_name_prefix}${uniqueString(resourceGroup().id, key_vault_location)}'
  location: key_vault_location
  properties: {
    tenantId: tenant().tenantId
    publicNetworkAccess: public_network_access
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: k8s_identity_id
        permissions: {
          keys: [
            'encrypt'
            'decrypt'
          ]
        }
      }
    ]
  }

  resource k8s_secret_encrypt_key 'keys' = if (deploy_secret) {
    name: 'k8s-secret-encrypt-key'
    properties: {
      attributes: {
        enabled: true
        exportable: false
      }
      kty: 'RSA'
    }
  }
}

output secret_uri string = securedKeyVault::k8s_secret_encrypt_key.properties.keyUriWithVersion
output resource_id string = securedKeyVault.id
