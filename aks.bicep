param aks_cluster_name_prefix string = 'aks-'
param key_vault_name_prefix string = 'akv-'
param key_vault_location string = 'northcentralus'
param aks_cluster_location string = 'westus2'
param aks_node_sku string = 'standard_b4ms'
param k8s_user_assigned_id string = 'k8sid-'
param aks_aad_admin string
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
    public_network_access: 'Enabled' // AKS provisioning rely on AKV being reachable.
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
    oidcIssuerProfile: {
      enabled: true
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: [
        aks_aad_admin
      ]
    }
    publicNetworkAccess: 'SecuredByPerimeter'
    securityProfile: {
      azureKeyVaultKms: {
        enabled: true
        keyId: akv.outputs.secret_uri
        keyVaultNetworkAccess: 'Public'
      }
    }
  }
}

module associations 'association.bicep' = {
  name: 'aks_akv_into_nsp'
  dependsOn: [akv, nsp, securedAKS]
  params: {
    aks_cluster_name_prefix: aks_cluster_name_prefix
    aks_cluster_location: aks_cluster_location
    perimeter_name_prefix: perimeter_name_prefix
    perimeter_location: perimeter_location
    key_vault_name_prefix: key_vault_name_prefix
    key_vault_location: key_vault_location
  }
}

module akvSecured 'akv.bicep' = {
  name: 'akvSecured'
  dependsOn: [associations] // after association finished we can update keyVault to SecuredByPerimeter
  params: {
    key_vault_name_prefix: key_vault_name_prefix
    key_vault_location: key_vault_location
    k8s_identity_id: k8sidentity.outputs.principal_id
    deploy_secret: true
    public_network_access: 'SecuredByPerimeter'
  }
}