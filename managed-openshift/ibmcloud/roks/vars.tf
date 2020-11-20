variable "cos_instance_crn" {
  description = "You may pass an existing Cloud Object Storage bucket, else the module will create a one."
  default = null
}

variable "disable_public_service_endpoint" {}

variable "entitlement" {
  default = "cloud_pak"
}

variable "kube_version" {
  default = "4.5_openshift"
}

variable "multizone" {}

variable "region" {}

variable "resource_group_id" {}

variable "unique_id" {}

variable "vpc_id" {}

variable "worker_node_flavor" {
  default = "bx2.16x64"
}

variable "worker_nodes_per_zone" {
  description = "Number of initial worker nodes per zone for the ROKS cluster. Select at least 3 for single-zone and at least 2 for multi-zone clusters."
  default = "3"
}

variable "zone_subnet_id_map"{}
