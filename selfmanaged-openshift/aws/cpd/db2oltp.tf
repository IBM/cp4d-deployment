
resource "local_file" "db2oltp_cr_yaml" {
  content  = data.template_file.db2oltp_cr.rendered
  filename = "${local.cpd_workspace}/db2oltp_cr.yaml"
}

resource "local_file" "db2oltp_sub_yaml" {
  content  = data.template_file.db2oltp_sub.rendered
  filename = "${local.cpd_workspace}/db2oltp_sub.yaml"
}

resource "null_resource" "install_db2oltp" {
  count = var.db2_oltp.enabled == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo 'Create db2oltp sub'
oc create -f ${self.triggers.cpd_workspace}/db2oltp_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-db2oltp-cp4d-operator ${local.operator_namespace}

echo 'Create db2oltp CR'
oc create -f ${self.triggers.cpd_workspace}/db2oltp_cr.yaml
sleep 3
echo 'check the db2oltp cr status'
bash cpd/scripts/check-cr-status.sh Db2oltpService db2oltp-cr ${var.cpd_namespace} db2oltpStatus
EOF
  }
  depends_on = [
    local_file.db2oltp_cr_yaml,
    local_file.db2oltp_sub_yaml,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}

