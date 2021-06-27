variable "rosa_token" {
  type = string
}

variable "openshift_version" {
  type = string
  default = "4.7.12"
}

variable "worker_machine_type" {
  type = string
  default = "m5.4xlarge"
}

variable "worker_machine_count" {
  type = number
  default = 3
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "multi_zone" {
  type = bool
}

variable "subnet_ids" {
  type = list
}

variable "private_cluster" {
  type = bool
}

variable "cluster_network_cidr" {
    type = string
}

variable "cluster_network_host_prefix" {
  type = number
}

variable "machine_network_cidr" {
  type = string
}

variable "service_network_cidr" {
  type    = string
}

variable "installer_workspace" {
  type        = string
  description = "Folder to store/find the installation files"
}