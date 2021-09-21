resource "local_file" "pa_cr_yaml" {
  content  = data.template_file.pa_cr.rendered
  filename = "${local.cpd_workspace}/pa_cr.yaml"
}

resource "local_file" "pa_sub_yaml" {
  content  = data.template_file.pa_sub.rendered
  filename = "${local.cpd_workspace}/pa_sub.yaml"
}


resource "null_resource" "install_pa" {
  count = var.planning_analytics.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Install Planning Analytics Operator"
oc create -f ${self.triggers.cpd_workspace}/pa_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-planning-analytics-operator ${local.operator_namespace}

echo "PA CR"
oc create -f ${self.triggers.cpd_workspace}/pa_cr.yaml
echo 'check the PA cr status'
bash cpd/scripts/check-cr-status.sh PAService ibm-planning-analytics-service ${var.cpd_namespace} paAddonStatus
EOF
  }
  depends_on = [
    local_file.pa_cr_yaml,
    local_file.pa_sub_yaml,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
