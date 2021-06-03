variable "rosa_token" {
  type = string
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

variable "public_subnet1_id" {
  type = string
}

variable "public_subnet2_id" {
  type = string
}

variable "public_subnet3_id" {
  type = string
}

variable "private_subnet1_id" {
  type = string
}

variable "private_subnet2_id" {
  type = string
}

variable "private_subnet3_id" {
  type = string
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

variable "openshift_username" {
  type = string
}

variable "openshift_password" {
  type = string
}

variable "enable_autoscaler" {
  type = bool
}
