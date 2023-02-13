param aks_cluster_name string = 'aks'
param aks_aad_admin string
param key_vault_name string = 'akv'
param k8s_user_assigned_id string = 'k8sid-'
param keyvault_region string = 'northcentralus'
param aks_cluster_region string = 'westus2'
param aks_node_sku = "standard_b4ms"
param associate bool = false
param enable_kms = false

module k8sidentity 'identity.bicep' = {
  name: 'k8sidentity'
  params: {
    id_prefix: k8s_user_assigned_id
    identity_region: aks_cluster_region
  }
}

module aks_kms_vault 'secured-kms-vault.bicep' = {
  name: 'aks_kms_vault'
  params: {
    secured_vault_name: key_vault_name
    secured_vault_region: keyvault_region
    k8s_identity_id: k8sidentity.outputs.principal_id
    deploy_secret: true
    public_network_access: 'Enabled'
  }
}

resource securedAKS 'Microsoft.ContainerService/managedClusters@2022-08-02-preview' = {
  name: '${aks_cluster_name}${uniqueString(resourceGroup().id, aks_cluster_region)}'
  location: aks_cluster_region
  dependsOn: [k8sidentity, aks_kms_vault]
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId(resourceGroup().name, 'Microsoft.ManagedIdentity/userAssignedIdentities', '${k8s_user_assigned_id}${uniqueString(resourceGroup().id, aks_cluster_region, k8s_user_assigned_id)}')}': {}
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
    publicNetworkAccess: associate ? 'SecuredByPerimeter' : "Disabled"
    workloadAutoScalerProfile: {
    }
    securityProfile: {
      azureKeyVaultKms: enable_kms ? {
        enabled: enable_kms
        keyId: aks_kms_vault.outputs.secret_uri
        keyVaultNetworkAccess: 'Public'
      }: null
    }
  }
}


