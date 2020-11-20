output "cluster_id" {
  value = ibm_container_vpc_cluster.this.id
}

output "oc_host" {
  value = data.ibm_container_cluster_config.this.host
}

output "oc_token" {
  value = data.ibm_container_cluster_config.this.token
}
