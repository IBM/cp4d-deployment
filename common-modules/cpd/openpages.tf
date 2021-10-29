resource "local_file" "op_cr_yaml" {
  content  = data.template_file.op_cr.rendered
  filename = "${local.cpd_workspace}/op_cr.yaml"
}

resource "local_file" "op_sub_yaml" {
  content  = data.template_file.op_sub.rendered
  filename = "${local.cpd_workspace}/op_sub.yaml"
}

resource "null_resource" "install_op" {
  count = var.openpages.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Creating OpenPages Operator through Subscription"
oc create -f ${self.triggers.cpd_workspace}/op_sub.yaml
bash cpd/scripts/pod-status-check.sh ibm-cpd-openpages-operator ${local.operator_namespace}

echo 'Create OpenPages CR'
oc create -f ${self.triggers.cpd_workspace}/op_cr.yaml
sleep 30
echo 'check the OpenPages cr status'
bash cpd/scripts/check-wa-cr-status.sh OpenPagesService openpages ${var.cpd_namespace} openPagesStatus
EOF
  }
  depends_on = [
    null_resource.install_ebd,
    null_resource.install_wa,
    null_resource.install_wd,
    null_resource.install_db2aaservice,
    local_file.op_cr_yaml,
    local_file.op_sub_yaml,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
