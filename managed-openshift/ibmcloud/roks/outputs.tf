output "cluster_id" {
  value = data.ibm_container_cluster_config.this.id
  depends_on = [ null_resource.make_kubeconfig_symlink ]
}

output "ingress_hostname" {
  value = data.ibm_container_vpc_cluster.this.ingress_hostname
}

output "kube_config_path" {
  value = data.ibm_container_cluster_config.this.config_file_path
}

output "openshift_token" {
  value = data.ibm_container_cluster_config.this.token
}

output "openshift_api" {
  value = data.ibm_container_cluster_config.this.host
}