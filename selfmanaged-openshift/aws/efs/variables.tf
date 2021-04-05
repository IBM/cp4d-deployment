variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "efs_name" {
  type = string
}

variable "performance_mode" {
 type =  string
 default = "generalPurpose"
 validation {
   condition     = var.performance_mode == "generalPurpose" || var.performance_mode == "maxIO"
   error_message = "Performance mode can only maxIO/generalPurpose."
 }
}

variable "encrypted" {
  type = bool
  default = true
}

variable "subnets" {
  type        = list(string)
  description = "Subnet IDs for EFS mount targets"
}

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
