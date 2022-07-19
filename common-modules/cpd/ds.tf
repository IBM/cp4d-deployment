resource "null_resource" "install_ds" {
  count = var.datastage == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Deploying catalogsources and operator subscriptions for datastage" &&
bash cpd/scripts/apply-olm.sh ${self.triggers.cpd_workspace} ${var.cpd_version} datastage_ent_plus &&
echo "Create datastage_ent cr" &&
bash cpd/scripts/apply-cr.sh ${self.triggers.cpd_workspace} ${var.cpd_version} datastage_ent_plus ${var.cpd_namespace} ${var.storage_option} ${local.storage_class} ${local.rwo_storage_class}

EOF
  }
  depends_on = [
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_dods,
    null_resource.install_dmc,
    null_resource.install_bigsql,
    null_resource.install_dv,
    null_resource.install_mdm,
    null_resource.install_cde,
    null_resource.install_wkc,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
