resource "local_file" "cde_catalog_yaml" {
  content  = data.template_file.cde_catalog.rendered
  filename = "${local.cpd_workspace}/cde_catalog.yaml"
}

resource "local_file" "cde_cr_yaml" {
  content  = data.template_file.cde_cr.rendered
  filename = "${local.cpd_workspace}/cde_cr.yaml"
}

resource "local_file" "cde_sub_yaml" {
  content  = data.template_file.cde_sub.rendered
  filename = "${local.cpd_workspace}/cde_sub.yaml"
}

resource "null_resource" "install_cde" {
  count = var.cognos_dashboard_embedded.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF


echo "Creating CDE Catalog"
oc create -f ${self.triggers.cpd_workspace}/cde_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cde-operator-catalog openshift-marketplace

echo "Creating CDE through Subscription"
oc create -f ${self.triggers.cpd_workspace}/cde_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cde-operator ${local.operator_namespace}

echo 'Create CDE CR'
oc create -f ${self.triggers.cpd_workspace}/cde_cr.yaml
sleep 3
echo 'Check the CDE cr status'
bash cpd/scripts/check-cr-status.sh CdeProxyService cdeproxyservice-cr ${var.cpd_namespace} cdeStatus
EOF
  }
  depends_on = [
    local_file.cde_catalog_yaml,
    local_file.cde_cr_yaml,
    local_file.cde_sub_yaml,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_dv,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}

