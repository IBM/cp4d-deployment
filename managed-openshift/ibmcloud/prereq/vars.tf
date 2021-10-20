variable "accept_cpd_license" {
  description = "I have read and agree to the license terms for IBM Cloud Pak for Data at https://ibm.biz/BdfEkc [yes/no]"
  
}

variable "portworx_is_ready" {
  type = any
  default = null
}
variable "worker_node_flavor" {}
variable "cpd_registry_password" {}
variable "cpd_registry_username" {}
variable "ibmcloud_api_key" {}
variable "unique_id" {}
variable "resource_group_name" {}
variable "region" {}
variable "existing_roks_cluster" {}