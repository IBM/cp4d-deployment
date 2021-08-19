resource "local_file" "cde_cr_yaml" {
  content  = data.template_file.cde_cr.rendered
  filename = "${local.cpd_workspace}/cde_cr.yaml"
}

resource "local_file" "cde_sub_yaml" {
  content  = data.template_file.cde_sub.rendered
  filename = "${local.cpd_workspace}/cde_sub.yaml"
}

resource "null_resource" "install_cde" {
  count = var.cognos_dashboard_embedded == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Creating CDE through Subscription"
oc create -f ${self.triggers.cpd_workspace}/cde_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cde-operator ${local.operator_namespace}

echo 'Create CDE CR'
oc create -f ${self.triggers.cpd_workspace}/cde_cr.yaml
sleep 3
echo 'Check the CDE cr status'
bash cpd/scripts/check-cr-status.sh CdeProxyService cde-cr ${var.cpd_namespace} cdeStatus
EOF
  }
  depends_on = [
    local_file.cde_cr_yaml,
    local_file.cde_sub_yaml,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_dv,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}

