terraform {
  required_version = "v0.12.31"
  required_providers {
    ibm = "1.28.0"
    kubernetes = "1.13.3"
    null = "~> 3.0"
  }
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
  generation       = 2
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

module "cpd_install" {
  source = "./cpd_install"

  accept_cpd_license    = var.accept_cpd_license
  cluster_id            = module.roks.cluster_id
  cpd_project_name      = var.cpd_project_name
  cpd_registry_password = var.cpd_registry_password
  cpd_registry          = var.cpd_registry
  cpd_registry_username = var.cpd_registry_username
  install_services      = var.install_services
  multizone             = var.multizone
  portworx_is_ready     = module.portworx.portworx_is_ready
  region                = var.region
  resource_group_id     = data.ibm_resource_group.this.id
  unique_id             = var.unique_id
  worker_node_flavor    = var.worker_node_flavor
}
