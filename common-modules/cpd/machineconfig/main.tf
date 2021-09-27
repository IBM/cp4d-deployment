locals {
  cpd_workspace      = "${var.installer_workspace}/cpd"
}

resource "local_file" "sysctl_worker_yaml" {
  content  = data.template_file.sysctl_worker.rendered
  filename = "${local.cpd_workspace}/sysctl_worker.yaml"
}
resource "local_file" "sysctl_machineconfig_yaml" {
  content  = data.template_file.sysctl_machineconfig.rendered
  filename = "${var.installer_workspace}/sysctl_machineconfig.yaml"
}

resource "local_file" "limits_machineconfig_yaml" {
  content  = data.template_file.limits_machineconfig.rendered
  filename = "${var.installer_workspace}/limits_machineconfig.yaml"
}

resource "local_file" "crio_machineconfig_yaml" {
  content  = data.template_file.crio_machineconfig.rendered
  filename = "${var.installer_workspace}/crio_machineconfig.yaml"
}

resource "null_resource" "login_cluster" {
  triggers = {
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    login_string        = var.login_string
  }
  provisioner "local-exec" {
    command = <<EOF
${self.triggers.login_string} || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
EOF
  }
  depends_on = [
    local_file.sysctl_worker_yaml,
    local_file.sysctl_machineconfig_yaml,
    local_file.limits_machineconfig_yaml,
    local_file.crio_machineconfig_yaml,
  ]
}

resource "null_resource" "patch_config_self" {
  count = var.cluster_type == "selfmanaged" && var.configure_openshift_nodes ? 1 : 0
  provisioner "local-exec" {
    command = <<EOF
echo "Patch configuration self"
oc patch machineconfigpool.machineconfiguration.openshift.io/worker --type merge -p '{"metadata":{"labels":{"db2u-kubelet": "sysctl"}}}'
EOF
  }
  depends_on = [
    local_file.sysctl_worker_yaml,
    local_file.sysctl_machineconfig_yaml,
    local_file.limits_machineconfig_yaml,
    local_file.crio_machineconfig_yaml,
    null_resource.login_cluster,
  ]
}

resource "null_resource" "patch_config_managed" {
  count = var.cluster_type == "managed" && var.configure_openshift_nodes ? 1 : 0
  provisioner "local-exec" {
    command = <<EOF
echo "Patch configuration self"
oc patch kubeletconfig custom-kubelet --type='json' -p='[{"op": "remove", "path": "/spec/machineConfigPoolSelector/matchLabels"}]'
oc patch kubeletconfig custom-kubelet --type merge -p '{"spec":{"machineConfigPoolSelector":{"matchLabels":{"pools.operator.machineconfiguration.openshift.io/master":""}}}}'
oc label machineconfigpool.machineconfiguration.openshift.io worker db2u-kubelet=sysctl
EOF
  }
  depends_on = [
    local_file.sysctl_worker_yaml,
    local_file.sysctl_machineconfig_yaml,
    local_file.limits_machineconfig_yaml,
    local_file.crio_machineconfig_yaml,
    null_resource.login_cluster,
  ]
}

resource "null_resource" "configure_global_pull_secret" {
  count = var.configure_global_pull_secret ? 1 : 0
  provisioner "local-exec" {
    command = <<EOF
echo "Configuring global pull secret"
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | sed -e 's|:{|:{"${var.cpd_external_registry}":{"username":"${var.cpd_external_username}","password":"${var.cpd_api_key}"},|' > /tmp/dockerconfig.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/dockerconfig.json

echo 'Sleeping for 5mins while global pull secret apply and the nodes restarts' 
sleep 300
EOF
  }
  depends_on = [
    local_file.sysctl_worker_yaml,
    local_file.sysctl_machineconfig_yaml,
    local_file.limits_machineconfig_yaml,
    local_file.crio_machineconfig_yaml,
    null_resource.login_cluster,
    null_resource.patch_config_self,
    null_resource.patch_config_managed,
  ]
}

resource "null_resource" "configure_cluster" {
  count = var.configure_openshift_nodes ? 1 : 0
  triggers = {
    installer_workspace = var.installer_workspace
    cpd_workspace       = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Sysctl changes"
oc apply -f ${self.triggers.cpd_workspace}/sysctl_worker.yaml

echo "Creating MachineConfig files"
oc create -f ${self.triggers.installer_workspace}/sysctl_machineconfig.yaml
oc create -f ${self.triggers.installer_workspace}/limits_machineconfig.yaml
oc create -f ${self.triggers.installer_workspace}/crio_machineconfig.yaml

echo 'Sleeping for 5mins while MachineConfigs apply and the nodes restarts' 
sleep 300
EOF
  }
  depends_on = [
    local_file.sysctl_worker_yaml,
    local_file.sysctl_machineconfig_yaml,
    local_file.limits_machineconfig_yaml,
    local_file.crio_machineconfig_yaml,
    null_resource.login_cluster,
    null_resource.patch_config_self,
    null_resource.patch_config_managed,
    null_resource.configure_global_pull_secret,
  ]
}
