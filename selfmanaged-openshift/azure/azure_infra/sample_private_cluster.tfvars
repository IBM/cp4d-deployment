## Azure Auth
azure-subscription-id = "<required>"
azure-client-id       = "<required>"
azure-client-secret   = "<required>"
azure-tenant-id       = "<required>"
​
## Azure topology
region                  = "centralus"
resource-group          = "<required>"
existing-resource-group = "yes"
cluster-name            = "<required>"
dnszone-resource-group  = "<required>" # Resource group the DNS group was created in
dnszone                 = "<required>" # DNS Zone created in Step 1 of the Readme - private dns zone for private cluster. 
single-or-multi-zone    = "single"
​
## OpenShift auth & topology
worker-node-count     = 3
pull-secret-file-path = "<required>"
openshift-username    = "ocadmin"
openshift-password    = "<required>"
storage               = "ocs" # ocs or portworx or nfs
ssh-public-key        = "<required>"
apikey                = "<required>"
​
## CPD services
​
## ** Note : set enable as "yes" for the services required. 
​
cpd_version               = "4.5.0"
watson_knowledge_catalog  = "no"
data_virtualization       = "no"
analytics_engine          = "no"
watson_studio             = "no"
watson_machine_learning   = "no"
watson_ai_openscale       = "no"
spss_modeler              = "no"
cognos_dashboard_embedded = "no"
datastage                 = "no"
db2_warehouse             = "no"
db2_oltp                  = "no"
cognos_analytics          = "no"
master_data_management    = "no"
decision_optimization     = "no"
bigsql                    = "no"
openpages                 = "no"
watson_discovery          = "no"
planning_analytics        = "no"
​
accept-cpd-license = "accept"

#################################### Dev vars ###################################
cpd_staging_registry = "cp.stg.icr.io"
cpd_staging_username = "cp"
cpd_staging_api_key  = "<required>"
hyc_cloud_private_registry = "hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com"
hyc_cloud_private_username = "<required>"
hyc_cloud_private_api_key = "<required>"
github_ibm_username = "<required>"
github_ibm_pat = "<required>"
##############################

​
new-or-existing              = "<required>"
existing-vnet-resource-group = "<required>" ## Resource group of existing vnet
virtual-network-name = "<required>" ## VNet name
virtual-network-cidr = "<required>" ## Vnet CIDR range 
master-subnet-name = "<required>"
master-subnet-cidr = "<required>"
worker-subnet-name = "<required>"
worker-subnet-cidr = "<required>"
​
# Internet facing endpoints
private-or-public-cluster = "private" ### Specify private for private cluster. 
​
###################################  Defaults ###################################
​
#admin-username               = "core" 
### Network Config
​
# Deploy OCP into single or multi-zone
​
​
# Applicable only if deploying in a single zone
#zone = 1 
​
#master-node-count = 3 
#master-instance-type = "Standard_D8s_v3" 
#worker-instance-type = "Standard_D16s_v3" 
​
#fips = true 
#clusterAutoscaler = "no" 
#openshift_api = "" 
​
#portworx-spec-url = "" 
#portworx-encryption = "no" 
#portworx-encryption-key = "" 
#storage-disk-size = 1024 
​
#enableNFSBackup = "no" 
​
# Openshift namespace/project to deploy cloud pak into
​
#cpd-external-registry = "cp.icr.io" 
#cpd-external-username = "cp" 
#openshift_installer_url_prefix = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp" 
#cloudctl_version = "v3.8.0" 
#ocp_version      = "4.6.31"
​
##############################
### CPD4.0 variables
##############################
​
#cpd-namespace           = "zen" 
#operator-namespace      = "ibm-common-services" 
#cpd_storageclass        = { "portworx": "portworx-shared-gp3", "ocs": "ocs-storagecluster-cephfs", "nfs": "nfs" } 
#rwo_cpd_storageclass    = { "portworx": "portworx-db2-rwo-sc", "ocs": "ocs-storagecluster-ceph-rbd", "nfs": "nfs"} 
#cpd_platform            = {"enable":"yes",  "version":"4.0.1", "channel":"v2.0"}