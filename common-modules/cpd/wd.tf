resource "local_file" "wd_cr_yaml" {
  content  = data.template_file.wd_cr.rendered
  filename = "${local.cpd_workspace}/wd_cr.yaml"
}

resource "local_file" "wd_sub_yaml" {
  content  = data.template_file.wd_sub.rendered
  filename = "${local.cpd_workspace}/wd_sub.yaml"
}

resource "null_resource" "install_wd" {
  count = var.watson_discovery.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Creating Watson Discovery Operator through Subscription"
oc create -f ${self.triggers.cpd_workspace}/wd_sub.yaml
bash cpd/scripts/pod-status-check.sh wd-discovery-operator ${local.operator_namespace}

echo 'Create Watson Discovery CR'
oc create -f ${self.triggers.cpd_workspace}/wd_cr.yaml
sleep 30
echo 'check the Watson Discovery cr status'
bash cpd/scripts/check-wa-cr-status.sh WatsonDiscovery wd ${var.cpd_namespace} watsonDiscoveryStatus
EOF
  }
  depends_on = [
    null_resource.install_ebd,
    null_resource.install_wa,
    local_file.wd_cr_yaml,
    local_file.wd_sub_yaml,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
