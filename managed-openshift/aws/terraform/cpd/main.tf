locals {
  classic_lb_timeout = 600
  cpd_workspace      = "${var.installer_workspace}/cpd"
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

resource "local_file" "bedrock_setup_yaml" {
  content  = data.template_file.bedrock_setup.rendered
  filename = "${local.cpd_workspace}/bedrock_setup.yaml"
}

resource "local_file" "operand_registry_yaml" {
  content  = data.template_file.operand_registry.rendered
  filename = "${local.cpd_workspace}/operand_registry.yaml"
}

resource "local_file" "zen_setup_yaml" {
  content  = data.template_file.zen_setup.rendered
  filename = "${local.cpd_workspace}/zen_setup.yaml"
}

resource "local_file" "zen_service_lite_yaml" {
  content  = data.template_file.zen_service_lite.rendered
  filename = "${local.cpd_workspace}/zen_service_lite.yaml"
}

# resource "null_resource" "configure_cluster" {
#   triggers = {
#     openshift_api       = var.openshift_api
#     openshift_username  = var.openshift_username
#     openshift_password  = var.openshift_password
#     openshift_token     = var.openshift_token
#     vpc_id              = var.vpc_id
#     installer_workspace = var.installer_workspace
#     login_cmd = var.login_cmd
#   }
#   provisioner "local-exec" {
#     command = <<EOF
# ${self.triggers.login_cmd} --insecure-skip-tls-verify || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
# oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true,"replicas":3}}' -n openshift-image-registry
# oc patch svc/image-registry -p '{"spec":{"sessionAffinity": "ClientIP"}}' -n openshift-image-registry
# oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"managementState":"Unmanaged"}}'
# echo 'Sleeping for 30s'
# sleep 30
# oc annotate route default-route haproxy.router.openshift.io/timeout=600s -n openshift-image-registry
# oc set env deployment/image-registry -n openshift-image-registry REGISTRY_STORAGE_S3_CHUNKSIZE=104857600
# echo 'Sleeping for 20s'
# sleep 20
# bash scripts/update-elb-timeout.sh ${self.triggers.vpc_id} ${local.classic_lb_timeout}
# echo "Creating MachineConfig files"
# oc create -f ${self.triggers.installer_workspace}/sysctl_machineconfig.yaml
# oc create -f ${self.triggers.installer_workspace}/limits_machineconfig.yaml
# oc create -f ${self.triggers.installer_workspace}/crio_machineconfig.yaml
# echo 'Sleeping for 10mins while MachineConfigs apply and the nodes restarts' 
# sleep 600
# EOF
#   }
#   depends_on = [
#     local_file.sysctl_machineconfig_yaml,
#     local_file.limits_machineconfig_yaml,
#     local_file.crio_machineconfig_yaml,
#   ]
# }

resource "null_resource" "bedrock_zen_operator" {
  triggers = {
    namespace             = var.cpd_namespace
    artifactory_username = var.artifactory_username
    artifactory_apikey = var.artifactory_apikey
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    vpc_id              = var.vpc_id
    cpd_workspace = local.cpd_workspace
    login_cmd = var.login_cmd
  }

  provisioner "local-exec" {
    command = <<-EOF
${self.triggers.login_cmd} --insecure-skip-tls-verify || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
bash scripts/setup-global-pull-secret-bedrock.sh ${var.artifactory_username} ${var.artifactory_apikey}
echo 'Waiting 15 minutes for the nodes to get ready'
sleep 15m
echo "Set up image mirroring. Adding bootstrap artifactory so that the cluster can pull un-promoted catalog images (and zen images)"
oc create -f ${self.triggers.cpd_workspace}/bedrock_setup.yaml
echo "Checking if the bedrock operator pods are ready and running."
bash scripts/pod-status-check.sh opencloud-operator openshift-marketplace
echo "checking status of ibm-common-service-operator"
bash scripts/pod-status-check.sh ibm-common-service-operator ibm-common-services
echo "checking status of operand-deployment-lifecycle-manager"
bash scripts/pod-status-check.sh operand-deployment-lifecycle-manager ibm-common-services
echo "checking status of ibm-namespace-scope-operator"
bash scripts/pod-status-check.sh ibm-namespace-scope-operator ibm-common-services
echo "Edit Operand Registry"
oc apply -f ${self.triggers.cpd_workspace}/operand_registry.yaml
echo "Setup Zen artifacts: Namespace, CatalogSource and OperandRequest"
oc create -f ${self.triggers.cpd_workspace}/zen_setup.yaml
echo "Sleeping for 5 mins"
sleep 5m
echo "check if the zen operator pod is up and running."
bash scripts/pod-status-check.sh ibm-zen-operator ibm-common-services
bash scripts/pod-status-check.sh ibm-cert-manager-operator ibm-common-services
oc project zen
echo "Create Lite CR"
oc create -f ${self.triggers.cpd_workspace}/zen_service_lite.yaml
EOF
  }
  depends_on = [
    local_file.bedrock_setup_yaml,
    local_file.operand_registry_yaml,
    local_file.zen_setup_yaml,
    local_file.zen_service_lite_yaml,
    # null_resource.configure_cluster,
  ]
}