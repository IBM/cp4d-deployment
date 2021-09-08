locals {
  classic_lb_timeout = 600
  cpd_workspace      = "${var.installer_workspace}/cpd"
  operator_namespace = "ibm-common-services"
  cpd_case_url       = "https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case"
  db2aaservice       = (var.datastage == "yes" || var.db2_aaservice == "yes" || var.watson_knowledge_catalog == "yes" ? "yes" : "no")
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
    openshift_api      = var.openshift_api
    openshift_username = var.openshift_username
    openshift_password = var.openshift_password
    login              = var.rosa_cluster ? "${var.login_cmd} --insecure-skip-tls-verify=true" : "oc login ${var.openshift_api} -u ${var.openshift_username} -p ${var.openshift_password} --insecure-skip-tls-verify=true"
  }
  provisioner "local-exec" {
    command = <<EOF
  ${self.triggers.login}
EOF
  }
}

resource "null_resource" "patch_config_self" {
  count = var.rosa_cluster ? 0 : 1
  provisioner "local-exec" {
    command = <<EOF
echo "Patch configuration self"
oc patch machineconfigpool.machineconfiguration.openshift.io/worker --type merge -p '{"metadata":{"labels":{"db2u-kubelet": "sysctl"}}}'
EOF
  }
  depends_on = [
    local_file.sysctl_machineconfig_yaml,
    local_file.limits_machineconfig_yaml,
    local_file.crio_machineconfig_yaml,
    null_resource.login_cluster,
  ]
}

resource "null_resource" "configure_cluster" {
  triggers = {
    installer_workspace = var.installer_workspace
    cpd_workspace       = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Configuring global pull secret"
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | sed -e 's|:{|:{"${var.cpd_external_registry}":{"username":"${var.cpd_external_username}","password":"${var.cpd_api_key}"},|' > /tmp/dockerconfig.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/dockerconfig.json

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
    local_file.sysctl_machineconfig_yaml,
    local_file.limits_machineconfig_yaml,
    local_file.crio_machineconfig_yaml,
    null_resource.login_cluster,
    null_resource.patch_config_self
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

resource "local_file" "cpd_operator_yaml" {
  content  = data.template_file.cpd_operator.rendered
  filename = "${local.cpd_workspace}/cpd_operator.yaml"
}

resource "local_file" "operand_requests_yaml" {
  content  = data.template_file.operand_requests.rendered
  filename = "${local.cpd_workspace}/operand_requests.yaml"
}

resource "local_file" "ibmcpd_cr_yaml" {
  content  = data.template_file.ibmcpd_cr.rendered
  filename = "${local.cpd_workspace}/ibmcpd_cr.yaml"
}

resource "local_file" "db2u_catalog_yaml" {
  content  = data.template_file.db2u_catalog.rendered
  filename = "${local.cpd_workspace}/db2u_catalog.yaml"
}

resource "null_resource" "cpd_foundational_services" {
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }

  provisioner "local-exec" {
    command = <<-EOF
echo "Ensure the nodes are running"
bash cpd/scripts/nodes_running.sh

echo "Create Operator Catalog Source"
oc create -f ${self.triggers.cpd_workspace}/ibm_operator_catalog_source.yaml

echo "create db2u operator catalog"
oc apply -f ${self.triggers.cpd_workspace}/db2u_catalog.yaml

echo "Waiting and checking till the ibm-operator-catalog is ready in the openshift-marketplace namespace"
bash cpd/scripts/pod-status-check.sh ibm-operator-catalog openshift-marketplace

echo "create cpd operator"
oc create -f  ${self.triggers.cpd_workspace}/cpd_operator.yaml

echo "Creating the ${self.triggers.namespace} namespace:"
oc new-project ${self.triggers.namespace}

echo "checking status of operand-deployment-lifecycle-manager"
bash cpd/scripts/bedrock-pod-status-check.sh operand-deployment-lifecycle-manager ${local.operator_namespace}

echo "Creating OperandRequests"
oc create -f  ${self.triggers.cpd_workspace}/operand_requests.yaml

echo "checking status of ibm-namespace-scope-operator"
bash cpd/scripts/bedrock-pod-status-check.sh ibm-namespace-scope-operator ${local.operator_namespace}

echo "checking status of ibm-common-service-operator"
bash cpd/scripts/bedrock-pod-status-check.sh ibm-common-service-operator ${local.operator_namespace}

echo "Create CPD CPD Platform CR"
oc project ${self.triggers.namespace}
sleep 1
oc create -f ${self.triggers.cpd_workspace}/ibmcpd_cr.yaml

echo "Check the CPD Platform CR status"
bash cpd/scripts/check-cr-status.sh Ibmcpd ibmcpd-cr ${var.cpd_namespace} controlPlaneStatus; if [ $? -ne 0 ] ; then echo \"CPD control plane failed to install\" ; exit 1 ; fi

echo "Enable CSV injector"
oc patch namespacescope common-service --type='json' -p='[{"op":"replace", "path": "/spec/csvInjector/enable", "value":true}]' -n ${local.operator_namespace}
EOF
  }
  depends_on = [
    local_file.ibmcpd_cr_yaml,
    local_file.operand_requests_yaml,
    local_file.cpd_operator_yaml,
    local_file.ibm_operator_catalog_source_yaml,
    local_file.db2u_catalog_yaml,
    null_resource.configure_cluster,
    null_resource.login_cluster,
    null_resource.patch_config_self
  ]
}

