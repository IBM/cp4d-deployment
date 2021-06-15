variable "openshift_api" {
  type = string
  default = ""
}

variable "openshift_username" {
  type = string
  default = ""
}

variable "openshift_password" {
  type = string
  default = ""
}

variable "openshift_token" {
  type        = string
  description = "For cases where you don't have the password but a token can be generated (e.g SSO is being used)"
  default = ""
}

variable "login_cmd" {
  type = string
  default = ""
}

variable "installer_workspace" {
  type        = string
  description = "Folder find the installation files"
  default = ""
}

variable "accept_cpd_license" {
  description = "Read and accept license at https://ibm.biz/Bdq6KP, (accept / reject)"
  default = "reject"
}

variable "cpd_external_registry" {
  description = "URL to external registry for CPD install. Note: CPD images must already exist in the repo"
  default = ""
}

variable "cpd_external_username" {
  description = "URL to external username for CPD install. Note: CPD images must already exist in the repo"
  default = ""
}

variable "api_key" {
  description = "Repository APIKey or Registry password"
  default = ""
}

variable "cpd_namespace" {
  default = "cpd-tenant"
}

variable "vpc_id" {
  type = string
  default = ""
}

variable "storage_option" {
  type = string
  default = "portworx"
}

variable "cpd_storageclass" {
  type        = map

  default     = {
    "portworx"   = "portworx-shared-gp3"
    "ocs"        = "ocs-storagecluster-cephfs"
  }
}

variable "cpd_version" {
  type = string
  default = "4.0.0"
}

variable "artifactory_username" {
  type = string
  default = ""
}

variable "artifactory_apikey" {
  type = string
  default = ""
}