resource "null_resource" "install_mdm" {
  count = var.master_data_management.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF

echo "Deploying catalogsources and operator subscriptions for Match 360 with Watson"
bash cpd/scripts/apply-olm.sh ${self.triggers.cpd_workspace} ${var.cpd_version} match360

echo "Create Match 360 with Watson cr"
bash cpd/scripts/apply-cr.sh ${self.triggers.cpd_workspace} ${var.cpd_version} match360 ${var.cpd_namespace} ${local.storage_class} ${local.rwo_storage_class}

EOF
  }
  depends_on = [
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
