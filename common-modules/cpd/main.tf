locals {
  classic_lb_timeout = 600
  cpd_workspace      = "${var.installer_workspace}/cpd"
  operator_namespace = "ibm-common-services"
  cpd_case_url       = "https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case"
  storage_class      = lookup(var.cpd_storageclass, var.storage_option)
  rwo_storage_class  = lookup(var.rwo_cpd_storageclass, var.storage_option)
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

resource "null_resource" "download_cpd_cli" {
  triggers = {
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<-EOF
  echo "Download cpd-cli installer."
case $(uname -s) in
  Darwin)
    wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/${var.cpd_version}/dev/cpd-cli/18/cpd-cli-darwin-EE-11.0.0-18.tgz -P ${self.triggers.cpd_workspace} -A 'cpd-cli-darwin-EE-11.0.0-18.tgz'
    tar -xvf ${self.triggers.cpd_workspace}/cpd-cli-darwin-EE-11.0.0-18.tgz -C ${self.triggers.cpd_workspace}
    rm -rf ${self.triggers.cpd_workspace}/plugins
    rm -rf ${self.triggers.cpd_workspace}/LICENSES
    mv ${self.triggers.cpd_workspace}/cpd-cli-darwin-EE-11.0.0-18/*  ${self.triggers.cpd_workspace}
    ;;
  Linux)
    wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/${var.cpd_version}/dev/cpd-cli/18/cpd-cli-linux-EE-11.0.0-18.tgz -P ${self.triggers.cpd_workspace} -A 'cpd-cli-linux-EE-11.0.0-18.tgz'
    tar -xvf ${self.triggers.cpd_workspace}/cpd-cli-linux-EE-11.0.0-18.tgz -C ${self.triggers.cpd_workspace}
    rm -rf ${self.triggers.cpd_workspace}/plugins
    rm -rf ${self.triggers.cpd_workspace}/LICENSES
    mv ${self.triggers.cpd_workspace}/cpd-cli-linux-EE-11.0.0-18/* ${self.triggers.cpd_workspace}
    ;;
  *)
    echo 'Supports only Linux and Mac OS at this time'
    exit 1;;
esac
EOF
  }
  depends_on = [
    module.machineconfig,
  ]
}

resource "null_resource" "login_cluster" {
  triggers = {
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    login_string        = var.login_string
    cpd_workspace       = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF

echo 'set OLM_UTILS_IMAGE env variable to staging repo required only in dev'
export OLM_UTILS_IMAGE=cp.stg.icr.io/cp/cpd/olm-utils:latest-validated

echo 'Remove any existing olm-utils-play container' 
podman rm --force olm-utils-play

echo 'podman login to stg.icr.io repo required only in dev'
podman login -u '${var.cpd_staging_username}' -p '${var.cpd_staging_api_key}' '${var.cpd_staging_registry}'

echo 'Run login-to-ocp command'

${self.triggers.cpd_workspace}/cpd-cli manage login-to-ocp --server ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' || ${self.triggers.cpd_workspace}/cpd-cli manage login-to-ocp --server ${self.triggers.openshift_api} --token='${self.triggers.openshift_token}'

${self.triggers.login_string} || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
 
sleep 60

${self.triggers.cpd_workspace}/cpd-cli manage login-to-ocp --server ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}'  || ${self.triggers.cpd_workspace}/cpd-cli manage login-to-ocp --server ${self.triggers.openshift_api} --token='${self.triggers.openshift_token}'

EOF
  }
  depends_on = [
    module.machineconfig,
    null_resource.download_cpd_cli,
  ]
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
    null_resource.download_cpd_cli,
  ]
}

resource "null_resource" "cpd_foundational_services" {
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }

  provisioner "local-exec" {
    command = <<-EOF
    
echo "Deploy all catalogsources and operator subscriptions for cpfs,cpd_platform"
bash cpd/scripts/apply-olm.sh ${self.triggers.cpd_workspace} ${var.cpd_version} cpfs,cpd_platform

echo "Applying CR for cpfs,cpd_platform"
bash cpd/scripts/apply-cr.sh ${self.triggers.cpd_workspace} ${var.cpd_version} cpfs,cpd_platform ${var.cpd_namespace}  ${local.storage_class} ${local.rwo_storage_class}

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
    null_resource.download_cpd_cli,
    null_resource.node_check,
    null_resource.configure_dev_cluster,
  ]
}

