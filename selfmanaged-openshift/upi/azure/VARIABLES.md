| Variables             | Default       | Description          |
| --------------------- | :-----------: | -------------------- |
| `azure-subscription-id` | - | Follow steps [here](https://github.com/IBM/cp4d-deployment/tree/master/azure#steps-to-deploy). The `id` in the json after the `az login` command goes here. |
| `azure-client-id` | - | Follow steps [here](https://github.com/IBM/cp4d-deployment/tree/master/azure#steps-to-deploy). The `appId` in the json after the `az ad sp create-for-rbac` command goes here. |
| `azure-client-secret` | - | Follow steps [here](https://github.com/IBM/cp4d-deployment/tree/master/azure#steps-to-deploy). The `password` in the json after the `az ad sp create-for-rbac` command goes here. |
| `azure-tenant-id` | - | Follow steps [here](https://github.com/IBM/cp4d-deployment/tree/master/azure#steps-to-deploy). The `tenant` in the json after the `az ad sp create-for-rbac` command goes here.  |
| `azure-sp-name` | `ocsp` | Please provide the service prinicpal name created by following this [step](https://github.com/IBM/cp4d-deployment/tree/master/azure#steps-to-deploy) |
| `region` | eastus | Choose a region that supports availability zones. See [link](https://docs.microsoft.com/en-us/azure/availability-zones/az-overview#services-support-by-region) |
| `resource-group` | mycpd-rg | Resource Group to contain deployment related resources. |
| `cluster-name` | mycpd-cluster | All resources created by the Openshift Installer will have this name as prefix |
| `dnszone-resource-group` | - | Follow steps [here](https://github.com/IBM/cp4d-deployment/tree/master/azure#steps-to-deploy) to create an App Service Domain. Enter the resource group created. |
| `dnszone` | - | Follow steps [here](https://github.com/IBM/cp4d-deployment/tree/master/azure#steps-to-deploy) to create an App Service Domain. Enter the dnszone name here |
| `new-or-existing` | new | Deploy cluster into new or existing network. NOTE: If using existing, you must deploy the cluster into the same region as the network |
| `existing-vnet-resource-group` | vnet-rg | If existing network is to be used, enter it's resource group here |
| `virtual-network-name` | ocpfourx-vnet | Name of new or existing virtual network |
| `virtual-network-cidr` | 10.11.0.0/16 | Address space of the virtual network. NOTE: Do not use a 192.* prefixed network, as this is reserved for the serviceNetwork. See [link](https://docs.openshift.com/container-platform/4.3/installing/installing_azure/installing-azure-vnet.html) for more details. |
| `bootnode-source-cidr` | 0.0.0.0/0 | Address space to allow SSH connections from. |
| `bootnode-subnet-name` | bootnode-subnet | Subnet Name to deploy bootnode VM in. |
| `bootnode-subnet-cidr` | 10.11.3.0/24 | Address space to deploy bootnode VM in. |
| `cluster-cidr` |10.0.0.0/16 | Address space of the cluster virtual network. This network will be used for deploying master and worker nodes. NOTE: Do not use a 192.* prefixed network, as this is reserved for the serviceNetwork. See [link](https://docs.openshift.com/container-platform/4.3/installing/ |
| `master-subnet-name` | master-subnet | Subnet Name to deploy control plane nodes in. |
| `master-subnet-cidr` | 10.0.0.0/24 | Address space to deploy control plane nodes in. |
| `worker-subnet-name` | worker-subnet | Subnet Name to deploy control plane nodes in. |
| `worker-subnet-cidr` | 10.0.1.0/24 | Address space to deploy compute nodes in. |
| `single-or-multi-zone` | multi | Deploy Openshift Cluster into a single zone or a multi-zone. Ensure the region selected supports Availability Zone. See [link](https://docs.microsoft.com/en-us/azure/availability-zones/az-overview#services-support-by-region). To deploy in a region without Availability Zone support, set variable to `noha` |
| `zone` | 1 | Zone to deploy nodes in. Applicable only if single zone deployment is selected |
| `master-node-count` | 3 | Number of control plane nodes |
| `worker-node-count` | 3 | Number of compute nodes |
| `bootnode-instance-type` | Standard_D8_v3 | Default has 8vcpus and 32gb RAM. Use [Azure VM sizing](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/sizes) for more information. |
| `master-instance-type` | Standard_D8_v3 | Default has 8vcpus and 32gb RAM. Use [Azure VM sizing](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/sizes) for more information. |
| `worker-instance-type` | Standard_D16_v3 | Default has 16vcpus and 64gb RAM. Use [Azure VM sizing](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/sizes) for more information. |
| `pull-secret-file-path` | - | The pull secret that you obtained from the [Pull Secret](https://cloud.redhat.com/openshift/install/pull-secret) page on the Red Hat OpenShift Cluster Manager site. You use this pull secret to authenticate with the services that are provided by the included authorities, including Quay.io, which serves the container images for OpenShift Container Platform components. Example: "/path/to/file/" |
| `fips` | true | If FIPS mode is enabled, the Red Hat Enterprise Linux CoreOS (RHCOS) machines that OpenShift Container Platform runs on bypass the default Kubernetes cryptography suite and use the cryptography modules that are provided with RHCOS instead. |
| `admin-username` | core | Admin username for the bootnode |
| `openshift-username` | - | Desired Openshift username |
| `openshift-password` | - | Desired Openshift password |
| `ssh-public-key` | - | SSH Public key to be included in the bootnode and all the nodes in the cluster. Example: "ssh-rsa AAAAB3Nza..." |
| `ssh-private-key-file-path` | - | Path to the private key file of the corresponding SSH public key used to allow terraform run commands remotely. Example: "/path/to/file/" |
| `private-or-public-cluster` | public | Public or Private. Set publish to Private to deploy a cluster which cannot be accessed from the internet. See [documentation](https://docs.openshift.com/container-platform/4.3/installing/installing_azure/installing-azure-private.html#private-clusters-default_installing-azure-private) for more details. |
| `storage` | nfs | nfs. Storage option to use. For Watson Assistant and Watson Discovery, selecting 'nfs' will install the service on azure-disk storageclass. |
<!-- | `portworx-spec-url` | - | Generate a specification file the [portworx-central](https://central.portworx.com/dashboard). See PORTWORX.md. | -->
| `storage-disk-size` | 1024 | Data disk size. Only applicable for NFS storage |
<!-- | `enableNFSBackup` | no | backup NFS Vm data | -->
| `disconnected-cluster` | no | For creating a disconnected cluster, select yes otherwise no, default if no. |
| `certificate-file-path` | Requires Input | (For disconnected istallation) Path to the domain.crt file which is used while setting up the mirror-registry |
| `local-registry-username` | Requires Input | (For disconnected istallation) Username that you provided for creating the mirror registry. |
| `local-registry-pwd` |  Requires Input  | (For disconnected istallation) Password that you provided for creating the mirror registry.  |
| `local-registry-repository` | Requires Input | (For disconnected istallation) <local_registry>/<local_repository_name> values from the imageContentSources section, from the output of the command for creating mirror registry. Example mirror-node.eastus.cloudapp.azure.com:5000/ocp4/openshift4 |
| `local-registry` | Requires Input | (For disconnected istallation) <local_registry> values from the imageContentSources section, from the output of the command for creating mirror registry. Example mirror-node.eastus.cloudapp.azure.com:5000 |
| `local-repository` | Requires Input | (For disconnected istallation) <local_repository_name> value from you provided during the mirror regitry creation. Example ocp4/openshift4 |
| `architecture` | Requires Input | (For disconnected istallation) architecture value from you provided during the mirror regitry creation. Example x86_64 |
| `mirror-node-resource-group` | Requires Input | (For disconnected istallation) Provide the resource group name where the mirror registry setup is done |
| `mirror-node-vnet-name` | Requires Input | (For disconnected istallation) Provide the vnet name where the mirror registry setup is done |
| `mirror-node-vnet-id` | Requires Input | (For disconnected istallation) Provide the vnet-id where the mirror registry setup is done. Example - subscriptions/(tenant-id)/resourceGroups/(mirror registry resource group name)/providers/Microsoft. Network/virtualNetworks/(mirror registry vnet name) |
| `pull-secret-json-path` | Requires Input | (For disconnected istallation) Provide the path of the pull-secret.json file containing the imagecontentsource details of the mirror registry you created. |
| `cpdservices-to-install` | lite | (For disconnected istallation) Input all the comma separated list of CP4D Service that you want to install. For example, to install the Cloud Pak for Data control plane, Watson Studio and Data Virtualization, specify lite, wsl, dv. At a minimum, you must specify lite. This variable is required to pre-load the images to mirror-registry. CP4D service list currently supported: lite, dv, spark, wkc, wsl, wml, aiopenscale, cde, streams, streams-flows, ds, db2wh, db2oltp, dmc, datagate, dods, ca, spss-modeler, big-sql, pa  |
| `cpd-namespace` | zen | Openshift namespace or project to deploy CPD into |
| `apikey` | - | API Key. Follow steps [here](https://github.com/IBM/cp4d-deployment/tree/master/azure#steps-to-deploy) |
| `ocp_version` | 4.6.13 | Openshift Container Platform version to install |
| `cpd-version` | latest | CPD version to install |
| `cloudctl_version` | v3.6.0 | cloudctl version to use |
| `cpd-cli-version` | v3.5.0 | cpd-cli version to use |
| `data-virtualization` | no | Install Data Virtualization Add-On |
| `watson-studio-library` | no | Install Watson Studio Library Add-On |
| `watson-knowledge-catalog` | no | Install Watson Knowledge Catalog Add-On |
| `watson-ai-openscale` | no | Install Watson AI Openscale Add-On |
| `watson-machine-learning` | no | Install Watson Machine Learning Add-On |
| `spark` | no | Install the Spark Add-on |
| `cognos-dashboard-embedded` | no | Install Cognos Dashboard |
| `streams` | no | Install the Streams Add-on |
| `streams-flows` | no | Install the Streams Flow Add-on  |
| `datastage` | no | Install the datastage Add-on |
| `db2_warehouse` | no | Install the DB2Warehouse Add-on  |
| `db2_oltp` | no | Install the db2 advanced edition Add-on |
| `data-management-console` | no | Install the data management console Add-on  |
| `decision-optimization` | no | Install the Decision Optimization Add-on  |
| `cognos-analytics` | no | Install the Cognos Analytics Add-on  |
| `accept-cpd-license` | reject | Read and accept CloudPak license at https://ibm.biz/Bdq6KP |
| `datagate` | no | Install the Datagate Add-on |
| `spss-modeler` | no | Install the SPSS Modeler Add-on |
| `db2-bigsql` | no | Install the Db2 BigSQL Add-on |
| `planning-analytics` | no | Install the Planning Analytics Add-on |

<!-- | `watson-assistant` | no | Enter `yes` to install the Watson Assistant Add-on service. |
| `watson-discovery` | no | Enter `yes` to install the Watson Discovery Add-on service. |
| `watson-knowledge-studio` | no | Enter `yes` to install the Watson Knowledge Studio Add-on service. |
| `watson-language-translator` | no | Enter `yes` to install the Watson Language Translator Add-on service. |
| `watson-speech` | no | Enter `yes` to install the Watson Speech Add-on service. | -->
