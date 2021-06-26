resource "local_file" "ocs_olm_yaml" {
  content  = data.template_file.ocs_olm.rendered
  filename = "${var.installer_workspace}/ocs_olm.yaml"
}

resource "local_file" "ocs_storagecluster_yaml" {
  content  = data.template_file.ocs_storagecluster.rendered
  filename = "${var.installer_workspace}/ocs_storagecluster.yaml"
}

resource "local_file" "ocs_toolbox_yaml" {
  content  = data.template_file.ocs_toolbox.rendered
  filename = "${var.installer_workspace}/ocs_toolbox.yaml"
}

resource "null_resource" "create_ocs_machinepool" {
  triggers = {
    installer_workspace = var.installer_workspace
    cluster_name        = var.cluster_name
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
${self.triggers.installer_workspace}/rosa create machinepool --cluster=${self.triggers.cluster_name} --name=workerocs --instance-type='${var.ocs_instance_type}' --replicas=3 --labels='cluster.ocs.openshift.io/openshift-storage=,node-role.kubernetes.io/infra=' --taints='node.ocs.openshift.io/storage=true:NoSchedule'
echo "Sleeping 5mins for new OCS nodes to become ready"
sleep 300
EOF
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
#${self.triggers.installer_workspace}/rosa delete machinepool --cluster=${self.triggers.cluster_name} workerocs 
EOF
  }
}

resource "null_resource" "login_cluster" {
  triggers = {
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    login_cmd = var.login_cmd
  }
  provisioner "local-exec" {
    command = <<EOF
${self.triggers.login_cmd} --insecure-skip-tls-verify || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
EOF
  }
}

resource "null_resource" "install_ocs" {
  triggers = {
    installer_workspace = var.installer_workspace
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOF
echo "Creating namespace, operator group and subscription"
oc create -f ${self.triggers.installer_workspace}/ocs_olm.yaml
echo "Sleeping for 5mins"
sleep 300
echo "Creating storagecluster"
oc create -f ${self.triggers.installer_workspace}/ocs_storagecluster.yaml
echo "Sleeping for 2min"
sleep 120
echo "Creating OCS toolbox"
oc create -f ${self.triggers.installer_workspace}/ocs_toolbox.yaml
echo "Sleeping for 5mins"
sleep 300
EOF
  }
#   provisioner "local-exec" {
#     when    = destroy
#     command = <<EOF
# echo "Logging in.."
# ${self.triggers.login_cmd} --insecure-skip-tls-verify || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server=${self.triggers.openshift_api} --token=${self.triggers.openshift_token}
# echo "Delete OCS toolbox"
# oc delete -f ${self.triggers.installer_workspace}/ocs_toolbox.yaml
# echo "Delete storagecluster"
# oc delete -f ${self.triggers.installer_workspace}/ocs_storagecluster.yaml
# echo "Delete Operator Group and Subscription."
# oc delete -f ${self.triggers.installer_workspace}/ocs_olm.yaml
# EOF
#   }
  depends_on = [
    local_file.ocs_olm_yaml,
    local_file.ocs_storagecluster_yaml,
    local_file.ocs_toolbox_yaml,
    null_resource.create_ocs_machinepool,
    null_resource.login_cluster,
  ]
}

locals {
  login_cmd = var.login_cmd
}
