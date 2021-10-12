variable "login_string" {
  type = string
}

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

variable "cluster_type" {
  type = string
}

variable "configure_global_pull_secret" {
  type        = bool
  description = "Configuring global pull secret"
  default     = true
}

variable "configure_openshift_nodes" {
  type        = bool
  description = "Setting machineconfig parameters on worker nodes"
  default     = true
}

variable "installer_workspace" {
  type        = string
  description = "Folder find the installation files"
  default     = ""
}

variable "cpd_external_registry" {
  description = "URL to external registry for CPD install. Note: CPD images must already exist in the repo"
  default     = "cp.icr.io"
}

variable "cpd_external_username" {
  description = "URL to external username for CPD install. Note: CPD images must already exist in the repo"
  default     = "cp"
}

variable "cpd_api_key" {
  description = "Repository APIKey or Registry password"
}