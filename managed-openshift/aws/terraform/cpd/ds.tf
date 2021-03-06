resource "local_file" "ds_cr_yaml" {
  content  = data.template_file.ds_cr.rendered
  filename = "${local.cpd_workspace}/ds_cr.yaml"
}

resource "null_resource" "install_ds" {
  count = var.datastage == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Create SCC for WKC-IIS"
oc create -f ${self.triggers.cpd_workspace}/wkc_iis_scc.yaml

echo "Install IIS Operator"
wget ${local.cpd_case_url}/ibm-iis-4.0.0.tgz -P ${self.triggers.cpd_workspace} -A 'ibm-iis-4.0.0.tgz'
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-iis-4.0.0.tgz --tolerance 1 --namespace ${local.operator_namespace} --action installOperator --inventory iisOperatorSetup
bash cpd/scripts/pod-status-check.sh ibm-cpd-iis-operator ${local.operator_namespace}

echo "Create IIS CR"
oc create -f ${self.triggers.cpd_workspace}/wkc_iis_cr.yaml
echo 'check the IIS cr status'
bash cpd/scripts/check-cr-status.sh IIS iis-cr ${var.cpd_namespace} iisStatus

echo "Creating Datastage Operator"
wget ${local.cpd_case_url}/ibm-datastage-4.0.1.tgz -P ${self.triggers.cpd_workspace} -A 'ibm-datastage-4.0.1.tgz'

${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-datastage-4.0.1.tgz --namespace ${local.operator_namespace} --action installOperator --inventory datastageOperatorSetup --tolerance 1
bash cpd/scripts/pod-status-check.sh ibm-datastage-operator ${local.operator_namespace}

echo 'Create Datastage CR'
oc create -f ${self.triggers.cpd_workspace}/ds_cr.yaml

echo 'check the Datastage cr status'
bash cpd/scripts/check-cr-status.sh datastageservice datastage-cr ${var.cpd_namespace} dsStatus
EOF
  }
  depends_on = [
    local_file.ds_cr_yaml,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_cde,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.install_ccs,
    null_resource.login_cluster,
    null_resource.install_db2aaservice,
  ]
}
