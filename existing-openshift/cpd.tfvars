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

storage_option = "nfs" # ocs ,portworx,nfs,efs


## CPD services
cpd_version               = "4.5.0"
watson_knowledge_catalog  =  "yes"
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

