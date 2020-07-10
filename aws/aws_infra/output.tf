output "bootnode_username" {
  description = "bootnode username"
  value       = var.admin-username
}

output "bootnode_dns" {
  description = "The Public DNS allocated for the bootnode"
  value       = aws_instance.bootnode.public_dns
}

output "bootnode_keypair" {
  description = "Key pair to connect bootnode"
  value       = var.key_name
}

output "openshift_console_url" {
  description = "URL for OpenShift web console"
  value       = "https://console-openshift-console.apps.${var.cluster-name}.${var.dnszone}"
}

output "openshift_console_username" {
  description = "username for OpenShift web console"
  value       = "${var.openshift-username}"
}

output "openshift_console_password" {
  description = "password for OpenShift web console"
  value       = "${var.openshift-password}"
}

output "cpd_url" {
  description = "URL for cpd web console"
  value       = "https://${var.cpd-namespace}-cpd-${var.cpd-namespace}.apps.${var.cluster-name}.${var.dnszone}"
}
