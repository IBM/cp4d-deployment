
resource "local_file" "analyticsengine_catalog_yaml" {
  content  = data.template_file.analyticsengine_catalog.rendered
  filename = "${local.cpd_workspace}/analyticsengine_catalog.yaml"
}
resource "local_file" "analyticsengine_cr_yaml" {
  content  = data.template_file.analyticsengine_cr.rendered
  filename = "${local.cpd_workspace}/analyticsengine_cr.yaml"
}

resource "local_file" "analyticsengine_sub_yaml" {
  content  = data.template_file.analyticsengine_sub.rendered
  filename = "${local.cpd_workspace}/analyticsengine_sub.yaml"
}

resource "null_resource" "install_analyticsengine" {
  count = var.analytics_engine.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF

echo 'Create analyticsengine catalog'
oc create -f ${self.triggers.cpd_workspace}/analyticsengine_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-ae-operator-catalog openshift-marketplace

echo 'Create analyticsengine sub'
oc create -f ${self.triggers.cpd_workspace}/analyticsengine_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-ae-operator ${local.operator_namespace}

echo 'Create analyticsengine CR'
oc create -f ${self.triggers.cpd_workspace}/analyticsengine_cr.yaml
sleep 3
echo 'check the analyticsengine cr status'
bash cpd/scripts/check-cr-status.sh AnalyticsEngine analyticsengine-cr ${var.cpd_namespace} analyticsengineStatus
EOF
  }
  depends_on = [
    local_file.analyticsengine_catalog_yaml,
    local_file.spss_cr_yaml,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_dv,
    null_resource.install_cde,
    null_resource.install_wkc,
    null_resource.install_db2aaservice,
  ]
}
