terraform {
  required_version = ">=v0.13.0"
  required_providers {
    ibm = {
         source = "IBM-Cloud/ibm"
         version = "1.33.0"
      }
    kubernetes = "1.13.3"
    null = "~> 3.0"
  }
}

locals {
  cpd_installer_workspace = "${path.root}/installer-files"
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

data "ibm_resource_group" "this" {
  name = var.resource_group_name
}

module "vpc" {
  source = "./vpc"

  # when this is not null, the module doesn't create any resources
  existing_vpc_id           = var.existing_vpc_id
  existing_vpc_subnets      = var.existing_vpc_subnets

  acl_rules                 = var.acl_rules
  enable_public_gateway     = var.enable_public_gateway
  multizone                 = var.multizone
  resource_group_id         = data.ibm_resource_group.this.id
  region                    = var.region
  subnet_ip_range_cidr      = var.subnet_ip_range_cidr
  unique_id                 = var.unique_id
  zone_address_prefix_cidr  = var.zone_address_prefix_cidr
  no_of_zones                 = var.no_of_zones
}

module "roks" {
  source = "./roks"

  cos_instance_crn                = var.cos_instance_crn
  existing_roks_cluster           = var.existing_roks_cluster
  disable_public_service_endpoint = var.disable_public_service_endpoint
  entitlement                     = var.entitlement
  kube_version                    = var.kube_version
  multizone                       = var.multizone
  region                          = var.region
  resource_group_id               = data.ibm_resource_group.this.id
  unique_id                       = var.unique_id
  vpc_id                          = module.vpc.vpc_id
  vpc_subnets                     = module.vpc.vpc_subnets
  worker_node_flavor              = var.worker_node_flavor
  worker_nodes_per_zone           = var.worker_nodes_per_zone
}

module "portworx" {
  source = "./portworx"

  cluster_id           = module.roks.cluster_id
  create_external_etcd = var.create_external_etcd
  ibmcloud_api_key     = var.ibmcloud_api_key
  kube_config_path     = module.roks.kube_config_path
  region               = var.region
  resource_group_id    = data.ibm_resource_group.this.id
  storage_capacity     = var.storage_capacity
  storage_iops         = var.storage_iops
  storage_profile      = var.storage_profile
  unique_id            = var.unique_id
  worker_nodes         = var.multizone ? var.no_of_zones*var.worker_nodes_per_zone : var.worker_nodes_per_zone
}

module "cpd_prereq" {
  source = "./prereq"

  accept_cpd_license    = var.accept_cpd_license
  portworx_is_ready     = module.portworx.portworx_is_ready
  worker_node_flavor    = var.worker_node_flavor
  region                = var.region
  cpd_registry_password = var.cpd_registry_password
  cpd_registry_username = var.cpd_registry_username
  unique_id             = var.unique_id
  ibmcloud_api_key      = var.ibmcloud_api_key
  resource_group_name   = var.resource_group_name
  existing_roks_cluster = var.existing_roks_cluster
}

module "cpd" {
  count                     = var.accept_cpd_license == "yes" ? 1 : 0
  source                    = "./cpd"
  openshift_api             = module.roks.openshift_api
  openshift_username        = var.openshift-username
  openshift_password        = ""
  openshift_token           = module.roks.openshift_token
  installer_workspace       = "${path.module}"
  accept_cpd_license        = var.accept_cpd_license
  cpd_api_key               = var.cpd_registry_password
  cpd_namespace             = var.cpd-namespace
  storage_option            = var.cpd_storageclass
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
  cluster_type              = "managed-ibm"
  configure_global_pull_secret = false
  configure_openshift_nodes    = false

  depends_on = [
    module.cpd_prereq
  ]
}
