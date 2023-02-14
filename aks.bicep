param aks_cluster_name_prefix string = 'aks-'
param key_vault_name_prefix string = 'akv-'
param key_vault_location string = 'northcentralus'
param aks_cluster_location string = 'westus2'
param aks_node_sku string = 'standard_b4ms'
param k8s_user_assigned_id string = 'k8sid-'
param aks_aad_admin string
param associate bool = false
param inbound_ip_ranges array = ['127.0.0.1']
param user_outbound_fqdns array = ['my-webhook.my-company.com']
param perimeter_name_prefix string = 'nsp-'
param perimeter_location string = 'centraluseuap'

module nsp 'nsp.bicep' = {
  name: 'nsp'
  params: {
    inbound_ip_ranges: inbound_ip_ranges
    user_outbound_fqdns: user_outbound_fqdns
    perimeter_name_prefix: perimeter_name_prefix
    perimeter_location: perimeter_location
  }
}

module k8sidentity 'identity.bicep' = {
  name: 'k8sidentity'
  params: {
    id_prefix: k8s_user_assigned_id
    identity_region: aks_cluster_location
  }
}

module akv 'akv.bicep' = {
  name: 'akv'
  params: {
    key_vault_name_prefix: key_vault_name_prefix
    key_vault_location: key_vault_location
    k8s_identity_id: k8sidentity.outputs.principal_id
    deploy_secret: true
    public_network_access: associate ? 'SecuredByPerimeter' : 'Enabled'
  }
}

resource securedAKS 'Microsoft.ContainerService/managedClusters@2022-10-02-preview' = {
  name: '${aks_cluster_name_prefix}${uniqueString(resourceGroup().id, aks_cluster_location)}'
  location: aks_cluster_location
  dependsOn: [k8sidentity, akv]
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId(resourceGroup().name, 'Microsoft.ManagedIdentity/userAssignedIdentities', '${k8s_user_assigned_id}${uniqueString(resourceGroup().id, aks_cluster_location, k8s_user_assigned_id)}')}': {}
    }
  }
  properties: {
    dnsPrefix: 'aks-kms-secured'
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: 1
        vmSize: aks_node_sku
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        maxPods: 110
        type: 'VirtualMachineScaleSets'
        maxCount: 5
        minCount: 1
        enableAutoScaling: true
        mode: 'System'
        osType: 'Linux'
        osSKU: 'Ubuntu'
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    enableRBAC: true
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'Standard'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: [
        aks_aad_admin
      ]
    }
    publicNetworkAccess: associate ? 'SecuredByPerimeter' : 'Disabled'
    securityProfile: {
      azureKeyVaultKms: {
        enabled: true
        keyId: akv.outputs.secret_uri
        keyVaultNetworkAccess: 'Public'
      }
    }
  }
}

/* keyvault reject ARM deployment after NSP enabling.
{ "error": {"code": "ForbiddenByNsp", "message": "[ForbiddenByNsp (Forbidden)] The request was forbidden by NSP policy. Caller: name=KeyVault/ManagementPlane;appid=c44b4083-3bb0-49c1-b47d-974e53cbdf3c;oid=f31399da-e7ed-4fe4-a825-a9dff4f53481" }

module akv_into_nsp 'association.bicep' = {
  name: 'akv_into_nsp'
  params: {
    resource_id: akv.outputs.resource_id
    perimeter_name_prefix: perimeter_name_prefix
    perimeter_location: perimeter_location
    association_name: 'akv_in_nsp'
  }
}

module aks_into_nsp 'association.bicep' = {
  name: 'aks_into_nsp'
  params: {
    aks_cluster_location: securedAKS.id
    perimeter_name_prefix: perimeter_name_prefix
    perimeter_location: perimeter_location
    association_name: 'aks_in_nsp'
  }
}
*/