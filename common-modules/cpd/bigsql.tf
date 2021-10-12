resource "local_file" "bigsql_cr_yaml" {
  content  = data.template_file.bigsql_cr.rendered
  filename = "${local.cpd_workspace}/bigsql_cr.yaml"
}

resource "local_file" "bigsql_sub_yaml" {
  content  = data.template_file.bigsql_sub.rendered
  filename = "${local.cpd_workspace}/bigsql_sub.yaml"
}

resource "null_resource" "install_bigsql" {
  count = var.bigsql.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Creating BIGSQL Operator through Subscription"
oc create -f ${self.triggers.cpd_workspace}/bigsql_sub.yaml
bash cpd/scripts/pod-status-check.sh ibm-bigsql-operator-controller-manager ${local.operator_namespace}

echo 'Create BIGSQL CR'
oc create -f ${self.triggers.cpd_workspace}/bigsql_cr.yaml

echo 'check the BIGSQL cr status'
bash cpd/scripts/check-cr-status.sh BigsqlService bigsql-service-cr ${var.cpd_namespace} reconcileStatus
EOF
  }
  depends_on = [
    local_file.bigsql_cr_yaml,
    local_file.bigsql_sub_yaml,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
