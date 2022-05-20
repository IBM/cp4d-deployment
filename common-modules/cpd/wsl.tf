
resource "local_file" "ws_cr_yaml" {
  content  = data.template_file.ws_cr.rendered
  filename = "${local.cpd_workspace}/ws_cr.yaml"
}

resource "local_file" "ws_sub_yaml" {
  content  = data.template_file.ws_sub.rendered
  filename = "${local.cpd_workspace}/ws_sub.yaml"
}

resource "null_resource" "install_ws" {
  count = var.watson_studio.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF

echo 'Create ws sub'
oc create -f ${self.triggers.cpd_workspace}/ws_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-ws-operator ${local.operator_namespace}

echo 'Create ws CR'
oc create -f ${self.triggers.cpd_workspace}/ws_cr.yaml
sleep 3
echo 'check the ws cr status'
bash cpd/scripts/check-cr-status.sh ws ws-cr ${var.cpd_namespace} wsStatus
EOF
  }
  depends_on = [
    local_file.ws_cr_yaml,
    local_file.ws_sub_yaml,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}

