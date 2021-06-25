
resource "local_file" "wml_cr_yaml" {
  content  = data.template_file.wml_cr.rendered
  filename = "${local.cpd_workspace}/wml_cr.yaml"
}

resource "local_file" "wml_sub_yaml" {
  content  = data.template_file.wml_sub.rendered
  filename = "${local.cpd_workspace}/wml_sub.yaml"
}

resource "null_resource" "install_wml" {
  count = var.watson_machine_learning == "yes" ? 1 : 0
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

echo 'Create WML sub'
oc apply -f ${self.triggers.cpd_workspace}/wml_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-wml-operator ${local.operator_namespace}

echo 'Create WML CR'
oc apply -f ${self.triggers.cpd_workspace}/wml_cr.yaml
sleep 3
echo 'check the WML cr status'
bash cpd/scripts/check-cr-status.sh WmlBase wml-cr ${var.cpd_namespace} wmlStatus
EOF
  }
  depends_on = [
    local_file.wml_cr_yaml,
    local_file.wml_sub_yaml,
    null_resource.configure_cluster,
  ]
}

