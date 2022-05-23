openshift_api      = "<required>"
openshift_username = "<required>"
openshift_password = "<required>"
openshift_token    = "<optional>"

#For dev configure_global_pull_secret to icr is false
configure_global_pull_secret = false          # false if pull secret is already created
configure_openshift_nodes    = true          # false if yesdes are already configured
cluster_type                 = "selfmanaged" # managed or selfmanaged

cpd_external_registry = "cp.icr.io"
cpd_external_username = "cp"
cpd_api_key           = ""
cpd_namespace         = "zen"

storage_option = "nfs" # ocs or portworx. if nfs set  variable cpd_storageclass


## CPD services
cpd_version               = "4.5.0"
watson_knowledge_catalog  = { "enable" : "yes", "version" : "4.0.5", "channel" : "v1.0" }
data_virtualization       = { "enable" : "no", "version" : "1.7.5", "channel" : "v1.7" }
analytics_engine          = { "enable" : "no", "version" : "4.0.5", "channel" : "stable-v1" }
watson_studio             = { "enable" : "no", "version" : "4.0.5", "channel" : "v2.0" }
watson_machine_learning   = { "enable" : "no", "version" : "4.0.5", "channel" : "v1.1" }
watson_ai_openscale       = { "enable" : "no", "version" : "4.0.5", "channel" : "v1" }
spss_modeler              = { "enable" : "no", "version" : "4.0.5", "channel" : "v1.0" }
cognos_dashboard_embedded = { "enable" : "no", "version" : "4.0.5", "channel" : "v1.0" }
datastage                 = { "enable" : "no", "version" : "4.0.5", "channel" : "v1.0" }
db2_warehouse             = { "enable" : "no", "version" : "4.0.7", "channel" : "v1.0" }
db2_oltp                  = { "enable" : "no", "version" : "4.0.7", "channel" : "v1.0" }
cognos_analytics          = { "enable" : "no", "version" : "4.0.5", "channel" : "v4.0" }
master_data_management    = { "enable" : "no", "version" : "1.1.175", "channel" : "v1.1" }
decision_optimization     = { "enable" : "no", "version" : "4.0.5", "channel" : "v4.0" }
bigsql                    = { "enable" : "no", "version" : "7.2.5", "channel" : "v7.2" }

accept-cpd-license = "accept"

## Dev vars
cpd_staging_registry = "cp.stg.icr.io"
cpd_staging_username = "cp"
cpd_staging_api_key  = "<required>"
hyc_cloud_private_registry = "hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com"
hyc_cloud_private_username = "<required>"
hyc_cloud_private_api_key = "<required>"
github_ibm_username = "<required>"
github_ibm_pat = "<required>"

