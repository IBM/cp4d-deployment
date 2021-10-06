openshift_api      = "<required>"
openshift_username = "<required>"
openshift_password = "<required>"
openshift_token    = "<optional>"

configure_global_pull_secret = true          # false if pull secret is already created
configure_openshift_nodes    = true          # false if nodes are already configured
cluster_type                 = "selfmanaged" # managed or selfmanaged

cpd_external_registry = "cp.icr.io"
cpd_external_username = "cp"
cpd_api_key           = "<required>"
cpd_namespace         = "<required>"

storage_option = "<required>" # ocs or portworx. if nfs set  variable cpd_storageclass
#cpd_storageclass            =  { "portworx": "", "ocs" : "", "nfs" : "<nfs storage class>" }

## CPD services

watson_knowledge_catalog  = { "enable" : "no", "version" : "4.0.2", "channel" : "v1.0" }
data_virtualization       = { "enable" : "no", "version" : "1.7.2", "channel" : "v1.7" }
analytics_engine          = { "enable" : "no", "version" : "4.0.2", "channel" : "stable-v1" }
watson_studio             = { "enable" : "no", "version" : "4.0.2", "channel" : "v2.0" }
watson_machine_learning   = { "enable" : "no", "version" : "4.0.2", "channel" : "v1.1" }
watson_ai_openscale       = { "enable" : "no", "version" : "4.0.2", "channel" : "v1" }
spss_modeler              = { "enable" : "no", "version" : "4.0.2", "channel" : "v1.0" }
cognos_dashboard_embedded = { "enable" : "no", "version" : "4.0.2", "channel" : "v1.0" }
datastage                 = { "enable" : "no", "version" : "4.0.2", "channel" : "v1.0" }
db2_warehouse             = { "enable" : "no", "version" : "4.0.2", "channel" : "v1.0" }
db2_oltp                  = { "enable" : "no", "version" : "4.0.2", "channel" : "v1.0" }
cognos_analytics          = { "enable" : "no", "version" : "4.0.2", "channel" : "v4.0" }
master_data_management    = { "enable" : "no", "version" : "4.0.2", "channel" : "v1.1" }
decision_optimization     = { "enable" : "no", "version" : "4.0.2", "channel" : "v4.0" }

accept-cpd-license = "accept"



