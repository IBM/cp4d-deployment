variable "accept_cpd_license" {
  description = "I have read and agree to the license terms for IBM Cloud Pak for Data at https://ibm.biz/BdfEkc [yes/no]"
  
  # validation {
  #   condition = var.accept_cpd_license == "yes"
  #   error_message = "You must read and agree to the license terms for IBM Cloud Pak for Data to proceed."
  # }
}
variable "cluster_id" {}
variable "cpd_project_name" {}
variable "cpd_registry_password" {}
variable "cpd_registry" {}
variable "cpd_registry_username" {}
variable "artifactory_username" {}
variable "artifactory_apikey" {}
variable "entitlement_user" {}
variable "entitlement_key" {}
variable "gituser" {}
variable "git_token" {}
variable "gituser_short" {}
variable "install_services" {}
variable "multizone" {}
variable "portworx_is_ready" {
  type = any
  default = null
}
variable "ibmcloud_api_key" {}
variable "resource_group_name" {}
variable "region" {}
variable "resource_group_id" {}
variable "unique_id" {}
variable "worker_node_flavor" {}
