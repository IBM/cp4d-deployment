resource "local_file" "wkc_sub_yaml" {
  content  = data.template_file.wkc_sub.rendered
  filename = "${local.cpd_workspace}/wkc_sub.yaml"
}

resource "local_file" "wkc_cr_yaml" {
  content  = data.template_file.wkc_cr.rendered
  filename = "${local.cpd_workspace}/wkc_cr.yaml"
}

resource "local_file" "wkc_iis_scc_yaml" {
  content  = data.template_file.wkc_iis_scc.rendered
  filename = "${local.cpd_workspace}/wkc_iis_scc.yaml"
}

resource "local_file" "wkc_iis_cr_yaml" {
  content  = data.template_file.wkc_iis_cr.rendered
  filename = "${local.cpd_workspace}/wkc_iis_cr.yaml"
}

resource "local_file" "wkc_ug_cr_yaml" {
  content  = data.template_file.wkc_ug_cr.rendered
  filename = "${local.cpd_workspace}/wkc_ug_cr.yaml"
}

resource "local_file" "sysctl_worker_yaml" {
  content  = data.template_file.sysctl_worker.rendered
  filename = "${local.cpd_workspace}/sysctl_worker.yaml"
}

resource "null_resource" "install_wkc" {
  count = var.watson_knowledge_catalog == "yes" ? 1 : 0
  triggers = {
    namespace             = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Creating WKC Operator"
oc create -f ${self.triggers.cpd_workspace}/wkc_sub.yaml
bash cpd/scripts/pod-status-check.sh ibm-cpd-wkc-operator ${local.operator_namespace}

echo 'Create WKC Core CR'
oc create -f ${self.triggers.cpd_workspace}/wkc_cr.yaml

echo 'check the WKC Core cr status'
bash cpd/scripts/check-cr-status.sh wkc wkc-cr ${var.cpd_namespace} wkcStatus


echo "Create SCC for WKC-IIS"
oc create -f ${self.triggers.cpd_workspace}/wkc_iis_scc.yaml

echo "Install IIS Operator"
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-iis/4.0.0/ibm-iis-4.0.0.tgz -P ${self.triggers.cpd_workspace} -A 'ibm-iis-4.0.0.tgz'
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-iis-4.0.0.tgz --tolerance 1 --namespace ${local.operator_namespace} --action installOperator --inventory iisOperatorSetup
bash cpd/scripts/pod-status-check.sh ibm-cpd-iis-operator ${local.operator_namespace}

echo "Create IIS CR"
oc create -f ${self.triggers.cpd_workspace}/wkc_iis_cr_yaml
echo 'check the IIS cr status'
bash cpd/scripts/check-cr-status.sh IIS iis-cr ${var.cpd_namespace} iisStatus

echo "Create UG cr"
oc create -f ${self.triggers.cpd_workspace}/wkc_ug_cr_yaml
echo 'check the UG cr status'
bash cpd/scripts/check-cr-status.sh UG ug-cr ${var.cpd_namespace} ugStatus

EOF
  }
  depends_on = [
    local_file.wkc_cr_yaml,
    # local_file.db2aaservice_cr_yaml,
    local_file.wkc_iis_scc_yaml,
    local_file.wkc_iis_cr_yaml,
    local_file.wkc_ug_cr_yaml,
    null_resource.install_analyticsengine,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_db2wh,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.install_ccs,
    null_resource.login_cluster,
  ]
}