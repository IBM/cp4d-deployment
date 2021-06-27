resource "local_file" "dv_cr_yaml" {
  content  = data.template_file.dv_cr.rendered
  filename = "${local.cpd_workspace}/dv_cr.yaml"
}

resource "null_resource" "install_dv" {
  count = var.data_virtualization == "yes" ? 1 : 0
  triggers = {
    namespace             = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Creating DV Operator"
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-dv-case/1.7.0/ibm-dv-case-1.7.0.tgz -P ${self.triggers.cpd_workspace} -A 'ibm-dv-case-1.7.0.tgz'

${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-dv-case-1.7.0.tgz --namespace openshift-marketplace --action installCatalog --inventory dv --tolerance 1
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-dv-case-1.7.0.tgz --namespace ${local.operator_namespace} --action installOperator --inventory dv --tolerance 1
bash cpd/scripts/pod-status-check.sh ibm-dv-operator ${local.operator_namespace}

echo 'Create DV CR'
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-dv-case-1.7.0.tgz --namespace ${var.cpd_namespace} --action applyCustomResources --inventory dv --tolerance 1

echo 'check the DV cr status'
bash cpd/scripts/check-cr-status.sh dvservice dv-service ${var.cpd_namespace} reconcileStatus
EOF
  }
  depends_on = [
    local_file.dv_cr_yaml,
    null_resource.install_analyticsengine,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_wkc,
    null_resource.install_db2wh,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.install_ccs,
    null_resource.login_cluster,
  ]
}