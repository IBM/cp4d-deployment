variable "cluster_id" {}
variable "create_external_etcd" {}
variable "ibmcloud_api_key" {}
variable "kube_config_path" {
  default = "~/.kube/config"
}
variable "region" {}
variable "resource_group_id" {}
variable "storage_capacity" {}
variable "storage_iops" {}
variable "storage_profile" {}
variable "unique_id" {}
variable "worker_nodes" {}

# These credentials have been hard-coded because the 'Databases for etcd' service instance is not configured to have a publicly accessible endpoint by default.
# You may override these for additional security.
variable "etcd_username" {
  default = "portworxuser"
}
variable "etcd_password" {
  default = "etcdpassword123"
}
variable "etcd_secret_name" {
  default = "px-etcd-certs" # don't change this
}
