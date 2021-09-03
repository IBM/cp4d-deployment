resource "local_file" "dv_cr_yaml" {
  content  = data.template_file.dv_cr.rendered
  filename = "${local.cpd_workspace}/dv_cr.yaml"
}

resource "local_file" "dv_sub_yaml" {
  content  = data.template_file.dv_sub.rendered
  filename = "${local.cpd_workspace}/dv_sub.yaml"
}

resource "null_resource" "install_dv" {
  count = var.data_virtualization == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Create DMC Catalog Source"
oc create -f ${self.triggers.cpd_workspace}/ibm_dmc_catalog_source.yaml

echo "Waiting and checking till the ibm-dmc-operator-catalog is ready in the openshift-marketplace namespace"
bash cpd/scripts/pod-status-check.sh ibm-dmc-operator-catalog openshift-marketplace

echo "Creating DV Operator through Subscription"
oc create -f ${self.triggers.cpd_workspace}/dv_sub.yaml
bash cpd/scripts/pod-status-check.sh ibm-dv-operator ${local.operator_namespace}

echo 'Create DV CR'
oc create -f ${self.triggers.cpd_workspace}/dv_cr.yaml

echo 'check the DV cr status'
bash cpd/scripts/check-cr-status.sh DvService dv-service-cr ${var.cpd_namespace} reconcileStatus
EOF
  }
  depends_on = [
    local_file.dv_cr_yaml,
    local_file.dv_sub_yaml,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
