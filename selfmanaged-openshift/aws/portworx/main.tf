resource "aws_kms_key" "px_key" {
  description = "Key used to encrypt Portworx PVCs"
}

resource "local_file" "portworx_subscription_yaml" {
  content  = data.template_file.portworx_subscription.rendered
  filename = "${var.installer_workspace}/portworx_subscription.yaml"
}

resource "local_file" "portworx_operator_group_yaml" {
  content  = data.template_file.portworx_operator_group.rendered
  filename = "${var.installer_workspace}/portworx_operator_group.yaml"
}

resource "local_file" "storage_classes_yaml" {
  content  = data.template_file.storage_classes.rendered
  filename = "${var.installer_workspace}/storage_classes.yaml"
}

resource "local_file" "portworx_storagecluster_yaml" {
  content  = data.template_file.portworx_storagecluster.rendered
  filename = "${var.installer_workspace}/portworx_storagecluster.yaml"
}

resource "null_resource" "install_portworx" {
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
oc create -f ${self.triggers.installer_workspace}/portworx_operator_group.yaml
oc create -f ${self.triggers.installer_workspace}/portworx_subscription.yaml
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
  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
echo "Logging in.."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server=${self.triggers.openshift_api} --token='${self.triggers.openshift_token}'
echo "Delete storage classes"
oc delete -f ${self.triggers.installer_workspace}/storage_classes.yaml
echo "Delete Storage Cluster"
oc delete -f ${self.triggers.installer_workspace}/portworx_storagecluster.yaml
echo "Delete Operator Group and Subscription."
oc delete -f ${self.triggers.installer_workspace}/portworx_operator_group.yaml
oc delete -f ${self.triggers.installer_workspace}/portworx_subscription.yaml
EOF
  }
  depends_on = [
    local_file.portworx_subscription_yaml,
    local_file.portworx_operator_group_yaml,
    local_file.storage_classes_yaml,
    local_file.portworx_storagecluster_yaml,
  ]
}
