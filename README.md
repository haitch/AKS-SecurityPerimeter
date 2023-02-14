# AKS-SecurityPerimeter

### Create Resources
```
az deployment group create -g nspdemo --template-file aks.bicep -n aks --parameters inbound_ip_ranges='["76.121.92.184/32","167.220.0.0/16"]' aks_aad_admin=<aad_admin_id>
```
also test connection to the AKS and AKV
- aks endpoint should be not reach-able
- akv endpoint should be reachable

### Associate AKS, AKV to NSP
```
az deployment group create -g nspdemo --template-file association.bicep -n association
```

### secure AKS, AKV with PublicNetworkAccess=Disabled
```
az deployment group create -g nspdemo --template-file aks.bicep -n aks --parameters inbound_ip_ranges='["76.121.92.184/32","167.220.0.0/16"]' aks_aad_admin=<aad_admin_id> associate=true
```