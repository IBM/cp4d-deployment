
resource "null_resource" "install_ebd" {
  count = var.watson_assistant.enable == "yes" || var.watson_discovery.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF

echo "Deploying catalogsources and operator subscriptions for EnterpriseDB Postgres"
bash cpd/scripts/apply-olm.sh ${self.triggers.cpd_workspace} ${var.cpd_version} edb_cp4d

echo "Create EnterpriseDB Postgres cr"
bash cpd/scripts/apply-cr.sh ${self.triggers.cpd_workspace} ${var.cpd_version} edb_cp4d ${var.cpd_namespace} ${local.storage_class} ${local.rwo_storage_class}

EOF
  }
  depends_on = [
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}

