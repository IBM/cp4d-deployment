
resource "local_file" "db2aaservice_cr_yaml" {
  content  = data.template_file.db2aaservice_cr.rendered
  filename = "${local.cpd_workspace}/db2aaservice_cr.yaml"
}

resource "local_file" "db2aaservice_sub_yaml" {
  content  = data.template_file.db2aaservice_sub.rendered
  filename = "${local.cpd_workspace}/db2aaservice_sub.yaml"
}

resource "null_resource" "install_db2aaservice" {
  count = local.db2aaservice == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Db2uaaService"
oc create -f ${self.triggers.cpd_workspace}/db2aaservice_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-db2aaservice-cp4d-operator-controller-manager ${local.operator_namespace}

oc create -f ${self.triggers.cpd_workspace}/db2aaservice_cr.yaml
echo "Checking if the Db2uaaService pods are ready and running"
bash cpd/scripts/check-cr-status.sh Db2aaserviceService db2aaservice-cr ${var.cpd_namespace} db2aaserviceStatus
EOF
  }
  depends_on = [
    local_file.db2aaservice_cr_yaml,
    local_file.db2aaservice_sub_yaml,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
