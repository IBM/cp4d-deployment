variable "cos_instance_crn" {
  default = null
}

variable "disable_public_service_endpoint" {}

variable "entitlement" {
  default = "cloud_pak"
}

variable "existing_roks_cluster" {
  default = null
}

variable "kube_version" {}

variable "multizone" {}

variable "region" {}

variable "resource_group_id" {}

variable "unique_id" {}

variable "vpc_id" {}

variable "vpc_subnets" {
  type = list
}

variable "worker_node_flavor" {}

variable "worker_nodes_per_zone" {}
