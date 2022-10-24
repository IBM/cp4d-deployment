openshift_api      = "<required>"
openshift_username = "<required>"
openshift_password = "<required>"
openshift_token    = "<optional>"


configure_global_pull_secret = true          # false if pull secret is already created
configure_openshift_nodes    = true          # false if nodes are already configured
cluster_type                 = "selfmanaged" # managed or selfmanaged
enable_fips = false

cpd_external_registry = "cp.icr.io"
cpd_external_username = "cp"
cpd_api_key           = "<required>"
cpd_namespace         = "zen"

storage_option = "nfs" # cloud pak for data storage class ocs ,portworx,nfs,efs,efs-ebs


## CPD services
cpd_version               = "4.5.3"
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
planning_analytics        =  "no"
db2_aaservice             =  "no"
watson_assistant          =  "no"
watson_discovery          =  "no"
openpages                 =  "no"
data_management_console   =  "no"

accept-cpd-license = "accept"


