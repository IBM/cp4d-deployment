locals {
  classic_lb_timeout = 600
  cpd_workspace      = "${var.installer_workspace}/cpd"
  operator_namespace = "ibm-common-services"
  cpd_case_url       = "https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case"
  db2aaservice       = (var.datastage == "yes" || var.db2_aaservice == "yes" || var.watson_knowledge_catalog == "yes" || var.openpages.enable == "yes" ? "yes" : "no")
}

module "machineconfig" {
  source                       = "./machineconfig"
  cpd_api_key                  = var.cpd_api_key
  installer_workspace          = var.installer_workspace
  cluster_type                 = var.cluster_type
  openshift_api                = var.openshift_api
  openshift_username           = var.openshift_username
  openshift_password           = var.openshift_password
  openshift_token              = var.openshift_token
  login_string                 = var.login_string
  configure_global_pull_secret = var.configure_global_pull_secret
  configure_openshift_nodes    = var.configure_openshift_nodes
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
    module.machineconfig,
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
cp ${self.triggers.cpd_workspace}/cloudctl /usr/local/bin
EOF
  }
  depends_on = [
    null_resource.login_cluster,
    module.machineconfig,
  ]
}

resource "local_file" "cpd_catalog_source_yaml" {
  content  = data.template_file.cpd_operator_catalog.rendered
  filename = "${local.cpd_workspace}/cpd_operator_catalog_source.yaml"
}

resource "local_file" "opencloud_catalog_source_yaml" {
  content  = data.template_file.opencloud_catalog.rendered
  filename = "${local.cpd_workspace}/opencloud_catalog.yaml"
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

resource "local_file" "ccs_catalog_yaml" {
  content  = data.template_file.ccs_catalog.rendered
  filename = "${local.cpd_workspace}/ccs_catalog.yaml"
}

resource "local_file" "db2aaservice_catalog_yaml" {
  content  = data.template_file.db2aaservice_catalog.rendered
  filename = "${local.cpd_workspace}/db2aaservice_catalog.yaml"
}

resource "local_file" "dmc_catalog_yaml" {
  content  = data.template_file.dmc_catalog.rendered
  filename = "${local.cpd_workspace}/dmc_catalog.yaml"
}

resource "local_file" "iis_catalog_yaml" {
  content = data.template_file.iis_catalog.rendered
  filename = "${local.cpd_workspace}/iis_catalog.yaml"
}

resource "local_file" "wkc_catalog_yaml" {
  content = data.template_file.wkc_catalog.rendered
  filename = "${local.cpd_workspace}/wkc_catalog.yaml"
}

resource "local_file" "ws_catalog_yaml" {
  content  = data.template_file.ws_catalog.rendered
  filename = "${local.cpd_workspace}/ws_catalog.yaml"
}

resource "local_file" "ws_runtime_catalog_yaml" {
  content  = data.template_file.ws_runtime_catalog.rendered
  filename = "${local.cpd_workspace}/ws_runtime_catalog.yaml"
}

resource "local_file" "redis_catalog_yaml" {
  content  = data.template_file.redis_catalog.rendered
  filename = "${local.cpd_workspace}/redis_catalog.yaml"
}

resource "local_file" "data_refinery_catalog_yaml" {
  content  = data.template_file.data_refinery_catalog.rendered
  filename = "${local.cpd_workspace}/data_refinery_catalog.yaml"
}

resource "local_file" "wml_catalog_yaml" {
  content = data.template_file.wml_catalog.rendered
  filename = "${local.cpd_workspace}/wml_catalog.yaml"
}

resource "local_file" "mongodb_catalog_yaml" {
  content = data.template_file.mongodb_catalog.rendered
  filename = "${local.cpd_workspace}/mongodb_catalog.yaml"
}

resource "local_file" "watson_gateway_catalog_yaml" {
  content = data.template_file.watson_gateway_catalog.rendered
  filename = "${local.cpd_workspace}/watson_gateway_catalog.yaml"
}

resource "local_file" "rabbitmq_catalog_yaml" {
  content = data.template_file.rabbitmq_catalog.rendered
  filename = "${local.cpd_workspace}/rabbitmq_catalog.yaml"
}

resource "local_file" "model_train_catalog_yaml" {
  content = data.template_file.model_train_catalog.rendered
  filename = "${local.cpd_workspace}/model_train_catalog.yaml"
}

resource "local_file" "minio_catalog_yaml" {
  content = data.template_file.minio_catalog.rendered
  filename = "${local.cpd_workspace}/minio_catalog.yaml"
}

resource "local_file" "etcd_catalog_yaml" {
  content = data.template_file.etcd_catalog.rendered
  filename = "${local.cpd_workspace}/etcd_catalog.yaml"
}

resource "local_file" "cloud_native_postgres_catalog_yaml" {
  content = data.template_file.cloud_native_postgres_catalog.rendered
  filename = "${local.cpd_workspace}/cloud_native_postgres_catalog.yaml"
}

resource "local_file" "elasticsearch_catalog_yaml" {
  content = data.template_file.elasticsearch_catalog.rendered
  filename = "${local.cpd_workspace}/elasticsearch_catalog.yaml"
}

resource "local_file" "data_governor_catalog_yaml" {
  content = data.template_file.data_governor_catalog.rendered
  filename = "${local.cpd_workspace}/data_governor_catalog.yaml"
}

resource "local_file" "auditwebhook_catalog_yaml" {
  content = data.template_file.auditwebhook_catalog.rendered
  filename = "${local.cpd_workspace}/auditwebhook_catalog.yaml"
}

resource "null_resource" "node_check" {
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  #adding a negative check for managed-ibm as it doesn't support machine config 
  #so that this block runs for all other stack except ibmcloud
  count = var.cluster_type != "managed-ibm" ? 1 : 0
  provisioner "local-exec" {
    command = <<-EOF
echo "Ensure the nodes are running"
bash cpd/scripts/nodes_running.sh

EOF
  }
  depends_on = [
    module.machineconfig,
    null_resource.login_cluster,
    null_resource.download_cloudctl,
    local_file.ibmcpd_cr_yaml,
    local_file.operand_requests_yaml,
    local_file.cpd_operator_yaml,
    local_file.ccs_catalog_yaml,
    local_file.db2u_catalog_yaml,
    local_file.dmc_catalog_yaml,
    local_file.data_refinery_catalog_yaml,
    local_file.iis_catalog_yaml,
    local_file.wkc_catalog_yaml,
    local_file.ws_catalog_yaml,
    local_file.ws_runtime_catalog_yaml,
    local_file.db2aaservice_catalog_yaml,
    local_file.wml_catalog_yaml,
    local_file.redis_catalog_yaml,
    local_file.mongodb_catalog_yaml,
    local_file.watson_gateway_catalog_yaml,
    local_file.elasticsearch_catalog_yaml,
    local_file.data_governor_catalog_yaml,
    local_file.auditwebhook_catalog_yaml,
  ]
}

resource "null_resource" "cpd_foundational_services" {
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }

  provisioner "local-exec" {
    command = <<-EOF

echo "create db2u operator catalog"
oc apply -f ${self.triggers.cpd_workspace}/db2u_catalog.yaml
bash cpd/scripts/pod-status-check.sh ibm-db2uoperator-catalog openshift-marketplace

echo "create cpd catalog"
oc create -f ${self.triggers.cpd_workspace}/cpd_operator_catalog_source.yaml
bash cpd/scripts/pod-status-check.sh cpd-platform openshift-marketplace

echo "create opencloud catalog"
oc create -f  ${self.triggers.cpd_workspace}/opencloud_catalog.yaml
bash cpd/scripts/pod-status-check.sh opencloud-operators openshift-marketplace

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

echo "Create CPD Platform CR"
oc project ${self.triggers.namespace}
sleep 1
oc create -f ${self.triggers.cpd_workspace}/ibmcpd_cr.yaml

echo "Wait for Platform CR reconcile to start"
sleep 240

echo "Check the CPD Platform CR status"
bash cpd/scripts/check-cr-status.sh Ibmcpd ibmcpd-cr ${var.cpd_namespace} controlPlaneStatus; if [ $? -ne 0 ] ; then echo \"CPD control plane failed to install\" ; exit 1 ; fi

echo "Enable CSV injector"
oc patch namespacescope common-service --type='json' -p='[{"op":"replace", "path": "/spec/csvInjector/enable", "value":true}]' -n ${local.operator_namespace}

oc project openshift-marketplace

echo "Create CCS catalog"
sleep 1
oc create -f ${self.triggers.cpd_workspace}/ccs_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-ccs-operator-catalog openshift-marketplace

echo "Db2aaService"
oc create -f ${self.triggers.cpd_workspace}/db2aaservice_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-db2aaservice-cp4d-operator-catalog openshift-marketplace


echo 'Create DataRefinery catalog'
oc create -f ${self.triggers.cpd_workspace}/data_refinery_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-datarefinery-operator-catalog openshift-marketplace

echo "Create IIS catalog"
sleep 1
oc create -f ${self.triggers.cpd_workspace}/iis_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-iis-operator-catalog openshift-marketplace

echo "Create WKC catalog"
sleep 1
oc create -f ${self.triggers.cpd_workspace}/wkc_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-wkc-operator-catalog openshift-marketplace

echo "Create WS catalog"
sleep 1
oc create -f ${self.triggers.cpd_workspace}/ws_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-ws-operator-catalog openshift-marketplace

echo 'Create ws runtime catalog'
oc create -f ${self.triggers.cpd_workspace}/ws_runtime_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-ws-runtimes-operator-catalog openshift-marketplace

echo "Create DMC catalog"
sleep 1
oc create -f ${self.triggers.cpd_workspace}/dmc_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-dmc-operator-catalog openshift-marketplace

echo "Create Redis catalog"
sleep 1
oc create -f ${self.triggers.cpd_workspace}/redis_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cloud-databases-redis-operator-catalog openshift-marketplace

echo 'create WML catalog'
oc apply -f ${self.triggers.cpd_workspace}/wml_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-wml-operator-catalog openshift-marketplace

echo 'create Mongodb catalog'
oc apply -f ${self.triggers.cpd_workspace}/mongodb_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-cpd-mongodb-catalog openshift-marketplace

echo 'create watson_gateway catalog'
oc create -f ${self.triggers.cpd_workspace}/watson_gateway_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-watson-gateway-operator-catalog openshift-marketplace

echo 'create model-train catalog'
oc create -f ${self.triggers.cpd_workspace}/model_train_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-model-train-operator-catalog openshift-marketplace

echo 'create rabbitmq-catalog'
oc create -f ${self.triggers.cpd_workspace}/rabbitmq_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-rabbitmq-operator-catalog openshift-marketplace

echo 'create minio-catalog'
oc create -f ${self.triggers.cpd_workspace}/minio_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-minio-operator-catalog openshift-marketplace

echo 'create etcd-catalog'
oc create -f ${self.triggers.cpd_workspace}/etcd_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-etcd-operator-catalog openshift-marketplace

echo 'create cloud_native_postgres_catalog'
oc create -f ${self.triggers.cpd_workspace}/cloud_native_postgres_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh cloud-native-postgresql-catalog openshift-marketplace

echo 'create elasticsearch-catalog'
oc create -f ${self.triggers.cpd_workspace}/elasticsearch_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-elasticsearch-catalog openshift-marketplace

echo 'create ibm-data-governor-operator-catalog'
oc create -f ${self.triggers.cpd_workspace}/data_governor_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-data-governor-operator-catalog openshift-marketplace

echo 'create ibm-auditwebhook-operator-catalog'
oc create -f ${self.triggers.cpd_workspace}/auditwebhook_catalog.yaml
sleep 3
bash cpd/scripts/pod-status-check.sh ibm-auditwebhook-operator-catalog openshift-marketplace

EOF
  }
  depends_on = [
    module.machineconfig,
    null_resource.login_cluster,
    null_resource.download_cloudctl,
    local_file.ibmcpd_cr_yaml,
    local_file.operand_requests_yaml,
    local_file.cpd_operator_yaml,
    local_file.dmc_catalog_yaml,
    local_file.data_refinery_catalog_yaml,
    local_file.ws_catalog_yaml,
    local_file.redis_catalog_yaml,
    local_file.iis_catalog_yaml,
    local_file.wkc_catalog_yaml,
    local_file.wml_catalog_yaml,
    local_file.db2u_catalog_yaml,
    local_file.db2aaservice_catalog_yaml,
    local_file.mongodb_catalog_yaml,
    null_resource.node_check,
  ]
}

