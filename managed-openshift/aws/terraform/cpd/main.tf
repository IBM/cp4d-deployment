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

resource "local_file" "cpd_mirror_yaml" {
  content  = data.template_file.cpd_mirror.rendered
  filename = "${local.cpd_workspace}/cpd_mirror.yaml"
}

resource "local_file" "bedrock_catalog_source_yaml" {
  content  = data.template_file.bedrock_catalog_source.rendered
  filename = "${local.cpd_workspace}/bedrock_catalog_source.yaml"
}

resource "local_file" "cpd_platform_operator_catalogsource_yaml" {
  content  = data.template_file.cpd_platform_operator_catalogsource.rendered
  filename = "${local.cpd_workspace}/cpd_platform_operator_catalogsource.yaml"
}

resource "local_file" "cpd_platform_operator_setup_yaml" {
  content  = data.template_file.cpd_platform_operator_setup.rendered
  filename = "${local.cpd_workspace}/cpd_platform_operator_setup.yaml"
}

resource "local_file" "operand_registry_yaml" {
  content  = data.template_file.operand_registry.rendered
  filename = "${local.cpd_workspace}/operand_registry.yaml"
}

resource "local_file" "cpd_platform_operator_operandrequest_yaml" {
  content  = data.template_file.cpd_platform_operator_operandrequest.rendered
  filename = "${local.cpd_workspace}/cpd_platform_operator_operandrequest.yaml"
}

resource "local_file" "zen_catalog_source_yaml" {
  content  = data.template_file.zen_catalog_source.rendered
  filename = "${local.cpd_workspace}/zen_catalog_source.yaml"
}

resource "local_file" "ibm_cpd_lite_yaml" {
  content  = data.template_file.ibm_cpd_lite.rendered
  filename = "${local.cpd_workspace}/ibm_cpd_lite.yaml"
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
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true,"replicas":3}}' -n openshift-image-registry
oc patch svc/image-registry -p '{"spec":{"sessionAffinity": "ClientIP"}}' -n openshift-image-registry
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"managementState":"Unmanaged"}}'
echo 'Sleeping for 30s'
sleep 30
oc annotate route default-route haproxy.router.openshift.io/timeout=600s -n openshift-image-registry
oc set env deployment/image-registry -n openshift-image-registry REGISTRY_STORAGE_S3_CHUNKSIZE=104857600
echo 'Sleeping for 20s'
sleep 20
bash cpd/scripts/update-elb-timeout.sh ${self.triggers.vpc_id} ${local.classic_lb_timeout}
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

resource "null_resource" "append_custom_pull_secret" {
  triggers = {
    artifactory_username = var.artifactory_username
    artifactory_apikey = var.artifactory_apikey
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    login_cmd = var.login_cmd
    cpd_workspace = local.cpd_workspace
  }  
  provisioner "local-exec" {
    command = <<-EOF
${self.triggers.login_cmd} --insecure-skip-tls-verify || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc create -f ${self.triggers.cpd_workspace}/cpd_mirror.yaml
echo "Set up image mirroring. Adding bootstrap artifactory so that the cluster can pull un-promoted catalog images (and zen images)"
bash cpd/scripts/setup-global-pull-secret-bedrock.sh ${var.artifactory_username} ${var.artifactory_apikey}
echo 'Waiting 15 minutes for the nodes to get ready'
sleep 900
EOF
  }
  depends_on = [
    /* null_resource.configure_cluster, */
  ]
}

resource "null_resource" "bedrock_zen_operator" {
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
oc create -f ${self.triggers.cpd_workspace}/bedrock_catalog_source.yaml

echo "Waiting and checking till the opencloud operator is ready in the openshift-marketplace namespace"
bash cpd/scripts/pod-status-check.sh opencloud-operator openshift-marketplace

echo "create cpd-platform catalog source"
oc create -f  ${self.triggers.cpd_workspace}/cpd_platform_operator_catalogsource.yaml

echo "Waiting and checking till the cpd-platform operator is ready in the openshift-marketplace namespace "
bash cpd/scripts/pod-status-check.sh cpd-platform openshift-marketplace

echo "Creating zen catalog source"
oc create -f  ${self.triggers.cpd_workspace}/zen_catalog_source.yaml

echo "Waiting and checking till the ibm-zen-operator-catalog is ready in the openshift-marketplace namespace "
bash cpd/scripts/pod-status-check.sh ibm-zen-operator-catalog openshift-marketplace

echo "Creating the ${local.operator_namespace} namespace:"
oc new-project ${self.triggers.namespace}
oc new-project ${local.operator_namespace}

sleep 10

echo "Create cpd-platform-operator subscription. This will deploy the bedrock and zen: "
oc create -f ${self.triggers.cpd_workspace}/cpd_platform_operator_setup.yaml

echo "Waiting and checking till the cpd-platform-operator-manager pod is up in ibm-common-services namespace."
bash cpd/scripts/pod-status-check.sh cpd-platform-operator-manager ${local.operator_namespace}

echo "Checking if the bedrock operator pods are ready and running."
echo "checking status of ibm-namespace-scope-operator"
bash cpd/scripts/bedrock-pod-status-check.sh ibm-namespace-scope-operator ${local.operator_namespace}

echo "checking status of operand-deployment-lifecycle-manager"
bash cpd/scripts/bedrock-pod-status-check.sh operand-deployment-lifecycle-manager ${local.operator_namespace}

echo "checking status of ibm-common-service-operator"
bash cpd/scripts/bedrock-pod-status-check.sh ibm-common-service-operator ${local.operator_namespace}

#oc apply -f ${self.triggers.cpd_workspace}/operand_registry.yaml
sleep 2
echo "Create cpd-platform-operator operand request. This creates the zen operator."
oc create -f ${self.triggers.cpd_workspace}/cpd_platform_operator_operandrequest.yaml

echo "Create lite ibmcpd-cr"
oc project ${self.triggers.namespace}
sleep 2
oc create -f ${self.triggers.cpd_workspace}/ibm_cpd_lite.yaml

echo "check if the zen operator pod is up and running"
bash cpd/scripts/bedrock-pod-status-check.sh ibm-zen-operator ${local.operator_namespace}
bash cpd/scripts/bedrock-pod-status-check.sh ibm-cert-manager-operator ${local.operator_namespace}

echo "check the lite cr status"
bash cpd/scripts/check-cr-status.sh ibmcpd ibmcpd-cr ${self.triggers.namespace} controlPlaneStatus
EOF
  }
  depends_on = [
    local_file.cpd_mirror_yaml,
    local_file.bedrock_catalog_source_yaml,
    local_file.cpd_platform_operator_catalogsource_yaml,
    local_file.cpd_platform_operator_setup_yaml,
    local_file.operand_registry_yaml,
    local_file.cpd_platform_operator_operandrequest_yaml,
    local_file.zen_catalog_source_yaml,
    local_file.ibm_cpd_lite_yaml,
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

echo "Downloading CCS package"
wget https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-ccs/1.0.0-746/ibm-ccs-1.0.0-746.tgz -P ${self.triggers.cpd_workspace} -A 'ibm-ccs-1.0.0-746.tgz'

${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-ccs-1.0.0-746.tgz --tolerance 1 --namespace ${local.operator_namespace} --action installOperator --inventory ccsSetup --args "--registry cp.stg.icr.io"

bash cpd/scripts/pod-status-check.sh ibm-cpd-ccs-operator ${local.operator_namespace}

oc project ${var.cpd_namespace}

oc create -f ${self.triggers.cpd_workspace}/ccs_cr.yaml
bash cpd/scripts/check-cr-status.sh ccs ccs-cr ${var.cpd_namespace} ccsStatus

EOF
  }
  depends_on = [
    local_file.cpd_mirror_yaml,
    local_file.bedrock_catalog_source_yaml,
    local_file.cpd_platform_operator_catalogsource_yaml,
    local_file.cpd_platform_operator_setup_yaml,
    local_file.operand_registry_yaml,
    local_file.cpd_platform_operator_operandrequest_yaml,
    local_file.zen_catalog_source_yaml,
    local_file.ibm_cpd_lite_yaml,
    null_resource.configure_cluster,
    null_resource.append_custom_pull_secret,
    null_resource.bedrock_zen_operator,
    local_file.ccs_cr,
    null_resource.download_cloudctl,
  ]
}


resource "local_file" "openscale_cr_yaml" {
  content  = data.template_file.openscale_cr.rendered
  filename = "${local.cpd_workspace}/openscale_cr.yaml"
}

resource "null_resource" "install_aiopenscale" {
  count = var.watson_ai_openscale == "yes" ? 1 : 0
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

echo "Download Case package"
wget https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/blob/4.0.0/local/case-repo-local/ibm-watson-openscale/2.0.0-237/ibm-watson-openscale-2.0.0-237.tgz -P ${self.triggers.cpd_workspace} -A 'ibm-watson-openscale-2.0.0-237.tgz'

echo "Install OpenScale operator using CLI (OLM)"
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-watson-openscale-2.0.0-237.tgz --tolerance 1 --namespace ${local.operator_namespace}

echo "Checking if the openscale operator pods are ready and running."
echo "checking status of ibm-watson-openscale-operator"
bash cpd/scripts/pod-status-check.sh ibm-cpd-wos-operator ${local.operator_namespace}

echo "switch to ${var.cpd_namespace} namespace"
oc project ${var.cpd_namespace}

echo 'Create aiopenscale CR'
oc create -f ${self.triggers.cpd_workspace}/openscale_cr.yaml

# check the aiopenscale cr status
bash cpd/scripts/check-cr-status.sh WOService aiopenscale ${var.cpd_namespace} wosStatus
EOF
  }
    depends_on = [
    local_file.openscale_cr_yaml,
    null_resource.configure_cluster,
    null_resource.append_custom_pull_secret,
    null_resource.install_ccs,
    null_resource.download_cloudctl,
  ]
}


resource "local_file" "wml_cr_yaml" {
  content  = data.template_file.wml_cr.rendered
  filename = "${local.cpd_workspace}/wml_cr.yaml"
}

resource "null_resource" "install_wml" {
  count = var.watson_machine_learning == "yes" ? 1 : 0
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

echo "Download Case package"
curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-wml-cpd/4.0.0-1376/ibm-wml-cpd-4.0.0-1376.tgz -o ${self.triggers.cpd_workspace}/ibm-wml-cpd-4.0.0-1376.tgz

echo "Install wml operator using CLI (OLM)"
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-wml-cpd-4.0.0-1376.tgz --tolerance 1 --inventory wmlOperatorSetup --action installCatalog --namespace openshift-marketplace

${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-wml-cpd-4.0.0-1376.tgz --tolerance 1 --inventory wmlOperatorSetup --action install --namespace ${local.operator_namespace}

echo "Checking if the wml operator pods are ready and running."
echo "checking status of ibm-cpd-wml-operator"
bash cpd/scripts/pod-status-check.sh ibm-cpd-wml-operator ${local.operator_namespace}

echo "switch to ${var.cpd_namespace} namespace"
oc project ${var.cpd_namespace}

echo 'Create wml CR'
oc create -f ${self.triggers.cpd_workspace}/wml_cr.yaml

# check the wml cr status
bash cpd/scripts/check-cr-status.sh WmlBase wml-cr ${var.cpd_namespace} wmlStatus
EOF
  }
    depends_on = [
    local_file.openscale_cr_yaml,
    null_resource.configure_cluster,
    null_resource.append_custom_pull_secret,
    null_resource.install_ccs,
    null_resource.download_cloudctl,
    null_resource.install_aiopenscale,
  ]
}

resource "local_file" "wsl_cr_yaml" {
  content  = data.template_file.wsl_cr.rendered
  filename = "${local.cpd_workspace}/wsl_cr.yaml"
}

resource "local_file" "wsl_resolvers_yaml" {
  content  = data.template_file.wsl_resolvers.rendered
  filename = "${local.cpd_workspace}/resolvers.yaml"
}

resource "local_file" "wsl_resolverAuth_yaml" {
  content  = data.template_file.wsl_resolverAuth.rendered
  filename = "${local.cpd_workspace}/resolverAuth.yaml"
}

resource "null_resource" "install_wsl" {
  count = var.watson_studio_local == "yes" ? 1 : 0
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

export CASECTL_RESOLVERS_LOCATION=${self.triggers.cpd_workspace}/resolvers.yaml
export CASECTL_RESOLVERS_AUTH_LOCATION=${self.triggers.cpd_workspace}/resolversAuth.yaml

echo "Download Case package"
curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-wsl/2.0.0-382/ibm-wsl-2.0.0-382.tgz -o ${self.triggers.cpd_workspace}/ibm-wsl-2.0.0-382.tgz

echo "Install wsl operator using CLI (OLM)"
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-wsl-2.0.0-382.tgz --tolerance 1 --namespace ${local.operator_namespace} --action installCatalog --inventory wslSetup

${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-wsl-2.0.0-382.tgz --tolerance 1 --namespace ${local.operator_namespace} --action installOperator --inventory wslSetup

echo "Checking if the wml operator pods are ready and running."
echo "checking status of ibm-cpd-ws-operator"
bash cpd/scripts/pod-status-check.sh ibm-cpd-ws-operator ${local.operator_namespace}

echo "switch to ${var.cpd_namespace} namespace"
oc project ${var.cpd_namespace}

echo 'Create wsl CR'
oc create -f ${self.triggers.cpd_workspace}/wsl_cr.yaml

# check the wsl cr status
bash cpd/scripts/check-cr-status.sh WS ws-cr ${var.cpd_namespace} wsStatus
EOF
  }
    depends_on = [
    local_file.openscale_cr_yaml,
    null_resource.configure_cluster,
    null_resource.append_custom_pull_secret,
    null_resource.install_ccs,
    null_resource.download_cloudctl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
  ]
}

resource "local_file" "spss_cr_yaml" {
  content  = data.template_file.spss_cr.rendered
  filename = "${local.cpd_workspace}/spss_cr.yaml"
}

resource "null_resource" "install_spss" {
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

echo "Download Case package"
curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-spss/1.0.0-107/ibm-spss-1.0.0-107.tgz -o ${self.triggers.cpd_workspace}/ibm-spss-1.0.0-107.tgz

echo "Install spss operator using CLI (OLM)"
${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-spss-1.0.0-153.tgz --tolerance 1  --namespace openshift-marketplace --inventory spssSetup --action installCatalog

${self.triggers.cpd_workspace}/cloudctl case launch --case ${self.triggers.cpd_workspace}/ibm-spss-1.0.0-153.tgz --tolerance 1 --namespace ${local.operator_namespace} --action installOperator --inventory spssSetup --args "--registry cp.stg.icr.io"

echo "Checking if the spss operator pods are ready and running."
echo "checking status of spss-controller-manager"
bash cpd/scripts/pod-status-check.sh spss-controller-manager ${local.operator_namespace}

echo "switch to ${var.cpd_namespace} namespace"
oc project ${var.cpd_namespace}

echo 'Create SPSS CR'
oc create -f ${self.triggers.cpd_workspace}/spss_cr.yaml

echo 'check the SPSS cr status'
bash cpd/scripts/check-cr-status.sh Spss spss-cr ${var.cpd_namespace} spssmodelerStatus
EOF
  }
  depends_on = [
    local_file.spss_cr_yaml,
    null_resource.configure_cluster,
    null_resource.append_custom_pull_secret,
    null_resource.install_ccs,
    null_resource.download_cloudctl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wsl,
  ]
}