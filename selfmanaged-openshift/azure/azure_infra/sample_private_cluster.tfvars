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
watson_knowledge_catalog     = {"enable":"no", "version":"4.0.5", "channel":"v1.0"}
data_virtualization          = {"enable":"no", "version":"1.7.5", "channel":"v1.7"}
analytics_engine             = {"enable":"no", "version":"4.0.5", "channel":"stable-v1"}
watson_studio                = {"enable":"no", "version":"4.0.5", "channel":"v2.0"}
watson_machine_learning      = {"enable":"no", "version":"4.0.5", "channel":"v1.1"}
watson_ai_openscale          = {"enable":"no", "version":"4.0.5", "channel":"v1"}
spss_modeler                 = {"enable":"no", "version":"4.0.5", "channel":"v1.0"}
cognos_dashboard_embedded    = {"enable":"no", "version":"4.0.5", "channel":"v1.0"}
datastage                    = {"enable":"no", "version":"4.0.5", "channel":"v1.0"}
db2_warehouse                = {"enable":"no", "version":"4.0.7", "channel":"v1.0"}
db2_oltp                     = {"enable":"no", "version":"4.0.7", "channel":"v1.0"}
cognos_analytics             = {"enable":"no","version":"4.0.5", "channel":"v4.0"}
data_management_console      = {"enable":"no", "version":"4.0.5", "channel":"v1.0"}
master_data_management       = {"enable":"no", "version":"1.1.175","channel":"v1.1"}
db2_aaservice                = {"enable":"no", "version":"4.0.5", "channel":"v1.0"}
decision_optimization        = {"enable":"no", "version":"4.0.5", "channel":"v4.0"}
bigsql                       = {"enable":"no", "version":"7.2.5", "channel":"v7.2"}
openpages                    = {"enable":"yes","version":"8.204.2","channel":"v1.0" }
watson_discovery             = {"enable":"yes","version":"4.0.5","channel":"v4.0" }
planning_analytics           = {"enable":"yes","version":"4.0.5","channel":"v4.0" }
​
accept-cpd-license = "accept"
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
