variable "openshift_api" {
  type = string
}

variable "openshift_username" {
  type = string
}

variable "openshift_password" {
  type = string
}

variable "openshift_token" {
  type        = string
  description = "For cases where you don't have the password but a token can be generated (e.g SSO is being used)"
}

variable "portworx_spec_url" {
  type = string
}

variable "installer_workspace" {
  type        = string
  description = "Folder to store/find the installation files"
}

variable "region" {
  type = string
  description = "AWS Region the cluster is deployed in"
}