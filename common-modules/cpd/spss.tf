
resource "null_resource" "install_spss" {
  count = var.spss_modeler == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Deploying catalogsources and operator subscriptions for spssmodeler"  &&
bash cpd/scripts/apply-olm.sh ${self.triggers.cpd_workspace} ${var.cpd_version} spss  &&
echo "Create spssmodeler cr" &&
bash cpd/scripts/apply-cr.sh ${self.triggers.cpd_workspace} ${var.cpd_version} spss ${var.cpd_namespace} ${var.storage_option}  ${local.storage_class} ${local.rwo_storage_class}
EOF
  }
  depends_on = [
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
    null_resource.install_aiopenscale,
    null_resource.install_ws,
    null_resource.install_wml,
    null_resource.install_dods,
  ]
}

