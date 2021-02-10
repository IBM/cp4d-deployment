output "bootnode_ssh_command" {
  description = "The ip address allocated for the bootnode."
  value       = "ssh ${var.admin-username}@${local.bootnode_ip_address}"
}

output "openshift_console_url" {
  description = "URL for OpenShift web console"
  value       = "https://console-openshift-console.apps.${var.cluster-name}.${var.dnszone}"
}

output "openshift_console_username" {
  description = "Username for OpenShift web console"
  value       = var.openshift-username
}

output "openshift_console_password" {
  description = "Password for OpenShift web console"
  value       = var.openshift-password
}

output "cpd_url" {
  description = "URL for cpd web console"
  value       = "https://${var.cpd-namespace}-cpd-${var.cpd-namespace}.apps.${var.cluster-name}.${var.dnszone}"
}