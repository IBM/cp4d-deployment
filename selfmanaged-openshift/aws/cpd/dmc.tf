resource "local_file" "dmc_cr_yaml" {
  content  = data.template_file.dmc_cr.rendered
  filename = "${local.cpd_workspace}/dmc_cr.yaml"
}

resource "null_resource" "install_dmc" {
  count = var.data_management_console == "yes" ? 1 : 0
  triggers = {
    namespace             = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Install DMC Operator"
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-dmc-4.0.0.tgz -P ${self.triggers.cpd_workspace} -A 'ibm-dmc-4.0.0.tgz'
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-dmc-4.0.0.tgz --namespace openshift-marketplace --action installCatalog --inventory dmcOperatorSetup --tolerance 1
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-dmc-4.0.0.tgz --namespace ${local.operator_namespace} --action installOperator --inventory dmcOperatorSetup --tolerance 1

echo "DMC CR"
oc create -f ${self.triggers.cpd_workspace}/dmc_cr.yaml
echo 'check the DMC cr status'
bash cpd/scripts/check-cr-status.sh dmcaddon dmcaddon-cr ${var.cpd_namespace} dmcStatus
EOF
  }
  depends_on = [
    local_file.dmc_cr_yaml,
    null_resource.install_analyticsengine,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_wkc,
    null_resource.install_db2wh,
    null_resource.install_dv,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.install_ccs,
    null_resource.login_cluster,
  ]
}