resource "local_file" "wkc_iis_scc_yaml" {
  content  = data.template_file.wkc_iis_scc.rendered
  filename = "${local.cpd_workspace}/wkc_iis_scc.yaml"
}

resource "local_file" "sysctl_worker_yaml" {
  content  = data.template_file.sysctl_worker.rendered
  filename = "${local.cpd_workspace}/sysctl_worker.yaml"
}

resource "null_resource" "install_wkc" {
  count = var.watson_knowledge_catalog == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Create SCC for WKC-IIS"  &&
oc apply -f ${self.triggers.cpd_workspace}/wkc_iis_scc.yaml  &&
#echo "Create RBAC for WKC-IIS"
#oc create clusterrole system:openshift:scc:wkc-iis-scc --verb=use --resource=scc --resource-name=wkc-iis-scc
#oc create rolebinding wkc-iis-scc-rb --namespace ${var.cpd_namespace} --clusterrole=system:openshift:scc:wkc-iis-scc --serviceaccount=${var.cpd_namespace}:wkc-iis-sa
echo "Deploying catalogsources and operator subscriptions for watson knowledge catalog" &&
bash cpd/scripts/apply-olm.sh ${self.triggers.cpd_workspace} ${var.cpd_version} wkc &&
echo "Create wkc cr" &&
bash cpd/scripts/apply-cr.sh ${self.triggers.cpd_workspace} ${var.cpd_version} wkc ${var.cpd_namespace} ${var.storage_option} ${local.storage_class} ${local.rwo_storage_class}

EOF
  }
  depends_on = [
    local_file.wkc_iis_scc_yaml,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_dods,
    null_resource.install_dmc,
    null_resource.install_bigsql,
    null_resource.install_dv,
    null_resource.install_mdm,
    null_resource.install_cde,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
