region                          = "<required>"
az                              = "single_zone"
availability_zone1              = "<required>"
access_key_id                   = "<required>"
secret_access_key               = "<required>"
base_domain                     = "<required>"

cluster_name                    = "wkc-1az-ocs-new-vpc"
worker_replica_count            = 3  # set worker_replica_count depending on the cpd services being installed
openshift_pull_secret_file_path = "<required>"
public_ssh_key                  = "<required>"
openshift_username              = "ocadmin"
openshift_password              = "<required>"
accept_cpd_license              = "accept"
cpd_api_key                     = "<required>"

watson_knowledge_catalog  = { "enable" : "no", "version" : "4.0.3", "channel" : "v1.0" }
data_virtualization       = { "enable" : "no", "version" : "1.7.3", "channel" : "v1.7" }
analytics_engine          = { "enable" : "no", "version" : "4.0.3", "channel" : "stable-v1" }
watson_studio             = { "enable" : "no", "version" : "4.0.3", "channel" : "v2.0" }
watson_machine_learning   = { "enable" : "no", "version" : "4.0.3", "channel" : "v1.1" }
watson_ai_openscale       = { "enable" : "no", "version" : "4.0.2", "channel" : "v1" }
spss_modeler              = { "enable" : "no", "version" : "4.0.3", "channel" : "v1.0" }
cognos_dashboard_embedded = { "enable" : "no", "version" : "4.0.3", "channel" : "v1.0" }
datastage                 = { "enable" : "no", "version" : "4.0.3", "channel" : "v1.0" }
db2_warehouse             = { "enable" : "no", "version" : "4.0.3", "channel" : "v1.0" }
db2_oltp                  = { "enable" : "no", "version" : "4.0.3", "channel" : "v1.0" }
cognos_analytics          = { "enable" : "no", "version" : "4.0.3", "channel" : "v4.0" }
master_data_management    = { "enable" : "no", "version" : "1.1.134", "channel" : "v1.1" }
decision_optimization     = { "enable" : "no", "version" : "4.0.3", "channel" : "v4.0" }
planning_analytics        = { "enable" : "no", "version" : "4.0.3", "channel" : "v4.0" }
bigsql                    = { "enable" : "no", "version" : "7.2.3", "channel" : "v7.2" }



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

######################################
# Storage Options: Enable only one   #
######################################
#ocs                 = { enable: true, ami_id: "", dedicated_node_instance_type: "m5.4xlarge"}
#portworx_enterprise = { enable: false, cluster_id: "", enable_encryption: true }
#portworx_essentials = {enable: false, cluster_id: "", user_id: "", osb_endpoint: ""}
#portworx_ibm        = { enable: false, ibm_px_package_path: "" } # absolute file path to the folder containing the cpd*-portworx*.tgz package 

#cpd_platform           = {"enable":"yes",  "version":"4.0.3", "channel":"v2.0"}
#cpd_external_registry   = "cp.icr.io"
#cpd_external_username   = "cp"
#cpd_namespace           = "zen"
#openshift_version       = "4.8.11"
#cloudctl_version        = "v3.7.1"
