resource "local_file" "cde_cr_yaml" {
  content  = data.template_file.cde_cr.rendered
  filename = "${local.cpd_workspace}/cde_cr.yaml"
}

resource "null_resource" "install_cde" {
  count = var.cognos_dashboard_embedded == "yes" ? 1 : 0
  triggers = {
    namespace             = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Install CDE Operator"
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cde-2.0.0.tgz -P ${self.triggers.cpd_workspace} -A 'ibm-cde-2.0.0.tgz'
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-cde-2.0.0.tgz --namespace ${local.operator_namespace} --action installOperator --inventory cdeOperatorSetup --tolerance 1
bash cpd/scripts/pod-status-check.sh ibm-cde-operator ${local.operator_namespace}

echo "CDE CR"
oc create -f ${self.triggers.cpd_workspace}/cde_cr.yaml
echo 'check the CDE cr status'
bash cpd/scripts/check-cr-status.sh CdeProxyService cde-cr ${var.cpd_namespace} cdeStatus
EOF
  }
  depends_on = [
    local_file.cde_cr_yaml,
    null_resource.install_analyticsengine,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_wkc,
    null_resource.install_db2wh,
    null_resource.install_dv,
    null_resource.install_dmc,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.install_ccs,
    null_resource.login_cluster,
  ]
}