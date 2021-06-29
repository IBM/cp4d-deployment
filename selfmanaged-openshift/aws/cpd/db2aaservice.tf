
resource "local_file" "db2aaservice_cr_yaml" {
  content  = data.template_file.db2aaservice_cr.rendered
  filename = "${local.cpd_workspace}/db2aaservice_cr.yaml"
}

resource "null_resource" "install_db2aaservice" {
  count = local.db2aaservice == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Db2uaaService"
wget ${local.cpd_case_url}/ibm-db2aaservice-4.0.0.tgz -P ${self.triggers.cpd_workspace} -A 'ibm-db2aaservice-4.0.0.tgz'

${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-db2aaservice-4.0.0.tgz --namespace openshift-marketplace --action installCatalog --inventory db2aaserviceOperatorSetup --tolerance 1
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-db2aaservice-4.0.0.tgz --namespace ${local.operator_namespace} --action installOperator --inventory db2aaserviceOperatorSetup --tolerance 1
bash cpd/scripts/pod-status-check.sh ibm-db2aaservice-cp4d-operator-controller-manager ${local.operator_namespace}

oc create -f ${self.triggers.cpd_workspace}/db2aaservice_cr.yaml
echo "Checking if the Db2uaaService pods are ready and running"
bash cpd/scripts/check-cr-status.sh Db2aaserviceService db2aaservice-cr ${var.cpd_namespace} db2aaserviceStatus
EOF
  }
  depends_on = [
    local_file.wkc_cr_yaml,
    local_file.db2aaservice_cr_yaml,
    null_resource.install_analyticsengine,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_db2wh,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.install_ccs,
    null_resource.login_cluster,
  ]
}
