# AKS-SecurityPerimeter

### Create Resources
```
az deployment group create -g nspdemo --template-file aks.bicep -n aks --parameters inbound_ip_ranges='["76.121.92.184/32","167.220.0.0/16"]' aks_aad_admin=<aad_admin_id>
```
also test connection to the AKS and AKV
- aks endpoint should be not reach-able
- akv endpoint should be reachable 
  - AKS validate AKV is reachable on enabling KMS

### Associate AKS, AKV to NSP
```
az deployment group create -g nspdemo --template-file association.bicep -n association
```

### secure AKS, AKV with PublicNetworkAccess=SecuredByPerimeter
```
az deployment group create -g nspdemo --template-file aks.bicep -n aks --parameters inbound_ip_ranges='["76.121.92.184/32","167.220.0.0/16"]' aks_aad_admin=<aad_admin_id> associate=true
```

### Test
- now AKS is fully regulated by NSP, while talking to KMS within same Perimeter.
- AKS inbound:
  - IP Range based rule
  - Subscription based Rule: 
    - setup a VM with MSI within same subscription
    - use VM MSI token talk to AKS
- AKS outbound
  - inPerimeter traffic
    - verify KMS feature is not broken by create/update secrets.
  - fqdn based outbound
    - AKS runs couple open-source component which does make calls to few selected endpoint, always make sure these endpoint allowed by NSP
      - [guard](https://github.com/kubeguard/guard) talks to 'graph.microsoft.com', 'login.microsoftonline.com', 'sts.windows.net', 'login.windows.net' for AKS AAD enabled clusters.
      - controller-manager talks to ARM 'management.azure.com' for network setup, VM information
      - cluster-auto-scaler talks to ARM 'management.azure.com' for VM scaling
    - Kubernetes does allow user to config webhooks
      - but AKS route those webhooks traffic to the nodes, it's like the request is sent out from konnectivity-agent or tunnel-end pod in kube-system, if desired, config a firewall/dns in the MC_ resource group to inspect/filter the traffic.