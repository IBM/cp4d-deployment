##### AWS Configuration #####
region                = "us-east-1"

access_key_id         = "<required>"
secret_access_key     = "<required>"

##############################

 # Enter the number of availability zones the cluster is to be deployed, default is single zone deployment.
 az                   = "single_zone"

##########
# ROSA
##########

 cluster_name          = "<required>"
 rosa_token            = "<required>"
 worker_machine_type   = "m5.4xlarge"
 worker_machine_count  = 3     # set count depending on number of CPD services
 private_cluster       = false
 ocs                   = { "enable" : "true", "ocs_instance_type" : "m5.4xlarge" }  
#efs                   = { "enable" : "false" } 

#Configure global pull secret is false for dev 
configure_global_pull_secret = false

#Storage 
storage_option = "nfs" # ocs ,portworx,nfs,efs

#############
# CPD Variables
###############

cpd_api_key              = "<required>"
accept_cpd_license       = "accept"
cpd_version               = "4.5.0"
 
## CPD services
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
db2_aaservice             =  "no"
watson_assistant          =  "no"
watson_discovery          =  "no"
openpages                 =  "no"
###############
# Dev Variables
###############
## Dev vars
cpd_staging_registry = "cp.stg.icr.io"
cpd_staging_username = "cp"
cpd_staging_api_key  = "<required>" 
hyc_cloud_private_registry = "hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com"
hyc_cloud_private_username = "<required>"
hyc_cloud_private_api_key = "<required>" 
github_ibm_username = "<required>"
github_ibm_pat = "<required>"

 
