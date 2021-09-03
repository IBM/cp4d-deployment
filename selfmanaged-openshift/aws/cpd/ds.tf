resource "local_file" "ds_cr_yaml" {
  content  = data.template_file.ds_cr.rendered
  filename = "${local.cpd_workspace}/ds_cr.yaml"
}

resource "local_file" "ds_sub_yaml" {
  content  = data.template_file.ds_sub.rendered
  filename = "${local.cpd_workspace}/ds_sub.yaml"
}

resource "local_file" "ds_iis_cr_yaml" {
  content  = data.template_file.ds_iis_cr.rendered
  filename = "${local.cpd_workspace}/ds_iis_cr.yaml"
}

resource "null_resource" "install_ds" {
  count = var.datastage.enable == "yes" ? 1 : 0
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
echo "Patch zen service"
oc patch zenservice lite-cr --type merge --patch '{"spec":{"image_digests": {"icp4data_nginx_repo": "sha256:c4124c8e4a9ebe902ae58b612fd4f08b5dd1d1e677cd72b922de227177e0171b", "icpd_requisite": "sha256:6bf10d1c9866595011310b049580368fa9a778e762cc4ed71b4334f09078f426", "influxdb": "sha256:848ef74e5d201470dc6d095ccd2c5c38ccd44b68ae31bc7eae248ad4308e8070", "privatecloud_usermgmt": "sha256:8eec0e953589207ba082a57cb87b6071a1e20c671eb74c6569d6c6da2bb94333", "zen_audit": "sha256:3d1a487933e628e42bc4c1e11422e0428408e9b3e402d9fdc90f1eb44a6aeb06", "zen_core": "sha256:c9dcb0001cfc683cc958e65a059c0a2163fd85c7b23066bf5d14d3e71f3b3b2e", "zen_core_api": "sha256:849d40d8ab78ff76b80bea251c67433c39a308a1e4ddd07b975e078d9b4a2e6f", "zen_data_sorcerer": "sha256:e75f67e2ed56ef578950c5f0a31f8dc5d96962d3b419ccd8d48df10c93149da1", "zen_iam_config": "sha256:dbfc3bce4861b670a7ab31124fac357c0e33f6e7d42bc1ad4b1dc91719d35ed3", "zen_metastoredb": "sha256:c228b0a18c5c0d4c0440820ae911eed896941deccbe07b1a7fd71606f049a6aa", "zen_watchdog": "sha256:acfde984704f140e908dcfd574d1dcb25e62021fa3f80ce64d41c6dbef6a154e"}  }}' -n ${self.triggers.namespace}

echo "Create SCC for WKC-IIS"
oc apply -f ${self.triggers.cpd_workspace}/wkc_iis_scc.yaml

echo "Install IIS Operator"
wget ${local.cpd_case_url}/ibm-iis-4.0.1.tgz -P ${self.triggers.cpd_workspace} -A 'ibm-iis-4.0.1.tgz'
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-iis-4.0.1.tgz --tolerance 1 --namespace ${local.operator_namespace} --action installOperator --inventory iisOperatorSetup
bash cpd/scripts/pod-status-check.sh ibm-cpd-iis-operator ${local.operator_namespace}

echo "Create IIS CR"
oc apply -f ${self.triggers.cpd_workspace}/ds_iis_cr.yaml

echo 'check the IIS cr status'
bash cpd/scripts/check-cr-status.sh IIS iis-cr ${var.cpd_namespace} iisStatus; if [ $? -ne 0 ] ; then echo \"IIS service failed to install\" ; exit 1 ; fi

echo 'Create Datastage sub'
oc create -f ${self.triggers.cpd_workspace}/ds_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-datastage-operator ${local.operator_namespace}

echo 'Create Datastage CR'
oc create -f ${self.triggers.cpd_workspace}/ds_cr.yaml

echo 'check the Datastage cr status'
bash cpd/scripts/check-cr-status.sh datastageservice datastage-cr ${var.cpd_namespace} dsStatus
EOF
  }
  depends_on = [
    local_file.ds_cr_yaml,
    local_file.ds_sub_yaml,
    local_file.ds_iis_cr_yaml,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_ws,
    null_resource.install_spss,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_cde,
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    null_resource.login_cluster,
    null_resource.install_db2aaservice,
  ]
}
