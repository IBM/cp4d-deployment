locals {
  classic_lb_timeout = 600
  cpd_workspace      = "${var.installer_workspace}/cpd"
  operator_namespace = "ibm-common-services"
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
  }
  provisioner "local-exec" {
    command = <<EOF
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true
EOF
  }
}

resource "null_resource" "configure_cluster" {
  triggers = {
    installer_workspace = var.installer_workspace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Configuring global pull secret"
case $(uname -s) in
  Darwin)
    pull_secret=$(echo "cp:${var.api_key}" | base64 -)
    ;;
  Linux)
    pull_secret=$(echo -n "cp:${var.api_key}" | base64 -w0 -)
    ;;
  *)
    echo 'Supports only Linux and Mac OS at this time'
    exit 1;;
esac
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | sed -e 's|:{|:{"cp.icr.io":{"auth":"'$pull_secret'"},|' > /tmp/dockerconfig.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/dockerconfig.json

echo "Sysctl changes"
oc patch machineconfigpool.machineconfiguration.openshift.io/worker --type merge -p '{"metadata":{"labels":{"db2u-kubelet": "sysctl"}}}'
oc apply -f ${self.triggers.cpd_workspace}/sysctl_worker.yaml

echo "Creating MachineConfig files"
oc create -f ${self.triggers.installer_workspace}/sysctl_machineconfig.yaml
oc create -f ${self.triggers.installer_workspace}/limits_machineconfig.yaml
oc create -f ${self.triggers.installer_workspace}/crio_machineconfig.yaml

echo 'Sleeping for 10mins while MachineConfigs apply and the nodes restarts' 
sleep 600
EOF
  }
  depends_on = [
    local_file.sysctl_machineconfig_yaml,
    local_file.limits_machineconfig_yaml,
    local_file.crio_machineconfig_yaml,
    null_resource.login_cluster,
  ]
}

resource "null_resource" "download_cloudctl" {
  triggers = {
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
  echo "Download cloudctl."
case $(uname -s) in
  Darwin)
    wget https://github.com/IBM/cloud-pak-cli/releases/download/${var.cloudctl_version}/cloudctl-darwin-amd64.tar.gz -P ${self.triggers.cpd_workspace} -A 'cloudctl-darwin-amd64.tar.gz'
    wget https://github.com/IBM/cloud-pak-cli/releases/download/${var.cloudctl_version}/cloudctl-darwin-amd64.tar.gz.sig -P ${self.triggers.cpd_workspace} -A 'cloudctl-darwin-amd64.tar.gz.sig'
    tar -xvf ${self.triggers.cpd_workspace}/cloudctl-darwin-amd64.tar.gz -C ${self.triggers.cpd_workspace}
    mv ${self.triggers.cpd_workspace}/cloudctl-darwin-amd64 ${self.triggers.cpd_workspace}/cloudctl
    ;;
  Linux)
    wget https://github.com/IBM/cloud-pak-cli/releases/download/${var.cloudctl_version}/cloudctl-linux-amd64.tar.gz -P ${self.triggers.cpd_workspace} -A 'cloudctl-linux-amd64.tar.gz'
    wget https://github.com/IBM/cloud-pak-cli/releases/download/${var.cloudctl_version}/cloudctl-linux-amd64.tar.gz.sig -P ${self.triggers.cpd_workspace} -A 'cloudctl-linux-amd64.tar.gz.sig'
    tar -xvf ${self.triggers.cpd_workspace}/cloudctl-linux-amd64.tar.gz -C ${self.triggers.cpd_workspace}
    mv ${self.triggers.cpd_workspace}/cloudctl-linux-amd64 ${self.triggers.cpd_workspace}/cloudctl
    ;;
  *)
    echo 'Supports only Linux and Mac OS at this time'
    exit 1;;
esac
chmod u+x ${self.triggers.cpd_workspace}/cloudctl
EOF
  }
}

resource "local_file" "ibm_operator_catalog_source_yaml" {
  content  = data.template_file.ibm_operator_catalog_source.rendered
  filename = "${local.cpd_workspace}/ibm_operator_catalog_source.yaml"
}

resource "local_file" "ibm_common_services_operator_yaml" {
  content  = data.template_file.ibm_common_services_operator.rendered
  filename = "${local.cpd_workspace}/ibm_common_services_operator.yaml"
}

resource "local_file" "operand_requests_yaml" {
  content  = data.template_file.operand_requests.rendered
  filename = "${local.cpd_workspace}/operand_requests.yaml"
}

resource "local_file" "lite_cr_yaml" {
  content  = data.template_file.lite_cr.rendered
  filename = "${local.cpd_workspace}/lite_cr.yaml"
}

resource "null_resource" "cpd_foundational_services" {
  triggers = {
    namespace             = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }

  provisioner "local-exec" {
    command = <<-EOF
echo "Ensure the nodes are running"
bash cpd/scripts/nodes_running.sh

echo "Create Operator Catalog Source"
oc create -f ${self.triggers.cpd_workspace}/ibm_operator_catalog_source.yaml

echo "Waiting and checking till the ibm-operator-catalog is ready in the openshift-marketplace namespace"
bash cpd/scripts/pod-status-check.sh ibm-operator-catalog openshift-marketplace

echo "create ibm common service operator"
oc create -f  ${self.triggers.cpd_workspace}/ibm_common_services_operator.yaml
bash cpd/scripts/pod-status-check.sh ibm-common-service-operator ${local.operator_namespace}

echo "Creating the ${self.triggers.namespace} namespace:"
oc new-project ${self.triggers.namespace}

echo "checking status of operand-deployment-lifecycle-manager"
bash cpd/scripts/bedrock-pod-status-check.sh operand-deployment-lifecycle-manager ${local.operator_namespace}

echo "Creating OperandRequests"
oc create -f  ${self.triggers.cpd_workspace}/operand_requests.yaml

echo "Checking if the bedrock operator pods are ready and running."
echo "Waiting and checking till the ibm-zen-operator-catalog is ready in the openshift-marketplace namespace "
bash cpd/scripts/pod-status-check.sh ibm-zen-operator ${local.operator_namespace}

echo "checking status of ibm-namespace-scope-operator"
bash cpd/scripts/bedrock-pod-status-check.sh ibm-namespace-scope-operator ${local.operator_namespace}

echo "checking status of ibm-common-service-operator"
bash cpd/scripts/bedrock-pod-status-check.sh ibm-common-service-operator ${local.operator_namespace}

echo "check if the ibm-cert-manager-operator pod is up and running"
bash cpd/scripts/bedrock-pod-status-check.sh ibm-cert-manager-operator ${local.operator_namespace}

echo "Create lite zenservice"
oc project ${self.triggers.namespace}
sleep 1
oc create -f ${self.triggers.cpd_workspace}/lite_cr.yaml

echo "check the lite cr status"
bash cpd/scripts/check-cr-status.sh Ibmcpd ibmcpd-cr ${var.cpd_namespace} controlPlaneStatus
EOF
  }
  depends_on = [
    local_file.lite_cr_yaml,
    local_file.operand_requests_yaml,
    local_file.ibm_common_services_operator_yaml,
    local_file.ibm_operator_catalog_source_yaml,
    null_resource.configure_cluster,
    null_resource.login_cluster,
  ]
}

resource "local_file" "ccs_sub_yaml" {
  content  = data.template_file.ccs_sub.rendered
  filename = "${local.cpd_workspace}/ccs_sub.yaml"
}

resource "local_file" "ccs_cr_yaml" {
  content  = data.template_file.ccs_cr.rendered
  filename = "${local.cpd_workspace}/ccs_cr.yaml"
}

resource "local_file" "ccs_dr_catalogs_yaml" {
  content  = data.template_file.ccs_dr_catalogs.rendered
  filename = "${local.cpd_workspace}/ccs_dr_catalogs.yaml"
}

resource "null_resource" "install_ccs" {
  triggers = {
    namespace             = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }

  provisioner "local-exec" {
    command = <<-EOF
echo "Create CCS sub"
oc apply -f ${self.triggers.cpd_workspace}/ccs_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-ccs-operator ${local.operator_namespace}

echo "Create CCS CR"
oc apply -f ${self.triggers.cpd_workspace}/ccs_cr.yaml
sleep 3
bash cpd/scripts/check-cr-status.sh ccs ccs-cr ${var.cpd_namespace} ccsStatus

echo "create ibm-cpd-datarefinery and cpd-ccs catalogs"
oc apply -f ${self.triggers.cpd_workspace}/ccs_dr_catalogs.yaml
EOF
  }
  depends_on = [
    null_resource.configure_cluster,
    null_resource.cpd_foundational_services,
    local_file.ccs_sub_yaml,
    local_file.ccs_cr_yaml,
  ]
}