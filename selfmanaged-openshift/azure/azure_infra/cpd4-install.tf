locals {
  #General
  cpd-installer-home = "${path.root}/installer-files/cpd4.0"
  cpd-common-files   = "${path.root}/installer-files/cpd4.0/cpd-common-files"
  cpd-repo-url       = "https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case"

  #Storage Classes
  cpd-storageclass = lookup(var.cpd_storageclass, var.storage)
  storagevendor    = var.storage == "nfs" ? "\"\"" : var.storage

  cpd_installer_workspace = "${path.root}/installer-files"
}

module "cpd" {
  count                     = var.accept-cpd-license == "accept" ? 1 : 0
  source                    = "./cpd"
  openshift_api             = var.openshift_api
  openshift_username        = var.openshift-username
  openshift_password        = var.openshift-password
  openshift_token           = ""
  installer_workspace       = local.cpd_installer_workspace
  accept_cpd_license        = var.accept-cpd-license
  cpd_external_registry     = var.cpd-external-registry
  cpd_external_username     = var.cpd-external-username
  cpd_api_key               = var.apikey
  cpd_namespace             = var.cpd-namespace
  cloudctl_version          = var.cloudctl_version
  storage_option            = var.storage
  cpd_version               = var.cpd_version
  cpd_platform              = var.cpd_platform
  data_virtualization       = var.data_virtualization
  analytics_engine          = var.analytics_engine
  watson_knowledge_catalog  = var.watson_knowledge_catalog
  watson_studio             = var.watson_studio
  watson_machine_learning   = var.watson_machine_learning
  watson_ai_openscale       = var.watson_ai_openscale
  cognos_dashboard_embedded = var.cognos_dashboard_embedded
  datastage                 = var.datastage
  db2_warehouse             = var.db2_warehouse
  cognos_analytics          = var.cognos_analytics
  spss_modeler              = var.spss_modeler
  data_management_console   = var.data_management_console
  db2_oltp                  = var.db2_oltp
  master_data_management    = var.master_data_management
  db2_aaservice             = var.db2_aaservice
  decision_optimization     = var.decision_optimization
  bigsql                    = var.bigsql
  openpages                 = var.openpages
  watson_discovery          = var.watson_discovery 
  planning_analytics        = var.planning_analytics
  cluster_type              = "selfmanaged"
  login_string              = "oc login ${var.openshift_api} -u ${var.openshift-username} -p ${var.openshift-password} --insecure-skip-tls-verify=true"

  ### Dev Var ###
  cpd_staging_registry         = var.cpd_staging_registry
  cpd_staging_username         = var.cpd_staging_username
  cpd_staging_api_key          = var.cpd_staging_api_key
  hyc_cloud_private_registry   = var.hyc_cloud_private_registry
  hyc_cloud_private_username   = var.hyc_cloud_private_username
  hyc_cloud_private_api_key    = var.hyc_cloud_private_api_key
  github_ibm_username          = var.github_ibm_username
  github_ibm_pat               = var.github_ibm_pat

  depends_on = [
    null_resource.openshift_post_install,
    module.portworx,
    module.ocs,
    null_resource.install_nfs_client,
  ]
}
