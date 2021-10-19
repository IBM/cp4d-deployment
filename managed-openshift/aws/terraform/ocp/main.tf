locals {
  classic_lb_timeout = 600
  
  installer_workspace = "${path.root}/installer-files"
  rosa_installer_url  = "https://github.com/openshift/rosa/releases/download/v1.0.8"
  subnet_ids          = join(",", var.subnet_ids)
  private_link        = var.private_cluster ? "--private-link" : ""
}

resource "null_resource" "download_binaries" {
  triggers = {
    installer_workspace = var.installer_workspace
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
test -e ${self.triggers.installer_workspace} || mkdir ${self.triggers.installer_workspace}
case $(uname -s) in
  Darwin)
    wget -r -l1 -np -nd -q ${local.rosa_installer_url}/rosa-darwin-amd64 -P ${self.triggers.installer_workspace} -A 'rosa-darwin-amd64'
    chmod u+x ${self.triggers.installer_workspace}/rosa-darwin-amd64
    mv ${self.triggers.installer_workspace}/rosa-darwin-amd64 ${self.triggers.installer_workspace}/rosa
    ;;
  Linux)
    wget -r -l1 -np -nd -q ${local.rosa_installer_url}/rosa-linux-amd64 -P ${self.triggers.installer_workspace} -A 'rosa-linux-amd64'
    chmod u+x ${self.triggers.installer_workspace}/rosa-linux-amd64
    mv ${self.triggers.installer_workspace}/rosa-linux-amd64 ${self.triggers.installer_workspace}/rosa
    ;;
  *)
    echo 'Supports only Linux and Mac OS at this time'
    exit 1;;
esac
EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
#rm -rf ${self.triggers.installer_workspace}
EOF
  }
}

resource "null_resource" "install_rosa" {
  triggers = {
    installer_workspace = var.installer_workspace
    cluster_name        = var.cluster_name
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
${self.triggers.installer_workspace}/rosa login --token='${var.rosa_token}'
${self.triggers.installer_workspace}/rosa init
${self.triggers.installer_workspace}/rosa verify quota
${self.triggers.installer_workspace}/rosa create cluster ${local.private_link} --cluster-name='${self.triggers.cluster_name}' --compute-machine-type='${var.worker_machine_type}' --compute-nodes ${var.worker_machine_count} --region ${var.region} \
    --machine-cidr='${var.machine_network_cidr}' --service-cidr='${var.service_network_cidr}' --pod-cidr='${var.cluster_network_cidr}' --host-prefix='${var.cluster_network_host_prefix}' --private=${var.private_cluster} \
    --multi-az=${var.multi_zone} --version='${var.openshift_version}' --subnet-ids='${local.subnet_ids}' --watch --yes
EOF
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
${self.triggers.installer_workspace}/rosa delete cluster --cluster='${self.triggers.cluster_name}' --yes 
sleep 120
EOF
  }
  depends_on = [
    null_resource.download_binaries
  ]
}

resource "null_resource" "create_rosa_user" {
  triggers = {
    installer_workspace = var.installer_workspace
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
${self.triggers.installer_workspace}/rosa create admin --cluster='${var.cluster_name}' > ${self.triggers.installer_workspace}/.creds
echo "Sleeping for 4mins"
sleep 240
EOF
  }
  depends_on = [
    null_resource.install_rosa,
  ]
}

data "local_file" "creds" {
  filename = "${var.installer_workspace}/.creds"
  depends_on = [
    null_resource.create_rosa_user
  ]
}
locals {
  login_cmd     = regex("oc\\s.*", data.local_file.creds.content)
}
resource "null_resource" "configure_image_registry" {
  provisioner "local-exec" {
    command =<<EOF
${local.login_cmd} --insecure-skip-tls-verify
bash ocp/scripts/nodes_running.sh
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true,"replicas":3}}' -n openshift-image-registry
oc patch svc/image-registry -p '{"spec":{"sessionAffinity": "ClientIP"}}' -n openshift-image-registry
echo 'Sleeping for 3m'
sleep 180
oc annotate route default-route haproxy.router.openshift.io/timeout=600s -n openshift-image-registry
oc set env deployment/image-registry -n openshift-image-registry REGISTRY_STORAGE_S3_CHUNKSIZE=1048576000

sleep 2m
bash ocp/scripts/update-elb-timeout.sh ${var.vpc_id} ${local.classic_lb_timeout}
EOF
  }
  depends_on = [
    null_resource.create_rosa_user
  ]
}

resource "null_resource" "configure_cluster_rosa" {
  provisioner "local-exec" {
    command =<<EOF
echo "Patch configuration managed"
oc patch kubeletconfig custom-kubelet --type='json' -p='[{"op": "remove", "path": "/spec/machineConfigPoolSelector/matchLabels"}]'
oc patch kubeletconfig custom-kubelet --type merge -p '{"spec":{"machineConfigPoolSelector":{"matchLabels":{"pools.operator.machineconfiguration.openshift.io/master":""}}}}'
oc label machineconfigpool.machineconfiguration.openshift.io worker db2u-kubelet=sysctl
bash ocp/scripts/nodes_running.sh
EOF
  }
  depends_on = [
    null_resource.configure_image_registry
  ]
}

