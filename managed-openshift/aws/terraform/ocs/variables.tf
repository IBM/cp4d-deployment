variable "openshift_api" {
  type    = string
  default = ""
}

variable "openshift_username" {
  type    = string
  default = ""
}

variable "openshift_password" {
  type    = string
  default = ""
}

variable "openshift_token" {
  type        = string
  description = "For cases where you don't have the password but a token can be generated (e.g SSO is being used)"
  default     = ""
}

variable "installer_workspace" {
  type        = string
  description = "Folder to store/find the installation files"
}

variable "cluster_name" {
  type = string
}

variable "ocs_instance_type" {
  type = string
}

variable "login_cmd" {
  type = string
}
