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

variable "installer_workspace" {
  type        = string
  description = "Folder to store/find the installation files"
}

variable "region" {
  type = string
  description = "AWS Region the cluster is deployed in"
}

variable "px_encryption" {
  type = bool
  default = true
  description = "Encrypt portworx volumes"
}

variable "px_generated_cluster_name" {
  description = "Storage Cluster name generated from install.portworx.com. See PORTWORX.md for more info"
}

variable "px_namespace" {
  description = "Namespace for Portworx to be deployed"
  default = "kube-system"
}

variable "disk_size" {
  description = "Disk size for each Portworx volume"
  default = 1000
}

variable "kvdb_disk_size" {
  default = 450
}

variable "secret_provider" {
  description = "Encryption secret provider"
  default = "aws-kms"
}

variable "px_enable_monitoring" {
  type = bool
  default = true
  description = "Enable monitoring on PX"
}

variable "px_enable_csi" {
  type = bool
  default = true
  description = "Enable CSI on PX"
}

variable "aws_access_key_id" {
  type = string
}

variable "aws_secret_access_key" {
  type = string
}