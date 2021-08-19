resource "local_file" "ca_cr_yaml" {
  content  = data.template_file.ca_cr.rendered
  filename = "${local.cpd_workspace}/ca_cr.yaml"
}

resource "local_file" "ca_sub_yaml" {
  content  = data.template_file.ca_sub.rendered
  filename = "${local.cpd_workspace}/ca_sub.yaml"
}

resource "null_resource" "install_ca" {
  count = var.cognos_analytics == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo 'Create CA sub'
oc create -f ${self.triggers.cpd_workspace}/ca_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-ca-operator ${local.operator_namespace}

echo "CA CR"
oc create -f ${self.triggers.cpd_workspace}/ca_cr.yaml
echo 'check the CA cr status'
bash cpd/scripts/check-cr-status.sh CAService ca-cr ${var.cpd_namespace} cdeStatus
EOF
  }
  depends_on = [
    local_file.ca_cr_yaml,
    local_file.ca_sub_yaml,
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
    null_resource.login_cluster,
    null_resource.install_cde,
  ]
}
