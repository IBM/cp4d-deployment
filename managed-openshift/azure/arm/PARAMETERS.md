### Description of all the parameters used in the AzureDeploy.json

| Parameters             | Default       | Description          |
| --------------------- | :-----------: | -------------------- |
| `aadClientId` | - | Azure Client ID. Follow steps [here](https://github.ibm.com/IIG/cpd_terraform/tree/master/azure#steps-to-deploy). The `appId` in the json after the `az ad sp create-for-rbac` command goes here. |
| `aadClientSecret` | - | Azure Client Secret. Follow steps [here](https://github.ibm.com/IIG/cpd_terraform/tree/master/azure#steps-to-deploy). The `password` in the json after the `az ad sp create-for-rbac` command goes here. |
| `clusterName` | myocp | All resources created by the Openshift Installer will have this name as prefix |
| `workerInstanceCount` | 3 | Number of compute nodes. Values: `3/4/5/6/7/8/9/10`. Note that 3 extra nodes are created for OCS dedicated storage|
| `bastionVmSize` | Standard_F8s_v2 | Bootnode instance type. Default has 8vcpus and 32gb RAM. Use [Azure VM sizing](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/sizes) for more information. |
| `masterVmSize` | Standard_F8s_v2 | Master instance type. Default has 8vcpus and 32gb RAM. Use [Azure VM sizing](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/sizes) for more information. Example: `Standard_D8s_v3` |
| `workerVmSize` | Standard_F16s_v2 | Worker instance type. Default has 16vcpus and 64gb RAM. Use [Azure VM sizing](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/sizes) for more information. Example: `Standard_D16s_v3` |
| `pullSecret` | - | The pull secret that you obtained from the [Pull Secret](https://cloud.redhat.com/openshift/install/pull-secret) page on the Red Hat OpenShift Cluster Manager site. You use this pull secret to authenticate with the services that are provided by the included authorities, including Quay.io, which serves the container images for OpenShift Container Platform components. Example: "reference": { "keyVault": { "id": "/subscriptions/SUBSCRIPTION-ID/resourceGroups/RESOURCE-GROUP-NAME/providers/Microsoft.KeyVault/vaults/VAULT-NAME" }, "secretName": "pullsecret" } |
| `adminUsername` | core | Admin username for the bootnode |
| `sshPublicKey` | - | SSH Public key to be included in the bootnode and all the nodes in the cluster. Example: "ssh-rsa AAAAB3Nza..." |
| `storageOption` | ocs | Only OCS storage option is supported for now. |
| `projectName` | zen | Openshift namespace or project to deploy CPD into |
| `apikey` | - | IBM Container Registry API Key |
| `cloudPakLicenseAgreement` | reject | Accept Cloud Pak for Data License Agreement to install below services through Azure Deploy script. Values: `accept/reject` |
| `installDataVirtualization` | no | Install Data Virtualization service. `cloudPakLicenseAgreement` needs to be accepted to install any CPD service. Values: `yes/no`|
| `installWatsonStudioLocal` | no | Install Watson Studio Local service. `cloudPakLicenseAgreement` needs to be accepted to install any CPD service. |
| `installWatsonKnowledgeCatalog` | no | Install Watson Knowledge Catalog service. `cloudPakLicenseAgreement` needs to be accepted to install any CPD service. |
| `installWatsonOpenscale` | no | Install Watson AI Openscale service. `cloudPakLicenseAgreement` needs to be accepted to install any CPD service. |
| `installWatsonMachineLearning` | no | Install Watson Machine Learning service. `cloudPakLicenseAgreement` needs to be accepted to install any CPD service. |
| `installCognosDashboard` | no | Install Cognos Dashboard service. `cloudPakLicenseAgreement` needs to be accepted to install any CPD service. |
| `installApacheSpark` | no | Install Apache Spark service. `cloudPakLicenseAgreement` needs to be accepted to install any CPD service. |


### For Existing VNet 

| Parameters             | Default       | Description          |
| --------------------- | :-----------: | -------------------- |
| `newOrExistingNetwork` | new | Deploy cluster into new or existing network. NOTE: If using existing, you must deploy the cluster into the same region as the network. Values: `new/existing`  |
| `existingVnetResourceGroupName` | resourceGroup().name | If existing network is to be used, enter it's resource group here |
| `virtualNetworkName` | myVNet | Name of new or existing virtual network |
| `virtualNetworkCIDR` | 10.0.0.0/16 | Address space of the virtual network. NOTE: Do not use a 192.* prefixed network, as this is reserved for the serviceNetwork. See [link](https://docs.openshift.com/container-platform/4.3/installing/installing_azure/installing-azure-vnet.html) for more details. |
| `bastionSubnetName` | bastionSubnet | Subnet Name to deploy bootnode VM in. |
| `bastionSubnetPrefix` | 10.0.3.0/27 | Address space to deploy bootnode VM in. |
| `masterSubnetName` | masterSubnet | Subnet Name to deploy control plane nodes in. |
| `masterSubnetPrefix` | 10.0.1.0/24 | Address space to deploy control plane nodes in. |
| `workerSubnetName` | workerSubnet | Subnet Name to deploy control plane nodes in. |
| `workerSubnetPrefix` | 10.0.2.0/24 | Address space to deploy compute nodes in. |
| `apiServerVisibility` | Public | Public or private facing api endpoint Values: `Public/Private`|
| `ingressVisibility` | Public | Public or private facing app endpoints Values: `Public/Private`|