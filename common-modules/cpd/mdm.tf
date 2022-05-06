resource "local_file" "mdm_catalog_yaml" {
  content  = data.template_file.mdm_catalog.rendered
  filename = "${local.cpd_workspace}/mdm_catalog.yaml"
}

resource "local_file" "mdm_cr_yaml" {
  content  = data.template_file.mdm_cr.rendered
  filename = "${local.cpd_workspace}/mdm_cr.yaml"
}

resource "local_file" "mdm_ocs_cr_yaml" {
  content  = data.template_file.mdm_ocs_cr.rendered
  filename = "${local.cpd_workspace}/mdm_ocs_cr.yaml"
}

resource "local_file" "mdm_sub_yaml" {
  content  = data.template_file.mdm_sub.rendered
  filename = "${local.cpd_workspace}/mdm_sub.yaml"
}


resource "null_resource" "install_mdm" {
  count = var.master_data_management.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF


echo "Install MDM catalog"
oc create -f ${self.triggers.cpd_workspace}/mdm_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh iibm-mdm-operator-catalog openshift-marketplace

echo "Install MDM Operator"
oc create -f ${self.triggers.cpd_workspace}/mdm_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-mdm-operator ${local.operator_namespace}

echo "MDM CR"

oc apply -f ${self.triggers.cpd_workspace}/${local.mdm-cr-file}.yaml
echo 'check the MDM cr status'
bash cpd/scripts/check-cr-status.sh MasterDataManagement mdm-cr ${var.cpd_namespace} mdmStatus
EOF
  }
  depends_on = [
    local_file.mdm_catalog_yaml,
    local_file.mdm_cr_yaml,
    local_file.mdm_sub_yaml,
    module.machineconfig,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
  ]
}
locals {
  mdm-cr-file  = var.storage_option == "ocs" ?  "mdm_ocs_cr" : "mdm_cr" 
}