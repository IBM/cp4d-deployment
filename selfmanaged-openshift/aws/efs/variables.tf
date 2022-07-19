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

variable "region" {
  type        = string
  description = "AWS Region the cluster is deployed in"
}


variable "vpc_cidr" {
  type = string
  default     = "10.0.0.0/16"
  description  =  "The CIDR block for the VPC, e.g: 10.0.0.0/16"
  
}

variable "vpc_id" {
  type        = string
  description = "AWS VPC"
}
variable "aws_access_key_id" {
  type = string
}

variable "aws_secret_access_key" {
  type = string
}

variable "login_cmd" {
  type = string
  default = "na"
}

variable "az" {
  type = string
  default = "single_zone"
}

variable "cluster_name" {
  type = string
  default = "cpd-cluster-id"
}

variable "installer_workspace" {
  type        = string
  description = "Folder to store/find the installation files"
}

variable "subnet_ids" {
  type = list
}
