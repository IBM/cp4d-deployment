resource "local_file" "wa_cr_ocs_yaml" {
  content  = data.template_file.wa_cr_ocs.rendered
  filename = "${local.cpd_workspace}/wa_cr_ocs.yaml"
}

resource "local_file" "wa_cr_portworx_yaml" {
  content  = data.template_file.wa_cr_portworx.rendered
  filename = "${local.cpd_workspace}/wa_cr_portworx.yaml"
}

resource "local_file" "wa_sub_yaml" {
  content  = data.template_file.wa_sub.rendered
  filename = "${local.cpd_workspace}/wa_sub.yaml"
}

resource "local_file" "wa_temp_patch_yaml" {
  content  = data.template_file.wa_temporary_patch.rendered
  filename = "${local.cpd_workspace}/wa_temp_patch.yaml"
}

resource "null_resource" "install_wa" {
  count = var.watson_assistant.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
oc adm policy add-scc-to-group restricted system:serviceaccounts:${var.cpd_namespace}
echo "Creating Watson Assistant Operator through Subscription"
oc create -f ${self.triggers.cpd_workspace}/wa_sub.yaml
bash cpd/scripts/pod-status-check.sh ibm-watson-assistant-operator ${local.operator_namespace}

echo 'Apply the following temporary fix to allow certificates to be enabled for the Certificate management service'
export INSTANCE=${local.wa_instance}
oc create -f ${self.triggers.cpd_workspace}/wa_temp_patch.yaml
sleep 5

echo 'Create Watson Assistant CR'
oc create -f ${self.triggers.cpd_workspace}/${local.wa_cr}
sleep 3
echo 'check the Watson Assistant cr status'
bash cpd/scripts/check-cr-status.sh WatsonAssistant wa ${var.cpd_namespace} edbStatus
EOF
  }
  depends_on = [
    null_resource.install_ebd,
    local_file.wa_cr_ocs_yaml,
    local_file.wa_cr_portworx_yaml,
    local_file.wa_sub_yaml,
    local_file.wa_temp_patch_yaml,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
