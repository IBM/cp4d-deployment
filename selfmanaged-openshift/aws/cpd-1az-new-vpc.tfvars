region                          = "<required>"
az                              = "single_zone"
availability_zone1              = "<required>"
access_key_id                   = "<required>"
secret_access_key               = "<required>"
base_domain                     = "<required>"

cluster_name                    = "cpd-1az-new-vpc"
worker_replica_count            = 3  # set worker_replica_count depending on the cpd services being installed
openshift_pull_secret_file_path = "<required>"
public_ssh_key                  = "<required>"
openshift_username              = "ocadmin"
openshift_password              = "<required>"
accept_cpd_license              = "accept"
cpd_api_key                     = "<required>"
cpd_version                     = "4.5.3"

watson_knowledge_catalog  =  "no"
data_virtualization       =  "no"
analytics_engine          =  "no"
watson_studio             =  "no"
watson_machine_learning   =  "no"
watson_ai_openscale       =  "no"
spss_modeler              =  "no"
cognos_dashboard_embedded =  "no"
datastage                 =  "no"
db2_warehouse             =  "no"
db2_oltp                  =  "no"
cognos_analytics          =  "no"
master_data_management    =  "no"
decision_optimization     =  "no"
bigsql                    =  "no"
planning_analytics        =  "no"
watson_assistant          =  "no"
watson_discovery          =  "no"
openpages                 =  "no"
data_management_console   =  "no"

######################################
# Storage Options: Enable only one   #
######################################
efs                  = { "enable" : "true" }  #Install efs storage
#ocs                 = { enable: true, ami_id: "", dedicated_node_instance_type: "m5.4xlarge"} #Install ocs storage
#portworx_enterprise = { enable: false, cluster_id: "", enable_encryption: true }
#portworx_essentials = {enable: false, cluster_id: "", user_id: "", osb_endpoint: ""}
#portworx_ibm        = { enable: false, ibm_px_package_path: "" } # absolute file path to the folder containing the cpd*-portworx*.tgz package

storage_option = "efs-ebs" # ocs ,portworx,nfs,efs,efs-ebs ,This storage option is for cpd services to use
##################################################################### DEFAULTS ##################################################################

#key_name                      = "openshift-key"
#tenancy                       = "default"
#new_or_existing_vpc_subnet    = "new"
#availability_zone2            = ""
#availability_zone3            = ""
#enable_permission_quota_check = true

##############################
# New Network
##############################
#vpc_cidr             = "10.0.0.0/16"
#master_subnet_cidr1  = "10.0.0.0/20"
#master_subnet_cidr2  = "10.0.16.0/20"
#master_subnet_cidr3  = "10.0.32.0/20"
#worker_subnet_cidr1  = "10.0.128.0/20"
#worker_subnet_cidr2  = "10.0.144.0/20"
#worker_subnet_cidr3  = "10.0.160.0/20"

##############################
# Existing Network       
##############################
#vpc_id            = ""
#master_subnet1_id = ""
#master_subnet2_id = ""
#master_subnet3_id = ""
#worker_subnet1_id = ""
#worker_subnet2_id = ""
#worker_subnet3_id = ""

#############################
# Existing Openshift Cluster Variables
#############################

#existing_cluster              = false
#existing_openshift_api        = ""
#existing_openshift_username   = ""
#existing_openshift_password.  = ""
#existing_openshift_token      = ""

##################################
# New Openshift Cluster Variables
##################################
#worker_instance_type          = "m5.4xlarge"
#worker_instance_volume_iops   = 2000
#worker_instance_volume_size   = 300
#worker_instance_volume_type   = "io1"
#master_instance_type          = "m5.2xlarge"
#master_instance_volume_iops   = 4000
#master_instance_volume_size   = 300
#master_instance_volume_type   = "io1"
#master_replica_count          = 3
#cluster_network_cidr          = "10.128.0.0/14"
#cluster_network_host_prefix   = 23
#service_network_cidr          = "172.30.0.0/16"
#private_cluster               = false
#enable_fips                   = true
#enable_autoscaler             = false

#cpd_external_registry   = "cp.icr.io"
#cpd_external_username   = "cp"
#cpd_namespace           = "zen"
#openshift_version       = "4.10.15"
