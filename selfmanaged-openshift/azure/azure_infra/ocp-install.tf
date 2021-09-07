locals {
  openshift_installer_url_prefix   = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp"
  ocpdir                    = "${path.root}/installer-files"
  installer_workspace       = "${path.root}/installer-files"
  azuredir                  = "${pathexpand("~/.azure")}"
  ocptemplates              = "${path.root}/ocpfourxtemplates"
  install-config-file       = "install-config-${var.single-or-multi-zone}.tpl.yaml"
  machine-autoscaler-file   = "machine-autoscaler-${var.single-or-multi-zone}.tpl.yaml"
  machine-health-check-file = "machine-health-check-${var.single-or-multi-zone}.tpl.yaml"
  openshift_installer_url   = "${var.openshift_installer_url_prefix}/${var.ocp_version}"
  ocs-machineset-file   = var.single-or-multi-zone == "single" ? "ocs-machineset-singlezone.yaml" : "ocs-machineset-multizone.yaml"  
}

resource "null_resource" "download_binaries" {
  triggers = {
    installer_workspace = local.installer_workspace
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
mkdir -p ${local.azuredir}
test -e ${self.triggers.installer_workspace} || mkdir ${self.triggers.installer_workspace}
case $(uname -s) in
  Darwin)
    wget -r -l1 -np -nd -q ${local.openshift_installer_url} -P ${self.triggers.installer_workspace} -A 'openshift-install-mac-4*.tar.gz'
    tar zxvf ${self.triggers.installer_workspace}/openshift-install-mac-4*.tar.gz -C ${self.triggers.installer_workspace}
    wget -r -l1 -np -nd -q ${local.openshift_installer_url} -P ${self.triggers.installer_workspace} -A 'openshift-client-mac-4*.tar.gz'
    tar zxvf ${self.triggers.installer_workspace}/openshift-client-mac-4*.tar.gz -C ${self.triggers.installer_workspace}
    ;;
  Linux)
    wget -r -l1 -np -nd -q ${local.openshift_installer_url} -P ${self.triggers.installer_workspace} -A 'openshift-install-linux-4*.tar.gz'
    tar zxvf ${self.triggers.installer_workspace}/openshift-install-linux-4*.tar.gz -C ${self.triggers.installer_workspace}
    wget -r -l1 -np -nd -q ${local.openshift_installer_url} -P ${self.triggers.installer_workspace} -A 'openshift-client-linux-4*.tar.gz'
    tar zxvf ${self.triggers.installer_workspace}/openshift-client-linux-4*.tar.gz -C ${self.triggers.installer_workspace}
    ;;
  *)
    echo 'Supports only Linux and Mac OS at this time'
    exit 1;;
esac
rm -f ${self.triggers.installer_workspace}/*.tar.gz ${self.triggers.installer_workspace}/README.md ${self.triggers.installer_workspace}/robots*.txt*
EOF
  }

  /* provisioner "local-exec" {
    when    = destroy
    command = <<EOF
rm -rf ${self.triggers.installer_workspace}
EOF
  } */
}

resource "local_file" "install_config_yaml" {
  content  = data.template_file.installconfig.rendered
  filename = "${local.ocpdir}/install-config.yaml"
  depends_on = [
    null_resource.download_binaries
  ]
}

resource "local_file" "machine-health-check_yaml" {
  content  = data.template_file.machine-health-check.rendered
  filename = "${local.ocptemplates}/machine-health-check-${var.single-or-multi-zone}.yaml"
  depends_on = [
    null_resource.download_binaries
  ]
}

resource "local_file" "azurecreds_yaml" {
  content  = data.template_file.azurecreds.rendered
  filename = "${local.azuredir}/osServicePrincipal.json"
  depends_on = [
    null_resource.download_binaries
  ]
}

resource "local_file" "registry-mc_yaml" {
  content  = data.template_file.registry-mc.rendered
  filename = "${local.ocptemplates}/insecure-registry-mc.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "sysctl-mc_yaml" {
  content  = data.template_file.sysctl-mc.rendered
  filename = "${local.ocptemplates}/sysctl-mc.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "limits-mc_yaml" {
  content  = data.template_file.limits-mc.rendered
  filename = "${local.ocptemplates}/limits-mc.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "crio-mc_yaml" {
  content  = data.template_file.crio-mc.rendered
  filename = "${local.ocptemplates}/crio-mc.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "chrony-mc_yaml" {
  content  = data.template_file.chrony-mc.rendered
  filename = "${local.ocptemplates}/chrony-mc.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "registry-conf_yaml" {
  content  = data.template_file.registry-conf.rendered
  filename = "${local.ocptemplates}/registries.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "multipath-mc_yaml" {
  content  = data.template_file.multipath-mc.rendered
  filename = "${local.ocptemplates}/multipath-machineconfig.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "clusterautoscaler_yaml" {
  content  = data.template_file.clusterautoscaler.rendered
  filename = "${local.ocptemplates}/cluster-autoscaler.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "machineautoscaler_yaml" {
  content  = data.template_file.machineautoscaler.rendered
  filename = "${local.ocptemplates}/machine-autoscaler-${var.single-or-multi-zone}.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "htpasswd_yaml" {
  content  = data.template_file.htpasswd.rendered
  filename = "${local.ocptemplates}/auth.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "px-storageclasses_yaml" {
  content  = data.template_file.px-storageclasses.rendered
  filename = "${local.ocptemplates}/px-storageclasses.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "px-install_yaml" {
  content  = data.template_file.px-install.rendered
  filename = "${local.ocptemplates}/px-install.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}


resource "local_file" "px-storageclasses-secure_yaml" {
  content  = data.template_file.px-storageclasses-secure.rendered
  filename = "${local.ocptemplates}/px-storageclasses-secure.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "toolbox_yaml" {
  content  = file("../ocs_module/toolbox.yaml")
  filename = "${local.ocptemplates}/toolbox.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "deploy-with-olm_yaml" {
  content  = file("../ocs_module/deploy-with-olm.yaml")
  filename = "${local.ocptemplates}/deploy-with-olm.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "ocs-machineset-singlezone_yaml" {
  content  = file("../ocs_module/ocs-machineset-singlezone.yaml")
  filename = "${local.ocptemplates}/ocs-machineset-singlezone.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "ocs-machineset-multizone_yaml" {
  content  = file("../ocs_module/ocs-machineset-multizone.yaml")
  filename = "${local.ocptemplates}/ocs-machineset-multizone.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "ocs-storagecluster_yaml" {
  content  = file("../ocs_module/ocs-storagecluster.yaml")
  filename = "${local.ocptemplates}/ocs-storagecluster.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "ocs-prereq_yaml" {
  content  = file("../ocs_module/ocs-prereq.sh")
  filename = "${local.ocptemplates}/ocs-prereq.sh"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "local_file" "nfs-template_yaml" {
  count = var.storage == "nfs" ? 1 : 0
  content  = data.template_file.nfs-template[count.index].rendered
  filename = "${local.ocptemplates}/nfs-template.yaml"
  depends_on = [
    null_resource.install_openshift
  ]
}

resource "null_resource" "install_openshift" {
  triggers = {
    username              = var.admin-username
    directory             = local.ocpdir
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
mkdir -p ${local.ocptemplates}
cp ${local.ocpdir}/install-config.yaml ${local.ocpdir}/install-config.yaml_backup
chmod +x ${local.ocpdir}/openshift-install
cd ${local.ocpdir} && ./openshift-install create cluster --log-level=debug
#mkdir -p ${pathexpand("~/.kube")} 
#cp ${local.ocpdir}/auth/kubeconfig ${pathexpand("~/.kube/config")} 
EOF
  }

  # Destroy OCP Cluster before destroying the bootnode

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
cd ${self.triggers.directory} && ./openshift-install destroy cluster --log-level=debug
sleep 5
EOF
  }
  depends_on = [
    azurerm_subnet.masternode,
    azurerm_subnet.workernode,
    local_file.azurecreds_yaml,
    local_file.install_config_yaml
  ]
}

resource "null_resource" "openshift_post_install" {
  triggers = {
    username              = var.admin-username
    ocp_directory             = local.ocpdir
  }
  provisioner "local-exec" {
    command = <<EOF
CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}' --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig)
sed -i -e s/${random_id.randomId.hex}/$CLUSTERID/g ${local.ocptemplates}/machine-health-check-${var.single-or-multi-zone}.yaml
#oc login -u kubeadmin -p $(cat ${local.ocpdir}/auth/kubeadmin-password) -n openshift-machine-api --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
oc create -f ${local.ocptemplates}/machine-health-check-${var.single-or-multi-zone}.yaml --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
htpasswd -c -B -b /tmp/.htpasswd '${var.openshift-username}' '${var.openshift-password}'
sleep 3
oc create secret generic htpass-secret --from-file=htpasswd=/tmp/.htpasswd -n openshift-config --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
oc apply -f ${local.ocptemplates}/auth.yaml --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
oc adm policy add-cluster-role-to-user cluster-admin '${var.openshift-username}' --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
oc project kube-system --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
#sudo mv ${local.ocptemplates}/registries.conf /etc/containers/registries.conf
oc create -f ${local.ocptemplates}/insecure-registry-mc.yaml --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
oc create -f ${local.ocptemplates}/sysctl-mc.yaml --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
oc create -f ${local.ocptemplates}/limits-mc.yaml --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
oc create -f ${local.ocptemplates}/crio-mc.yaml --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
oc create -f ${local.ocptemplates}/chrony-mc.yaml --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
oc create -f ${local.ocptemplates}/multipath-machineconfig.yaml --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true, "replicas":${var.worker-node-count}}}' --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
echo 'Sleeping for 15 mins while MCs apply and the cluster restarts' 
sleep 15m
result=$(oc wait machineconfigpool/worker --for condition=updated --timeout=15m --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig)
echo $result
oc login https://api.${var.cluster-name}.${var.dnszone}:6443 -u '${var.openshift-username}' -p '${var.openshift-password}' --insecure-skip-tls-verify=true
EOF
  }
  depends_on = [
    null_resource.install_openshift,
    local_file.machine-health-check_yaml,
    local_file.registry-mc_yaml,
    local_file.sysctl-mc_yaml,
    local_file.limits-mc_yaml,
    local_file.crio-mc_yaml,
    local_file.chrony-mc_yaml,
    local_file.registry-conf_yaml,
    local_file.multipath-mc_yaml,
  ]
}

resource "null_resource" "cluster_autoscaler" {
  count = var.clusterAutoscaler == "yes" ? 1 : 0
  triggers = {
    username              = var.admin-username
  }
  provisioner "local-exec" {
    command = <<EOF
CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}' --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig)
sed -i s/${random_id.randomId.hex}/$CLUSTERID/g ${local.ocptemplates}/machine-autoscaler-${var.single-or-multi-zone}.yaml
oc create -f ${local.ocptemplates}/cluster-autoscaler.yaml --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
oc create -f ${local.ocptemplates}/machine-autoscaler-${var.single-or-multi-zone}.yaml --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig
EOF
  }
  depends_on = [
    null_resource.install_openshift,
    local_file.clusterautoscaler_yaml,
    local_file.clusterautoscaler_yaml,
    local_file.machineautoscaler_yaml
  ]
}

resource "null_resource" "install_portworx" {
  count = var.storage == "portworx" ? 1 : 0
  triggers = {
    username              = var.admin-username
  }
  provisioner "local-exec" {
    command = <<EOF
result=$(oc create -f ${local.ocptemplates}/px-install.yaml)
sleep 60
echo $result
result=$(oc apply -f "${var.portworx-spec-url}")
echo $result
echo 'Sleeping for 5 mins to get portworx storage cluster up' 
sleep 5m
EOF
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    local_file.px-install_yaml
  ]
}

resource "null_resource" "setup_sc_with_pwx_encryption" {
  count = var.storage == "portworx" && var.portworx-encryption == "yes" && var.portworx-encryption-key != "" ? 1 : 0
  triggers = {
    username              = var.admin-username
  }
  provisioner "local-exec" {
    command = <<EOF
result=$(oc -n kube-system create secret generic px-vol-encryption --from-literal=cluster-wide-secret-key=${var.portworx-encryption-key})
echo $result
PX_POD=$(oc get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
echo $PX_POD
result=$(oc exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl secrets set-cluster-key --secret cluster-wide-secret-key)
echo $result
result=$(oc create -f ${local.ocptemplates}/px-storageclasses-secure.yaml)
echo $result
EOF
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    null_resource.install_portworx,
    local_file.px-storageclasses-secure_yaml
  ]
}

resource "null_resource" "setup_sc_without_pwx_encryption" {
  count = var.storage == "portworx" && var.portworx-encryption == "no" ? 1 : 0
  triggers = {
    username              = var.admin-username
  }
  provisioner "local-exec" {
    command = <<EOF
result=$(oc create -f ${local.ocptemplates}/px-storageclasses.yaml)
echo $result
EOF
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    null_resource.install_portworx,
    local_file.px-storageclasses_yaml
  ]
}
resource "null_resource" "install_ocs" {
  count = var.storage == "ocs" ? 1 : 0
  triggers = {
    username              = var.admin-username
    ocp_directory             = local.ocpdir
  }
  provisioner "local-exec" {
    command = <<EOF
#chmod +x ${local.ocptemplates}/ocs-prereq.sh
#export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig
#${local.ocptemplates}/ocs-prereq.sh
CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}' --kubeconfig ${self.triggers.ocp_directory}/auth/kubeconfig)
sed -i -e s#REPLACE_CLUSTERID#$CLUSTERID#g ${local.ocptemplates}/${local.ocs-machineset-file}
sed -i -e s#REPLACE_REGION#${var.region}#g ${local.ocptemplates}/${local.ocs-machineset-file}
sed -i -e s#REPLACE_VNET_RG#${var.resource-group}#g ${local.ocptemplates}/${local.ocs-machineset-file}
sed -i -e s#REPLACE_WORKER_SUBNET#${var.worker-subnet-name}#g ${local.ocptemplates}/${local.ocs-machineset-file}
sed -i -e s#REPLACE_VNET_NAME#${var.virtual-network-name}#g ${local.ocptemplates}/${local.ocs-machineset-file}
oc create -f ${local.ocptemplates}/${local.ocs-machineset-file}
sleep 600
oc create -f ${local.ocptemplates}/deploy-with-olm.yaml
sleep 300
oc apply -f ${local.ocptemplates}/ocs-storagecluster.yaml
sleep 600
oc apply -f ${local.ocptemplates}/toolbox.yaml
sleep 60
EOF
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    local_file.toolbox_yaml,
    local_file.deploy-with-olm_yaml,
    local_file.ocs-storagecluster_yaml,
    local_file.ocs-prereq_yaml,
    local_file.ocs-machineset-singlezone_yaml,
    local_file.ocs-machineset-multizone_yaml
  ]
}

resource "null_resource" "install_nfs_client" {
  count = var.storage == "nfs" ? 1 : 0
  triggers = {
    username              = var.admin-username
  }
  provisioner "local-exec" {
    command = <<EOF
oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:kube-system:nfs-client-provisioner
oc process -f ${local.ocptemplates}/nfs-template.yaml | oc create -n kube-system -f -
EOF
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    local_file.nfs-template_yaml
  ]
}