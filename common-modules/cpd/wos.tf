
resource "local_file" "wos_catalog_yaml" {
  content  = data.template_file.wos_catalog.rendered
  filename = "${local.cpd_workspace}/wos_catalog.yaml"
}

resource "local_file" "wos_cr_yaml" {
  content  = data.template_file.wos_cr.rendered
  filename = "${local.cpd_workspace}/wos_cr.yaml"
}

resource "local_file" "wos_sub_yaml" {
  content  = data.template_file.wos_sub.rendered
  filename = "${local.cpd_workspace}/wos_sub.yaml"
}

resource "null_resource" "install_aiopenscale" {
  count = var.watson_ai_openscale.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF

echo 'Create wos catalog'
oc apply -f ${self.triggers.cpd_workspace}/wos_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-openscale-operator-catalog openshift-marketplace

echo 'Create wos sub'
oc apply -f ${self.triggers.cpd_workspace}/wos_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-wos-operator ${local.operator_namespace}

echo 'Create wos CR'
oc apply -f ${self.triggers.cpd_workspace}/wos_cr.yaml
sleep 3
echo 'check the wos cr status'
bash cpd/scripts/check-cr-status.sh woservice aiopenscale-cr ${var.cpd_namespace} wosStatus
EOF
  }
  depends_on = [
    local_file.wos_catalog_yaml,
    local_file.wos_cr_yaml,
    local_file.wos_sub_yaml,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
    null_resource.install_wml,
    null_resource.install_ws,
  ]
}

