resource "local_file" "ds_catalog_yaml" {
  content  = data.template_file.ds_catalog.rendered
  filename = "${local.cpd_workspace}/ds_catalog.yaml"
}

resource "local_file" "ds_cr_yaml" {
  content  = data.template_file.ds_cr.rendered
  filename = "${local.cpd_workspace}/ds_cr.yaml"
}

resource "local_file" "ds_sub_yaml" {
  content  = data.template_file.ds_sub.rendered
  filename = "${local.cpd_workspace}/ds_sub.yaml"
}

resource "null_resource" "install_ds" {
  count = var.datastage.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF

echo 'Create Datastage catalog'
oc apply -f ${self.triggers.cpd_workspace}/ds_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-datastage-operator-catalog openshift-marketplace

echo 'Create Datastage sub'
oc apply -f ${self.triggers.cpd_workspace}/ds_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-datastage-operator ${local.operator_namespace}

echo 'Create Datastage CR'
oc apply -f ${self.triggers.cpd_workspace}/ds_cr.yaml

echo 'check the Datastage cr status'
bash cpd/scripts/check-cr-status.sh datastage datastage-cr ${var.cpd_namespace} dsStatus
EOF
  }
  depends_on = [
    local_file.ds_catalog_yaml,
    local_file.ds_cr_yaml,
    local_file.ds_sub_yaml,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_cde,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
    null_resource.install_db2aaservice,
  ]
}
