resource "null_resource" "install_aiopenscale" {
  count = var.watson_ai_openscale.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF

echo "Deploying catalogsources and operator subscriptions for watson open scale"
bash cpd/scripts/apply-olm.sh ${self.triggers.cpd_workspace} ${var.cpd_version} wos

echo "Create wos cr"
bash cpd/scripts/apply-cr.sh ${self.triggers.cpd_workspace} ${var.cpd_version} wos ${var.cpd_namespace} ${local.storage_class} ${local.rwo_storage_class}

EOF
  }
  depends_on = [
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
    null_resource.install_wml,
    null_resource.install_ws,
  ]
}

