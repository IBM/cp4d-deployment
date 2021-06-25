
resource "local_file" "db2wh_cr_yaml" {
  content  = data.template_file.db2wh_cr.rendered
  filename = "${local.cpd_workspace}/db2wh_cr.yaml"
}

resource "local_file" "db2wh_sub_yaml" {
  content  = data.template_file.db2wh_sub.rendered
  filename = "${local.cpd_workspace}/db2wh_sub.yaml"
}

resource "null_resource" "install_db2wh" {
  count = var.db2_warehouse == "yes" ? 1 : 0
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

echo 'Create db2wh sub'
oc create -f ${self.triggers.cpd_workspace}/db2wh_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-db2wh-cp4d-operator ${local.operator_namespace}

echo 'Create db2wh CR'
oc create -f ${self.triggers.cpd_workspace}/db2wh_cr.yaml
sleep 3
echo 'check the db2wh cr status'
bash cpd/scripts/check-cr-status.sh Db2whService db2wh ${var.cpd_namespace} db2whStatus
EOF
  }
  depends_on = [
    local_file.db2wh_cr_yaml,
    local_file.db2wh_sub_yaml,
    null_resource.configure_cluster,
  ]
}

