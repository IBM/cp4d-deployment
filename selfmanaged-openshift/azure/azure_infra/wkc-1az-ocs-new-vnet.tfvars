## Azure Auth
azure-subscription-id = "<required>"
azure-client-id       = "<required>"
azure-client-secret   = "<required>"
azure-tenant-id       = "<required>"

## Azure topology
region                  = "centralus"
resource-group          = "<required>"
existing-resource-group = "no"
cluster-name            = "<required>"
dnszone-resource-group  = "<required>" # Resource group the DNS group was created in
dnszone                 = "<required>" # DNS Zone created in Step 1 of the Readme
single-or-multi-zone    = "single"

## OpenShift auth & topology
worker-node-count     = 3
pull-secret-file-path = "<required>"
openshift-username    = "ocadmin"
openshift-password    = "<required>"
storage               = "ocs" # ocs or portworx or nfs
ssh-public-key        = "<required>"
apikey                = "<required>"

## CPD services
watson_knowledge_catalog  = { "enable" : "no", "version" : "4.0.4", "channel" : "v1.0" }
data_virtualization       = { "enable" : "no", "version" : "1.7.3", "channel" : "v1.7" }
analytics_engine          = { "enable" : "no", "version" : "4.0.4", "channel" : "stable-v1" }
watson_studio             = { "enable" : "no", "version" : "4.0.4", "channel" : "v2.0" }
watson_machine_learning   = { "enable" : "no", "version" : "4.0.4", "channel" : "v1.1" }
watson_ai_openscale       = { "enable" : "no", "version" : "4.0.4", "channel" : "v1" }
spss_modeler              = { "enable" : "no", "version" : "4.0.4", "channel" : "v1.0" }
cognos_dashboard_embedded = { "enable" : "no", "version" : "4.0.4", "channel" : "v1.0" }
datastage                 = { "enable" : "no", "version" : "4.0.4", "channel" : "v1.0" }
db2_warehouse             = { "enable" : "no", "version" : "4.0.5", "channel" : "v1.0" }
db2_oltp                  = { "enable" : "no", "version" : "4.0.5", "channel" : "v1.0" }
cognos_analytics          = { "enable" : "no", "version" : "4.0.4", "channel" : "v4.0" }
master_data_management    = { "enable" : "no", "version" : "1.1.167", "channel" : "v1.1" }
decision_optimization     = { "enable" : "no", "version" : "4.0.4", "channel" : "v4.0" }
bigsql                    = { "enable" : "no", "version" : "7.2.3", "channel" : "v7.2" }
openpages                 = { "enable" : "no", "version" : "8.204.2","channel": "v1.0" }
watson_discovery          = { "enable" : "no", "version" : "4.0.5", "channel": "v4.0" }
planning_analytics        = { "enable" : "no", "version" : "4.0.5","channel": "v4.0" }

accept-cpd-license = "accept"


###################################  Defaults ###################################

#admin-username               = "core" 
### Network Config
#new-or-existing              = "new" 
#existing-vnet-resource-group = "vnet-rg" 
#virtual-network-name = "ocpfourx-vnet" 
##virtual-network-cidr = "10.0.0.0/16" 

#master-subnet-name = "master-subnet" 
#master-subnet-cidr = "10.0.1.0/24" 
#worker-subnet-name = "worker-subnet" 
#worker-subnet-cidr = "10.0.2.0/24" 

# Deploy OCP into single or multi-zone


# Applicable only if deploying in a single zone
#zone = 1 
#master-node-count = 3 
#master-instance-type = "Standard_D8s_v3" 
#worker-instance-type = "Standard_D16s_v3" 

#fips = true 
#clusterAutoscaler = "no" 
#openshift_api = "" 

# Internet facing endpoints
#private-or-public-cluster = "public" 

#portworx-spec-url = "" 
#portworx-encryption = "no" 
#portworx-encryption-key = "" 
#storage-disk-size = 1024 

#enableNFSBackup = "no" 

# Openshift namespace/project to deploy cloud pak into

#cpd-external-registry = "cp.icr.io" 
#cpd-external-username = "cp" 
#openshift_installer_url_prefix = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp" 
#cloudctl_version = "v3.8.0" 
#ocp_version      = "4.8.11"

##############################
### CPD4.0 variables
##############################

#cpd-namespace           = "zen" 
#operator-namespace      = "ibm-common-services" 
#cpd_storageclass        = { "portworx": "portworx-shared-gp3", "ocs": "ocs-storagecluster-cephfs", "nfs": "nfs" } 
#rwo_cpd_storageclass    = { "portworx": "portworx-db2-rwo-sc", "ocs": "ocs-storagecluster-ceph-rbd", "nfs": "nfs"} 
#cpd_platform            = {"enable":"yes",  "version":"4.0.1", "channel":"v2.0"}
