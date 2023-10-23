param perimeter_name_prefix string = 'nsp-'
param perimeter_location string = 'northcentralus'
param storage_account string = 'nspsa'
param shoebox_name string = 'shoebox'
param inbound_ip_ranges array = [ '127.0.0.1' ]
param user_outbound_fqdns array = [ 'my-webhook.my-company.com' ]

resource perimeter 'Microsoft.Network/networkSecurityPerimeters@2021-02-01-preview' = {
  name: '${perimeter_name_prefix}${uniqueString(resourceGroup().id, perimeter_location)}'
  location: perimeter_location
  properties: {}
}

resource aksprofile 'Microsoft.Network/networkSecurityPerimeters/profiles@2021-02-01-preview' = {
  parent: perimeter
  name: 'aksTraffic'
  location: perimeter_location
  properties: {}
}

resource ipInbound 'Microsoft.Network/networkSecurityPerimeters/profiles/accessRules@2021-02-01-preview' = {
  parent: aksprofile
  name: 'ipInbound'
  properties: {
    direction: 'Inbound'
    addressPrefixes: inbound_ip_ranges
  }
}

// resource subInbound 'Microsoft.Network/networkSecurityPerimeters/profiles/accessRules@2021-02-01-preview' = {
//   parent: aksprofile
//   name: 'subInbound'
//   properties: {
//     direction: 'Inbound'
//     subscriptions: [
//       { id: '${subscription().id}' }
//     ]
//   }
// }

// resource userOutbound 'Microsoft.Network/networkSecurityPerimeters/profiles/accessRules@2021-02-01-preview' = {
//   parent: aksprofile
//   name: 'userOutbound'
//   properties: {
//     direction: 'Outbound'
//     fullyQualifiedDomainNames: user_outbound_fqdns
//   }
// }

resource sa 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: '${storage_account}${uniqueString(resourceGroup().id)}'
  location: perimeter_location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource shoebox 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${shoebox_name}${uniqueString(resourceGroup().id)}'
  properties: {
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    storageAccountId: '${resourceId(resourceGroup().name, 'Microsoft.Storage/storageAccounts', '${storage_account}${uniqueString(resourceGroup().id)}')}'
  }
  scope: perimeter
  dependsOn: [ perimeter, sa ]
}

output resource_id string = perimeter.id
