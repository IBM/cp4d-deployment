resource "local_file" "dmc_cr_yaml" {
  content  = data.template_file.dmc_cr.rendered
  filename = "${local.cpd_workspace}/dmc_cr.yaml"
}


resource "local_file" "dmc_sub_yaml" {
  content  = data.template_file.dmc_sub.rendered
  filename = "${local.cpd_workspace}/dmc_sub.yaml"
}


resource "null_resource" "install_dmc" {
  count = var.data_management_console.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF

echo "Install DMC Operator"
oc create -f ${self.triggers.cpd_workspace}/dmc_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-dmc-controller-manager ${local.operator_namespace}

echo "DMC CR"
oc create -f ${self.triggers.cpd_workspace}/dmc_cr.yaml
echo 'check the DMC cr status'
bash cpd/scripts/check-cr-status.sh Dmcaddon data-management-console-addon ${var.cpd_namespace} dmcAddonStatus
EOF
  }
  depends_on = [
    local_file.dmc_cr_yaml,
    local_file.dmc_sub_yaml,
    null_resource.install_dv,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
