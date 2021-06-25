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


resource "local_file" "ccs_cr_yaml" {
  content  = data.template_file.ccs_cr.rendered
  filename = "${local.cpd_workspace}/ccs_cr.yaml"
}

resource "null_resource" "configure_cluster" {
  triggers = {
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    vpc_id              = var.vpc_id
    installer_workspace = var.installer_workspace
    login_cmd = var.login_cmd
  }
  provisioner "local-exec" {
    command = <<EOF
${self.triggers.login_cmd} --insecure-skip-tls-verify || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'

echo "Configuring global pull secret"
case $(uname -s) in
  Darwin)
    pull_secret=$(echo -n "cp:${var.api_key}" | base64 -)
    ;;
  Linux)
    pull_secret=$(echo -n "cp:${var.api_key}" | base64 -w0 -)
    ;;
  *)
    echo 'Supports only Linux and Mac OS at this time'
    exit 1;;
esac
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | sed -e 's|:{|:{"hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com":{"auth":"'$pull_secret'"\},|' > /tmp/dockerconfig.json
sed -i -e 's|:{|:{"cp.icr.io":{"auth":"'$pull_secret'"\},|' /tmp/dockerconfig.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/dockerconfig.json

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
  ]
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
    artifactory_username  = var.artifactory_username
    artifactory_apikey  = var.artifactory_apikey
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    cpd_workspace = local.cpd_workspace
    login_cmd = var.login_cmd
  }

  provisioner "local-exec" {
    command = <<-EOF
${self.triggers.login_cmd} --insecure-skip-tls-verify || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc create -f ${self.triggers.cpd_workspace}/ibm_operator_catalog_source.yaml

echo "Waiting and checking till the ibm-operator-catalog is ready in the openshift-marketplace namespace"
bash cpd/scripts/pod-status-check.sh ibm-operator-catalog openshift-marketplace

echo "create ibm common service operator"
oc create -f  ${self.triggers.cpd_workspace}/ibm_common_services_operator.yaml

echo "Creating the ${self.triggers.namespace} namespace:"
oc new-project ${self.triggers.namespace}

sleep 1

echo "Creating OperandRequests"
oc create -f  ${self.triggers.cpd_workspace}/operand_requests.yaml

echo "Checking if the bedrock operator pods are ready and running."
echo "Waiting and checking till the ibm-zen-operator-catalog is ready in the openshift-marketplace namespace "
bash cpd/scripts/pod-status-check.sh ibm-zen-operator ${local.operator_namespace}

echo "checking status of ibm-namespace-scope-operator"
bash cpd/scripts/bedrock-pod-status-check.sh ibm-namespace-scope-operator ${local.operator_namespace}

echo "checking status of operand-deployment-lifecycle-manager"
bash cpd/scripts/bedrock-pod-status-check.sh operand-deployment-lifecycle-manager ${local.operator_namespace}

echo "checking status of ibm-common-service-operator"
bash cpd/scripts/bedrock-pod-status-check.sh ibm-common-service-operator ${local.operator_namespace}

echo "check if the ibm-cert-manager-operator pod is up and running"
bash cpd/scripts/bedrock-pod-status-check.sh ibm-cert-manager-operator ${local.operator_namespace}

echo "Create lite zenservice"
oc project ${self.triggers.namespace}
sleep 1
oc create -f ${self.triggers.cpd_workspace}/lite_cr.yaml

echo "check the lite cr status"
bash cpd/scripts/check-cr-status.sh zenservice lite ${var.cpd-namespace} zenStatus
EOF
  }
  depends_on = [
    local_file.lite_cr_yaml,
    local_file.operand_requests_yaml,
    local_file.ibm_common_services_operator_yaml,
    local_file.ibm_operator_catalog_source_yaml,
    null_resource.configure_cluster,
    null_resource.append_custom_pull_secret,
  ]
}

resource "null_resource" "download_cloudctl" {
  triggers = {
    namespace = var.cpd_namespace
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    cpd_workspace = local.cpd_workspace
    login_cmd = var.login_cmd
  }
  provisioner "local-exec" {
    command = <<-EOF
  echo "Download cloudctl and aiopenscale case package."
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


resource "local_file" "ccs_sub_yaml" {
  content  = data.template_file.ccs_sub.rendered
  filename = "${local.cpd_workspace}/ccs_sub.yaml"
}

resource "local_file" "ccs_cr_yaml" {
  content  = data.template_file.ccs_cr.rendered
  filename = "${local.cpd_workspace}/ccs_cr.yaml"
}

resource "null_resource" "install_ccs" {
  triggers = {
    namespace             = var.cpd_namespace
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    cpd_workspace = local.cpd_workspace
    login_cmd = var.login_cmd
  }

  provisioner "local-exec" {
    command = <<-EOF
${self.triggers.login_cmd} --insecure-skip-tls-verify || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'

echo "Create CCS sub"
oc apply -f ${self.triggers.cpd_workspace}/ccs_sub.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-ccs-operator ${local.operator_namespace}

echo "Create CCS CR"
oc apply -f ${self.triggers.cpd_workspace}/ccs_cr.yaml
sleep 3
bash cpd/scripts/check-cr-status.sh ccs ccs ${var.cpd_namespace} ccsStatus

EOF
  }
  depends_on = [
    null_resource.configure_cluster,
    null_resource.append_custom_pull_secret,
    null_resource.cpd_foundational_services,
    local_file.ccs_sub_yaml,
    local_file.ccs_cr_yaml,
    null_resource.download_cloudctl,
  ]
}

resource "local_file" "wkc_cr_yaml" {
  content  = data.template_file.wkc_cr.rendered
  filename = "${local.cpd_workspace}/wkc_cr.yaml"
}

resource "local_file" "db2aaservice_cr_yaml" {
  content  = data.template_file.db2aaservice_cr.rendered
  filename = "${local.cpd_workspace}/db2aaservice_cr.yaml"
}

resource "local_file" "wkc_iis_scc_yaml" {
  content  = data.template_file.wkc_iis_scc.rendered
  filename = "${local.cpd_workspace}/wkc_iis_scc.yaml"
}

resource "local_file" "wkc_iis_cr_yaml" {
  content  = data.template_file.wkc_iis_cr.rendered
  filename = "${local.cpd_workspace}/wkc_iis_cr.yaml"
}

resource "local_file" "wkc_ug_cr_yaml" {
  content  = data.template_file.wkc_ug_cr.rendered
  filename = "${local.cpd_workspace}/wkc_ug_cr.yaml"
}

resource "local_file" "sysctl_worker_yaml" {
  content  = data.template_file.sysctl_worker.rendered
  filename = "${local.cpd_workspace}/sysctl_worker.yaml"
}

resource "null_resource" "install_wkc" {
  count = var.spss_modeler == "yes" ? 1 : 0
  triggers = {
    namespace             = var.cpd_namespace
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    cpd_workspace = local.cpd_workspace
    login_cmd = var.login_cmd
  }
  provisioner "local-exec" {
    command = <<-EOF
${self.triggers.login_cmd} --insecure-skip-tls-verify || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'

oc patch machineconfigpool.machineconfiguration.openshift.io/worker --type merge -p '{"metadata":{"labels":{"db2u-kubelet": "sysctl"}}}'
oc apply -f ${self.triggers.cpd_workspace}/sysctl_worker.yaml
sleep 60
bash cpd/scripts/nodes_running.sh

echo "Download DB2aaservice package"
curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-db2aaservice/4.0.0-1228.749/ibm-db2aaservice-4.0.0-1228.749.tgz -o ${self.triggers.cpd_workspace}/ibm-db2aaservice-4.0.0-1228.749.tgz
curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-db2uoperator/4.0.0-3731.2407/ibm-db2uoperator-4.0.0-3731.2407.tgz -o ${self.triggers.cpd_workspace}/ibm-db2uoperator-4.0.0-3731.2407.tgz

echo "Install DB2Operator operator using CLI (OLM)"
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-db2uoperator-4.0.0-3731.2407.tgz --tolerance 1 --namespace openshift-marketplace --inventory db2uOperatorSetup --action installCatalog
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-db2uoperator-4.0.0-3731.2407.tgz --tolerance 1 --namespace ${local.operator_namespace} --action installOperator --inventory db2uOperatorSetup
echo "Checking if the DB2 operator pods are ready and running."
echo "checking status of db2u-operator"
bash cpd/scripts/pod-status-check.sh db2u-operator ${local.operator_namespace}

echo "Install DB2aaService operator using CLI (OLM)"
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-db2aaservice-4.0.0-1228.749.tgz --tolerance 1 --namespace openshift-marketplace --inventory db2aaserviceOperatorSetup --action installCatalog
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-db2aaservice-4.0.0-1228.749.tgz --tolerance 1 --namespace ${local.operator_namespace} --action installOperator --inventory db2aaserviceOperatorSetup
echo "Checking if the DB2 as a service pods are ready and running."
echo "checking status of db2aaservice-cp4d-operator"
bash cpd/scripts/pod-status-check.sh db2aaservice-cp4d-operator ${local.operator_namespace}

echo "switch to ${var.cpd_namespace} namespace"
oc project ${var.cpd_namespace}

echo 'Create DB2aaservice CR'
oc create -f ${self.triggers.cpd_workspace}/db2aaservice_cr.yaml

echo 'check the SPSS cr status'
bash cpd/scripts/check-cr-status.sh Db2aaserviceService db2aaservice-cr ${var.cpd_namespace} db2aaserviceStatus


echo "Install WKC operator using CLI (OLM)"
curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-wkc/4.0.0-423/ibm-wkc-4.0.0-423.tgz -o ${self.triggers.cpd_workspace}/ibm-wkc-4.0.0-423.tgz

${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-wkc-4.0.0-423.tgz --tolerance 1 --namespace ${local.operator_namespace} --action installOperator --inventory wkcOperatorSetup
echo "Checking if the WKC are ready and running."
echo "checking status of ibm-cpd-wkc-operator"
bash cpd/scripts/pod-status-check.sh ibm-cpd-wkc-operator ${local.operator_namespace}

echo "switch to ${var.cpd_namespace} namespace"
oc project ${var.cpd_namespace}

echo 'Create WKC Core CR'
oc create -f ${self.triggers.cpd_workspace}/wkc_cr.yaml

echo 'check the WKC Core cr status'
bash cpd/scripts/check-cr-status.sh wkc wkc-cr ${var.cpd_namespace} wkcStatus

echo "##########"

echo "Create SCC for WKC-IIS"
oc create -f ${self.triggers.cpd_workspace}/wkc_iis_scc.yaml

echo "Install IIS operator"
curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-iis/4.0.0-359/ibm-iis-4.0.0-359.tgz -o ${self.triggers.cpd_workspace}/ibm-iis-4.0.0-359.tgz

${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-iis-4.0.0-359.tgz --tolerance 1 --namespace ${local.operator_namespace} --action installOperator --inventory iisOperatorSetup
echo "Checking if the WKC are ready and running."
echo "checking status of ibm-cpd-iis-operator"
bash cpd/scripts/pod-status-check.sh ibm-cpd-iis-operator ${local.operator_namespace}

echo "Create iis cr"
oc create -f ${self.triggers.cpd_workspace}/wkc_iis_cr_yaml
EOF
  }
  depends_on = [
    local_file.wkc_cr_yaml,
    local_file.db2aaservice_cr_yaml,
    local_file.wkc_iis_scc_yaml,
    local_file.wkc_iis_cr_yaml,
    local_file.wkc_ug_cr_yaml,
    null_resource.configure_cluster,
    null_resource.append_custom_pull_secret,
    null_resource.install_ccs,
    null_resource.download_cloudctl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wsl,
    null_resource.install_spss,
  ]
}