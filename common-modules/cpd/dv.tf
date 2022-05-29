resource "null_resource" "install_dv" {
  count = var.data_virtualization == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Deploying catalogsources and operator subscriptions for data virtualization" &&
bash cpd/scripts/apply-olm.sh ${self.triggers.cpd_workspace} ${var.cpd_version} dv  &&
echo "Create dv cr"  &&
bash cpd/scripts/apply-cr.sh ${self.triggers.cpd_workspace} ${var.cpd_version} dv ${var.cpd_namespace} ${local.storage_class} ${local.rwo_storage_class}

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
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
    
  ]
}
