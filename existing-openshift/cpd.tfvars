openshift_api             = "<required>"
openshift_username        = "<required>"
openshift_password        = "<required>"
openshift_token           = "<optional>"

login_cmd                 = "<optional>"

# login_cmd_set
# configure_ocp

installer_workspace       = "install"
cpd_external_registry     = "cp.icr.io"
cpd_external_username     = "cp"
cpd_api_key               = "<required>"

storage_option            = "ocs"

## CPD services

watson_knowledge_catalog  = { "enable" : "no", "version" : "4.0.1", "channel" : "v1.0" }
data_virtualization       = { "enable" : "no", "version" : "1.7.1", "channel" : "v1.7" }
analytics_engine          = { "enable" : "no", "version" : "4.0.1", "channel" : "stable-v1" }
watson_studio             = { "enable" : "no", "version" : "4.0.1", "channel" : "v2.0" }
watson_machine_learning   = { "enable" : "no", "version" : "4.0.1", "channel" : "v1.1" }
watson_ai_openscale       = { "enable" : "no", "version" : "4.0.1", "channel" : "v1" }
spss_modeler              = { "enable" : "no", "version" : "4.0.1", "channel" : "v1.0" }
cognos_dashboard_embedded = { "enable" : "no", "version" : "4.0.1", "channel" : "v1.0" }
datastage                 = { "enable" : "no", "version" : "4.0.1", "channel" : "v1.0" }
db2_warehouse             = { "enable" : "no", "version" : "4.0.1", "channel" : "v1.0" }
db2_oltp                  = { "enable" : "no", "version" : "4.0.1", "channel" : "v1.0" }
cognos_analytics          = { "enable" : "no", "version" : "4.0.1", "channel" : "v4.0" }
master_data_management    = { "enable" : "no", "version" : "4.0.1", "channel" : "v1.1" }
decision_optimization     = { "enable" : "no", "version" : "4.0.1", "channel" : "v4.0" }

accept-cpd-license        = "accept"

rosa_cluster              = false

