
resource "local_file" "wml_cr_yaml" {
  content  = data.template_file.wml_cr.rendered
  filename = "${local.cpd_workspace}/wml_cr.yaml"
}

resource "local_file" "wml_sub_yaml" {
  content  = data.template_file.wml_sub.rendered
  filename = "${local.cpd_workspace}/wml_sub.yaml"
}

resource "null_resource" "install_wml" {
  count = var.watson_machine_learning.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo 'Create WML sub'
oc apply -f ${self.triggers.cpd_workspace}/wml_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-wml-operator ${local.operator_namespace}

echo 'Create WML CR'
oc apply -f ${self.triggers.cpd_workspace}/wml_cr.yaml
sleep 3
echo 'check the WML cr status'
bash cpd/scripts/check-cr-status.sh WmlBase wml-cr ${var.cpd_namespace} wmlStatus
EOF
  }
  depends_on = [
    local_file.wml_cr_yaml,
    local_file.wml_sub_yaml,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
    null_resource.install_ws,
  ]
}

