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
    wget https://github.com/IBM/cpd-cli/releases/download/v11.3.0/cpd-cli-darwin-EE-11.3.0.tgz -P ${self.triggers.cpd_workspace} -A 'cpd-cli-darwin-EE-11.3.0.tgz'
    tar -xvf ${self.triggers.cpd_workspace}/cpd-cli-darwin-EE-11.3.0.tgz -C ${self.triggers.cpd_workspace}
    rm -rf ${self.triggers.cpd_workspace}/plugins
    rm -rf ${self.triggers.cpd_workspace}/LICENSES
    mv ${self.triggers.cpd_workspace}/cpd-cli-darwin-EE-11.3.0-52/*  ${self.triggers.cpd_workspace}
    ;;
  Linux)
    wget https://github.com/IBM/cpd-cli/releases/download/v11.3.0/cpd-cli-linux-EE-11.3.0.tgz -P ${self.triggers.cpd_workspace} -A 'cpd-cli-linux-EE-11.3.0.tgz'
    tar -xvf ${self.triggers.cpd_workspace}/cpd-cli-linux-EE-11.3.0.tgz -C ${self.triggers.cpd_workspace}
    rm -rf ${self.triggers.cpd_workspace}/plugins
    rm -rf ${self.triggers.cpd_workspace}/LICENSES
    mv ${self.triggers.cpd_workspace}/cpd-cli-linux-EE-11.3.0-52/* ${self.triggers.cpd_workspace}
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
    build_number        = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = <<EOF

echo 'Remove any existing olm-utils-play container' 
podman rm --force olm-utils-play

echo 'Run login-to-ocp command'

${self.triggers.cpd_workspace}/cpd-cli manage login-to-ocp --server ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' || ${self.triggers.cpd_workspace}/cpd-cli manage login-to-ocp --server ${self.triggers.openshift_api} --token='${self.triggers.openshift_token}'

${self.triggers.login_string} || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
 
sleep 60

EOF
  }
  depends_on = [
    module.machineconfig,
    null_resource.download_cpd_cli,
  ]
}

resource "null_resource" "configure_global_pull_secret" {
  triggers = {
    cpd_workspace = local.cpd_workspace
    cpd_external_registry = var.cpd_external_registry
    cpd_external_username = var.cpd_external_username
    cpd_api_key = var.cpd_api_key

  }

  count = var.configure_global_pull_secret ? 1 : 0
  provisioner "local-exec" {
    command = <<EOF
echo "Configuring global pull secret"

${self.triggers.cpd_workspace}/cpd-cli manage add-cred-to-global-pull-secret  '${self.triggers.cpd_external_registry}'  '${self.triggers.cpd_external_username}'  '${self.triggers.cpd_api_key}'

echo 'Sleeping for 5mins while global pull secret apply and the nodes restarts' 
sleep 300
EOF
  }
   depends_on = [
    module.machineconfig,
    null_resource.login_cluster,
    null_resource.download_cpd_cli,
  ]
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
    null_resource.configure_global_pull_secret,
  ]
}

resource "null_resource" "cpd_foundational_services" {
  triggers = {
    namespace     = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }

  provisioner "local-exec" {
    command = <<-EOF
echo "Deploy all catalogsources and operator subscriptions for cpfs,cpd_platform"  &&
bash cpd/scripts/apply-olm.sh ${self.triggers.cpd_workspace} ${var.cpd_version} cpfs,cpd_platform  &&
echo "Applying CR for cpfs,cpd_platform" &&
bash cpd/scripts/apply-cr.sh ${self.triggers.cpd_workspace} ${var.cpd_version} cpfs,cpd_platform ${var.cpd_namespace} ${var.storage_option}  ${local.storage_class} ${local.rwo_storage_class}  &&
echo "Enable CSV injector" &&
oc patch namespacescope common-service --type='json' -p='[{"op":"replace", "path": "/spec/csvInjector/enable", "value":true}]' -n ${local.operator_namespace}
EOF
  }
  depends_on = [
    module.machineconfig,
    null_resource.login_cluster,
    null_resource.download_cpd_cli,
    null_resource.node_check,
    null_resource.configure_global_pull_secret,
  ]
}

