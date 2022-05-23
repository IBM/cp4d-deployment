resource "null_resource" "install_db2oltp" {
  count = var.db2_oltp.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF

echo "Deploying catalogsources and operator subscriptions for Db2 oltp"
bash cpd/scripts/apply-olm.sh ${self.triggers.cpd_workspace} ${var.cpd_version} db2oltp


echo "Create Db2 oltp  cr"
bash cpd/scripts/apply-cr.sh ${self.triggers.cpd_workspace} ${var.cpd_version} db2oltp ${var.cpd_namespace} ${local.storage_class} ${local.rwo_storage_class}

EOF
  }
  depends_on = [
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}

