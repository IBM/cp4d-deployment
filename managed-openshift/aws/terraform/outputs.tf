output "login_command" {
  value = module.ocp.login_cmd
}

output "cpd_url" {
  description = "URL for cpd web console"
  value       = "$(oc get routes -n ${var.cpd_namespace})"
}

output "cpd_url_username" {
  description = "Username for CPD Web console"
  value       = "admin"
}

output "cpd_url_password" {
  description = "URL for cpd web console"
  value       = "$(oc extract secret/admin-user-details --keys=initial_admin_password --to=-)"
}
