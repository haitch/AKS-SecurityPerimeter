param aks_cluster_name_prefix string = 'aks-'
param aks_cluster_location string = 'westus2'
param perimeter_name_prefix string = 'nsp-'
param perimeter_location string = 'centraluseuap'
param key_vault_name_prefix string = 'akv'
param key_vault_location string = 'northcentralus'

resource aks_association 'Microsoft.Network/networkSecurityPerimeters/resourceAssociations@2021-02-01-preview' = {
  name: '${perimeter_name_prefix}${uniqueString(resourceGroup().id, perimeter_location)}/aks_into_nsp'
  properties: {
    privateLinkResource: {
      id: resourceId('Microsoft.ContainerService/managedClusters', '${aks_cluster_name_prefix}${uniqueString(resourceGroup().id, aks_cluster_location)}')
    }
    profile: {
      id: resourceId('Microsoft.Network/networkSecurityPerimeters/profiles', '${perimeter_name_prefix}${uniqueString(resourceGroup().id, perimeter_location)}', 'aksTraffic')
    }
  }
}

resource akv_association 'Microsoft.Network/networkSecurityPerimeters/resourceAssociations@2021-02-01-preview' = {
  name: '${perimeter_name_prefix}${uniqueString(resourceGroup().id, perimeter_location)}/akv_into_nsp'
  properties: {
    privateLinkResource: {
      id: resourceId('Microsoft.KeyVault/vaults', '${key_vault_name_prefix}${uniqueString(resourceGroup().id, key_vault_location)}')
    }
    profile: {
      id: resourceId('Microsoft.Network/networkSecurityPerimeters/profiles', '${perimeter_name_prefix}${uniqueString(resourceGroup().id, perimeter_location)}', 'aksTraffic')
    }
  }
}
