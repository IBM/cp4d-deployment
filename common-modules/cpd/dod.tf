resource "local_file" "dods_cr_yaml" {
  content  = data.template_file.dods_cr.rendered
  filename = "${local.cpd_workspace}/dods_cr.yaml"
}

resource "local_file" "dods_sub_yaml" {
  content  = data.template_file.dods_sub.rendered
  filename = "${local.cpd_workspace}/dods_sub.yaml"
}

resource "null_resource" "install_dods" {
  count = var.decision_optimization.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Creating DO Operator through Subscription"
oc create -f ${self.triggers.cpd_workspace}/dods_sub.yaml
bash cpd/scripts/pod-status-check.sh ibm-cpd-dods-operator ${local.operator_namespace}

echo 'Create DO CR'
oc create -f ${self.triggers.cpd_workspace}/dods_cr.yaml

echo 'check the DO cr status'
bash cpd/scripts/check-cr-status.sh DODS dods-cr ${var.cpd_namespace} dodsStatus
EOF
  }
  depends_on = [
    local_file.dods_cr_yaml,
    local_file.dods_sub_yaml,
    null_resource.install_wml,
    null_resource.install_ws,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
