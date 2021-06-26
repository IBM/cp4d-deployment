
resource "local_file" "spss_cr_yaml" {
  content  = data.template_file.spss_cr.rendered
  filename = "${local.cpd_workspace}/spss_cr.yaml"
}

resource "local_file" "spss_sub_yaml" {
  content  = data.template_file.spss_sub.rendered
  filename = "${local.cpd_workspace}/spss_sub.yaml"
}

resource "null_resource" "install_spss" {
  count = var.spss_modeler == "yes" ? 1 : 0
  triggers = {
    namespace             = var.cpd_namespace
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    cpd_workspace = local.cpd_workspace
    login_cmd = var.login_cmd
  }
  provisioner "local-exec" {
    command = <<-EOF
${self.triggers.login_cmd} --insecure-skip-tls-verify || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'

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
    local_file.spss_cr_yaml,
    local_file.spss_sub_yaml,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.install_ccs,
    null_resource.install_aiopenscale,
    null_resource.install_analyticsengine,
    null_resource.install_db2wh,
  ]
}

