
resource "null_resource" "install_ebd" {
  count = var.watson_assistant.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
"oc adm policy add-scc-to-group restricted system:serviceaccounts:${var.cpd_namespace}",
echo 'Create Watson Assistant CR'
cloudctl case save \
--case https://github.com/IBM/cloud-pak/raw/master/repo/case/ibm-watson-assistant-${var.watson_assistant.version}.tgz \
--outputdir ${self.triggers.cpd_workspace}

echo 'Create an EDB License Key for IBM products'
cloudctl case launch \
  --case ${self.triggers.cpd_workspace}/ibm-watson-assistant-${var.watson_assistant.version}.tgz \
  --inventory assistantOperator \
  --action create-postgres-licensekey \
  --namespace ${var.cpd_namespace}

echo 'Install the EDB Cloud Native PostgreSQL operator'
cloudctl case launch \
  --case ${self.triggers.cpd_workspace}/ibm-watson-assistant-${var.watson_assistant.version}.tgz \
  --inventory assistantOperator \
  --action install-postgres-operator \
  --namespace ${var.cpd_namespace} \
  --args "--inputDir ${self.triggers.cpd_workspace}"
sleep 3
bash cpd/scripts/pod-status-check.sh postgresql-operator-controller-manager ${local.operator_namespace}
EOF
  }
  depends_on = [
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}

