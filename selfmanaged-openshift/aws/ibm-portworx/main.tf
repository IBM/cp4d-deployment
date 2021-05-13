resource "aws_kms_key" "px_key" {
  description = "Key used to encrypt Portworx PVCs"
}

resource "local_file" "storage_classes_yaml" {
  content  = data.template_file.storage_classes.rendered
  filename = "${var.installer_workspace}/storage_classes.yaml"
}

resource "local_file" "portworx_operator_yaml" {
  content  = data.template_file.portworx_operator.rendered
  filename = "${var.installer_workspace}/portworx_operator.yaml"
}

resource "local_file" "portworx_storagecluster_yaml" {
  content  = data.template_file.portworx_storagecluster.rendered
  filename = "${var.installer_workspace}/portworx_storagecluster.yaml"
}

resource "null_resource" "download_and_extract_packages" {
  count = local.download_and_extract_packages ? 1 : 0
  triggers = {
    installer_workspace = local.installer_workspace
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
test -e ${self.triggers.installer_workspace} || mkdir ${self.triggers.installer_workspace}
case $(uname -s) in
  Darwin)
    wget -r -l1 -np -nd -q ${var.ibm_px_package_url} -P ${self.triggers.installer_workspace} -A 'cpd*-portworx*.tgz'
    tar zxvf ${self.triggers.installer_workspace}/cpd*-portworx*.tgz -C ${self.triggers.installer_workspace}
    ;;
  Linux)
    wget -r -l1 -np -nd -q ${var.ibm_px_package_url} -P ${self.triggers.installer_workspace} -A 'cpd*-portworx*.tgz'
    tar zxvf ${self.triggers.installer_workspace}/cpd*-portworx*.tgz -C ${self.triggers.installer_workspace}
    ;;
  *)
    echo 'Supports only Linux and Mac OS at this time'
    exit 1;;
esac
rm -f ${self.triggers.installer_workspace}/*.tgz
EOF
  }
}

resource "null_resource" "push_ibm_px_images" {
  triggers = {
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
cd ibm-portworx/cpd-portworx/px-images
echo "cleaning up stale images"
PODMAN_LOGIN_ARGS="--tls-verify=false" PODMAN_PUSH_ARGS="--tls-verify=false" ./podman-rm-local-images.sh
echo "Processing images"
PODMAN_LOGIN_ARGS="--tls-verify=false" PODMAN_PUSH_ARGS="--tls-verify=false" ./process-px-images.sh -r $(oc registry info -n openshift-image-registry) -u $(oc whoami) -p $(oc whoami -t) -s kube-system -c podman -t ./px_*-dist.tgz
EOF
    depends_on = [
        null_resource.download_and_extract_packages
    ]
  }
}

resource "null_resource" "install_ibm_portworx" {
  triggers = {
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    installer_workspace = var.installer_workspace
    region              = var.region
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
chmod +x portworx/scripts/portworx-prereq.sh
bash portworx/scripts/portworx-prereq.sh ${self.triggers.region}
oc create -f ${self.triggers.installer_workspace}/portworx_operator.yaml
echo "Sleeping for 5mins"
sleep 300
echo "Deploying StorageCluster"
oc create -f ${self.triggers.installer_workspace}/portworx_storagecluster.yaml
sleep 300
echo "Enabling encryption"
PX_POD=$(oc get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
oc exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl secrets aws login
echo "Create storage classes"
oc create -f ${self.triggers.installer_workspace}/storage_classes.yaml
EOF
  }
  depends_on = [
    null_resource.download_and_extract_packages,
    null_resource.push_ibm_px_images,
    local_file.storage_classes_yaml,
    local_file.portworx_storagecluster_yaml,
    local_file.portworx_operator_yaml,
  ]
}


locals {
  px_cluster_id = "px-storage-cluster"
  priv_image_registry = "image-registry.openshift-image-registry.svc:5000/kube-system"
  download_and_extract_packages = false
}