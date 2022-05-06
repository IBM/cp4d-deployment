
resource "local_file" "spss_catalog_yaml" {
  content  = data.template_file.spss_catalog.rendered
  filename = "${local.cpd_workspace}/spss_catalog.yaml"
}
resource "local_file" "spss_cr_yaml" {
  content  = data.template_file.spss_cr.rendered
  filename = "${local.cpd_workspace}/spss_cr.yaml"
}

resource "local_file" "spss_sub_yaml" {
  content  = data.template_file.spss_sub.rendered
  filename = "${local.cpd_workspace}/spss_sub.yaml"
}

resource "null_resource" "install_spss" {
  count = var.spss_modeler.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo 'Create spss sub'
oc apply -f ${self.triggers.cpd_workspace}/spss_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-spss-operator-catalog openshift-marketplace

echo 'Create spss sub'
oc apply -f ${self.triggers.cpd_workspace}/spss_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-spss-operator ${local.operator_namespace}

echo 'Create spss CR'
oc apply -f ${self.triggers.cpd_workspace}/spss_cr.yaml
sleep 3
echo 'check the spss cr status'
bash cpd/scripts/check-cr-status.sh Spss spss-cr ${var.cpd_namespace} spssmodelerStatus
EOF
  }
  depends_on = [
    local_file.spss_catalog_yaml,
    local_file.spss_cr_yaml,
    local_file.spss_sub_yaml,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
    null_resource.install_aiopenscale,
    null_resource.install_ws,
    null_resource.install_wml,
  ]
}

