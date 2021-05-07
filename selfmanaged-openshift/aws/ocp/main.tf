locals {
  installer_workspace     = "${path.root}/installer-files"
  openshift_installer_url = "${var.openshift_installer_url}/${var.openshift_version}"
}

resource "null_resource" "download_binaries" {
  triggers = {
    installer_workspace = local.installer_workspace
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
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

resource "null_resource" "install_openshift" {
  triggers = {
    installer_workspace = local.installer_workspace
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
cd ${self.triggers.installer_workspace} && ./openshift-install create cluster --log-level=debug
EOF
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
cd ${self.triggers.installer_workspace} && ./openshift-install destroy cluster --log-level=debug
sleep 30
EOF
  }
  depends_on = [
    null_resource.download_binaries,
    local_file.install_config_yaml,
  ]
}

resource "null_resource" "create_openshift_user" {
  triggers = {
    installer_workspace = local.installer_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
htpasswd -c -B -b /tmp/.htpasswd '${var.openshift_username}' '${var.openshift_password}'
sleep 30
oc create secret generic htpass-secret --from-file=htpasswd=/tmp/.htpasswd -n openshift-config --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig
oc apply -f ${self.triggers.installer_workspace}/htpasswd.yaml --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig
oc adm policy add-cluster-role-to-user cluster-admin '${var.openshift_username}' --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig
sleep 60
EOF
  }

  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
rm -f /tmp/.htpasswd
oc delete secret htpass-secret -n openshift-config --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig
oc delete -f ${self.triggers.installer_workspace}/htpasswd.yaml --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig
EOF
  } */
  depends_on = [
    null_resource.download_binaries,
    null_resource.install_openshift,
    local_file.htpasswd_yaml,
  ]
}

resource "null_resource" "enable_autoscaler" {
  count = var.enable_autoscaler == true ? 1 : 0
  triggers = {
    installer_workspace     = local.installer_workspace
  }
  provisioner "local-exec" {
    when = create
    command = <<EOF
echo "Creating Cluster Autoscaler"
oc create -f ${self.triggers.installer_workspace}/cluster_autoscaler.yaml --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig
CLUSTERID=$(oc get machineset -n openshift-machine-api --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')
sed -i -e s/CLUSTERID/$CLUSTERID/g ${self.triggers.installer_workspace}/machine_autoscaler.yaml
echo "Creating Machine Autoscaler"
oc create -f ${self.triggers.installer_workspace}/machine_autoscaler.yaml --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig
echo "Creating Machine Health Check"
sed -i -e s/CLUSTERID/$CLUSTERID/g ${self.triggers.installer_workspace}/machine_health_check.yaml
oc create -f ${self.triggers.installer_workspace}/machine_health_check.yaml --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig
EOF
  }

  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Deleting Machine Health Check"
oc delete -f ${self.triggers.installer_workspace}/machine_health_check.yaml --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig
echo "Deleting Machine Autoscaler"
oc delete -f ${self.triggers.installer_workspace}/machine_autoscaler.yaml --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig
echo "Deleting Cluster Autoscaler"
oc delete -f ${self.triggers.installer_workspace}/cluster_autoscaler.yaml --kubeconfig ${self.triggers.installer_workspace}/auth/kubeconfig
EOF
  } */
  depends_on = [
    local_file.cluster_autoscaler_yaml,
    local_file.machine_autoscaler_yaml,
    local_file.machine_health_check_yaml,
    null_resource.download_binaries,
    null_resource.install_openshift,
  ]
}
