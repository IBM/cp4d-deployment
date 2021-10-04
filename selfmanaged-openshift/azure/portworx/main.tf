resource "local_file" "px_install_yaml" {
  content  = data.template_file.px_install_yaml.rendered
  filename = "${var.installer_workspace}/px-install.yaml"
}

resource "local_file" "px_storage_classes" {
  content  = data.template_file.px_storage_classes.rendered
  filename = "${var.installer_workspace}/px-storageclasses.yaml"
}


resource "local_file" "px_secure_storage_classes" {
  content  = data.template_file.px_secure_storage_classes.rendered
  filename = "${var.installer_workspace}/px-storageclasses-secure.yaml"
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
oc create -f ${self.triggers.installer_workspace}/px-install.yaml
echo "Sleeping for 1min"
sleep 60
echo "Deploying PX cluster using spec url"
oc apply -f "${var.portworx-spec-url}"
echo 'Sleeping for 5 mins to get portworx storage cluster up' 
sleep 5m
EOF
  }
  depends_on = [
    local_file.px_install_yaml,
    local_file.px_storage_classes,
    local_file.px_secure_storage_classes,
  ]
}

resource "null_resource" "setup_sc_without_pwx_encryption" {
  count = var.storage == "portworx" && var.portworx-encryption == "no" ? 1 : 0
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
result=$(oc create -f ${self.triggers.installer_workspace}/px-storageclasses.yaml)
echo $result
EOF
  }
  depends_on = [
    local_file.px_install_yaml,
    local_file.px_storage_classes,
    local_file.px_secure_storage_classes,
    null_resource.install_portworx,
  ]
}

resource "null_resource" "setup_sc_with_pwx_encryption" {
  count = var.storage == "portworx" && var.portworx-encryption == "yes" && var.portworx-encryption-key != "" ? 1 : 0
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
result=$(oc -n kube-system create secret generic px-vol-encryption --from-literal=cluster-wide-secret-key=${var.portworx-encryption-key})
echo $result
PX_POD=$(oc get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
echo $PX_POD
result=$(oc exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl secrets set-cluster-key --secret cluster-wide-secret-key)
echo $result
result=$(oc create -f ${self.triggers.installer_workspace}/px-storageclasses-secure.yaml)
echo $result
EOF
  }
  depends_on = [
    local_file.px_install_yaml,
    local_file.px_storage_classes,
    local_file.px_secure_storage_classes,
    null_resource.install_portworx,
    null_resource.setup_sc_without_pwx_encryption,
  ]
}