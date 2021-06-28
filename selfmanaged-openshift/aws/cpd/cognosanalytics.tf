resource "local_file" "ca_cr_yaml" {
  content  = data.template_file.ca_cr.rendered
  filename = "${local.cpd_workspace}/ca_cr.yaml"
}

resource "null_resource" "install_ca" {
  count = var.cognos_analytics == "yes" ? 1 : 0
  triggers = {
    namespace             = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Install CA Catalog and Operator"
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cognos-analytics-prod-4.0.0.tgz -P ${self.triggers.cpd_workspace} -A 'ibm-cognos-analytics-prod-4.0.0.tgz'
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-cognos-analytics-prod-4.0.0.tgz --namespace openshift-marketplace --action installCatalog --inventory ibmCaOperatorSetup --tolerance 1
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-cognos-analytics-prod-4.0.0.tgz --namespace ${local.operator_namespace} --action installOperator --inventory ibmCaOperatorSetup --tolerance 1

echo "CA CR"
oc create -f ${self.triggers.cpd_workspace}/ca_cr.yaml
echo 'check the CA cr status'
bash cpd/scripts/check-cr-status.sh CAService ca-cr ${var.cpd_namespace} cdeStatus
EOF
  }
  depends_on = [
    local_file.ca_cr_yaml,
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
    null_resource.install_cde,
  ]
}