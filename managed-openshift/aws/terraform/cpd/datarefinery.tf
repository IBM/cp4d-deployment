
# resource "local_file" "dr_cr_yaml" {
#   content  = data.template_file.dr_cr.rendered
#   filename = "${local.cpd_workspace}/dr_cr.yaml"
# }

# resource "local_file" "dr_sub_yaml" {
#   content  = data.template_file.dr_sub.rendered
#   filename = "${local.cpd_workspace}/dr_sub.yaml"
# }

resource "null_resource" "install_datarefinery" {
  count = var.watson_studio == "yes" || var.watson_knowledge_catalog == "yes" ? 1 : 0
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

EOF
  }
  depends_on = [
    # local_file.dr_cr_yaml,
    # local_file.dr_sub_yaml,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.install_ccs,
    null_resource.install_aiopenscale,
    null_resource.install_analyticsengine,
    null_resource.install_db2wh,
    null_resource.install_spss,
  ]
}

