provider "aws" {
  version    = "~> 2.0"
  region     = var.region
  access_key = var.access_key_id
  secret_key = var.secret_access_key
}

locals {
  installer_workspace = "${path.root}/installer-files"
}

resource "null_resource" "create_workspace" {
  provisioner "local-exec" {
    command = <<EOF
test -e ${local.installer_workspace} || mkdir -p ${local.installer_workspace}
EOF
  }
}

module "portworx" {
  count               = var.storage_option == "portworx" ? 1 : 0
  source              = "./portworx"
  openshift_api       = var.openshift_api
  openshift_username  = var.openshift_username
  openshift_password  = var.openshift_password
  openshift_token     = var.openshift_token
  portworx_spec_url   = var.portworx_spec_url
  installer_workspace = local.installer_workspace
  region              = var.region
  depends_on = [
    null_resource.create_workspace,
  ]
}

##################################
# OCS IS NOT CURRENTLY SUPPORTED #
##################################

# module "ocs" {
#   count               = var.storage_option == "ocs" ? 1 : 0
#   source              = "./ocs"
#   openshift_api       = var.openshift_api
#   openshift_username  = var.openshift_username
#   openshift_password  = var.openshift_password
#   openshift_token     = var.openshift_token
#   installer_workspace = local.installer_workspace
# }

module "efs" {
  count               = var.storage_option == "efs" ? 1 : 0
  source              = "./efs"
  vpc_id              = var.vpcid
  vpc_cidr            = var.vpc_cidr
  efs_name            = var.efs_name
  openshift_api       = var.openshift_api
  openshift_username  = var.openshift_username
  openshift_password  = var.openshift_password
  openshift_token     = var.openshift_token
  installer_workspace = local.installer_workspace
  region              = var.region
  subnets             = var.subnets

  depends_on = [
    null_resource.create_workspace,
  ]
}

module "cpd" {
  count                     = var.accept_cpd_license == "accept" ? 1 : 0
  source                    = "./cpd"
  vpc_id                    = var.vpcid
  openshift_api             = var.openshift_api
  openshift_username        = var.openshift_username
  openshift_password        = var.openshift_password
  openshift_token           = var.openshift_token
  installer_workspace       = local.installer_workspace
  accept_cpd_license        = var.accept_cpd_license
  cpd_external_registry     = ""
  cpd_external_username     = ""
  api_key                   = var.api_key
  cpd_namespace             = var.cpd_namespace
  cloudctl_version          = var.cloudctl_version
  datacore_version          = var.datacore_version
  storage_option            = var.storage_option
  data_virtualization       = var.data_virtualization
  apache_spark              = var.apache_spark
  watson_knowledge_catalog  = var.watson_knowledge_catalog
  watson_studio_library     = var.watson_studio_library
  watson_machine_learning   = var.watson_machine_learning
  watson_ai_openscale       = var.watson_ai_openscale
  cognos_dashboard_embedded = var.cognos_dashboard_embedded
  streams                   = var.streams
  streams_flows             = var.streams_flows
  datastage                 = var.datastage
  db2_warehouse             = var.db2_warehouse
  db2_advanced_edition      = var.db2_advanced_edition
  data_management_console   = var.data_management_console
  datagate                  = var.datagate
  decision_optimization     = var.decision_optimization
  cognos_analytics          = var.cognos_analytics
  spss_modeler              = var.spss_modeler
  db2_bigsql                = var.db2_bigsql
  planning_analytics        = var.planning_analytics

  depends_on = [
    null_resource.create_workspace,
    module.portworx,
    module.ocs,
    module.efs,
  ]
}
