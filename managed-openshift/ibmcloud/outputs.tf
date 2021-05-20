output "cpd_url" {
  description = "Access your Cloud Pak for Data deployment at this URL."
  value = "https://cpd-tenant-cpd-${var.cpd_project_name}.${module.roks.ingress_hostname}/zen"
}
