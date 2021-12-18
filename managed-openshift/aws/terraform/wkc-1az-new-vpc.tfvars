##### AWS Configuration #####
region                = "us-east-2"

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

#############
# CPD Variables
###############

 cpd_api_key              = "<required>"
 accept_cpd_license       = "accept"

## CPD services
watson_knowledge_catalog  = { "enable" : "yes", "version" : "4.0.3", "channel" : "v1.0" }
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




 
