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

resource "local_file" "cpd_service_yaml" {
  content  = data.template_file.cpd_service.rendered
  filename = "${local.cpd_workspace}/cpd_service.yaml"
}

resource "null_resource" "configure_cluster" {
  triggers = {
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    vpc_id              = var.vpc_id
    installer_workspace = var.installer_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true,"replicas":3}}' -n openshift-image-registry
oc patch svc/image-registry -p '{"spec":{"sessionAffinity": "ClientIP"}}' -n openshift-image-registry
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"managementState":"Unmanaged"}}'
echo 'Sleeping for 3m'
sleep 3m
oc annotate route default-route haproxy.router.openshift.io/timeout=600s -n openshift-image-registry
oc set env deployment/image-registry -n openshift-image-registry REGISTRY_STORAGE_S3_CHUNKSIZE=104857600
echo 'Sleeping for 2m'
sleep 2m
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

resource "null_resource" "install_operator" {
  triggers = {
    cpd_workspace         = local.cpd_workspace
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    api_key               = var.api_key
    datacore_version      = var.datacore_version
    cloudctl_version      = var.cloudctl_version
    cpd_external_registry = var.cpd_external_registry
    cpd_external_username = var.cpd_external_username
  }
  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${self.triggers.cpd_workspace}
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
case $(uname -s) in
  Darwin)
    wget https://github.com/IBM/cloud-pak-cli/releases/download/${self.triggers.cloudctl_version}/cloudctl-darwin-amd64.tar.gz -O ${self.triggers.cpd_workspace}/cloudctl-darwin-amd64.tar.gz
    wget https://github.com/IBM/cloud-pak-cli/releases/download/${self.triggers.cloudctl_version}/cloudctl-darwin-amd64.tar.gz.sig -O ${self.triggers.cpd_workspace}/cloudctl-darwin-amd64.tar.gz.sig
    curl https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cp-datacore-${self.triggers.datacore_version}.tgz -o ${self.triggers.cpd_workspace}/ibm-cp-datacore-${self.triggers.datacore_version}.tgz
    tar -xvf ${self.triggers.cpd_workspace}/cloudctl-darwin-amd64.tar.gz -C ${self.triggers.cpd_workspace}
    ;;
  Linux)
    wget https://github.com/IBM/cloud-pak-cli/releases/download/${self.triggers.cloudctl_version}/cloudctl-linux-amd64.tar.gz -O ${self.triggers.cpd_workspace}/cloudctl-linux-amd64.tar.gz
    wget https://github.com/IBM/cloud-pak-cli/releases/download/${self.triggers.cloudctl_version}/cloudctl-linux-amd64.tar.gz.sig -O ${self.triggers.cpd_workspace}/cloudctl-linux-amd64.tar.gz.sig
    curl https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cp-datacore-${self.triggers.datacore_version}.tgz -o ${self.triggers.cpd_workspace}/ibm-cp-datacore-${self.triggers.datacore_version}.tgz
    tar -xvf ${self.triggers.cpd_workspace}/cloudctl-linux-amd64.tar.gz -C ${self.triggers.cpd_workspace}
    ;;
  *)
    echo 'Supports only Linux and Mac OS at this time'
    exit 1;;
esac
tar -xvf ${self.triggers.cpd_workspace}/ibm-cp-datacore-${self.triggers.datacore_version}.tgz -C ${self.triggers.cpd_workspace}
oc new-project cpd-meta-ops
cp cpd/scripts/install-cpd-operator.sh ${self.triggers.cpd_workspace}
chmod +x ${self.triggers.cpd_workspace}/install-cpd-operator.sh
cd ${self.triggers.cpd_workspace} && bash install-cpd-operator.sh '${self.triggers.api_key}' cpd-meta-ops '${self.triggers.cpd_external_registry}' '${self.triggers.cpd_external_username}'
echo "Sleeping for 5min"
sleep 300
OP_STATUS=$(oc get pods -n cpd-meta-ops -l name=ibm-cp-data-operator --no-headers | awk '{print $3}')
if [ $OP_STATUS != 'Running' ] ; then echo "CPD Operator Installation Failed" ; exit 1 ; fi
oc new-project ${self.triggers.cpd_namespace}
EOF
  }
  /* provisioner "local-exec" {
    when    = destroy
    command = <<EOF
echo "Uninstall Operator"

echo "Delete Both Namespaces (meta-ops and cpd)"

echo "#rm -rf ${self.triggers.cpd_workspace}"
EOF
  }
  depends_on = [
    null_resource.configure_cluster,
  ] */
}

resource "null_resource" "install_lite" {
  count = var.accept_cpd_license == "accept" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#lite#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod +x cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh lite ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "Lite Installation Failed" ; exit 1 ; fi
sed -i -e s#lite#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice lite-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_dv" {
  count = var.accept_cpd_license == "accept" && var.data_virtualization == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#dv#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh dv ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "dv Installation Failed" ; exit 1 ; fi
sed -i -e s#dv#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice dv-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_spark" {
  count = var.accept_cpd_license == "accept" && var.apache_spark == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#spark#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh spark ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "spark Installation Failed" ; exit 1 ; fi
sed -i -e s#spark#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice spark-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_wkc" {
  count = var.accept_cpd_license == "accept" && var.watson_knowledge_catalog == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#wkc#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh wkc ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "wkc Installation Failed" ; exit 1 ; fi
sed -i -e s#wkc#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice wkc-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_wsl" {
  count = var.accept_cpd_license == "accept" && var.watson_studio_library == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#wsl#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh wsl ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "wsl Installation Failed" ; exit 1 ; fi
sed -i -e s#wsl#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice wsl-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_wml" {
  count = var.accept_cpd_license == "accept" && var.watson_machine_learning == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#wml#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh wml ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "wml Installation Failed" ; exit 1 ; fi
sed -i -e s#wml#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice wml-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_aiopenscale" {
  count = var.accept_cpd_license == "accept" && var.watson_ai_openscale  == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#aiopenscale#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh aiopenscale ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "aiopenscale Installation Failed" ; exit 1 ; fi
sed -i -e s#aiopenscale#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice aiopenscale-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_cde" {
  count = var.accept_cpd_license == "accept" && var.cognos_dashboard_embedded  == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#cde#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh cde ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "cde Installation Failed" ; exit 1 ; fi
sed -i -e s#cde#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice cde-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_streams" {
  count = var.accept_cpd_license == "accept" && var.streams  == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#streams#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh streams ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "streams Installation Failed" ; exit 1 ; fi
sed -i -e s#streams#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice streams-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_streams_flows" {
  count = var.accept_cpd_license == "accept" && var.streams_flows  == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#streams-flows#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh streams-flows ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "streams-flows Installation Failed" ; exit 1 ; fi
sed -i -e s#streams-flows#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice streams-flows-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_ds" {
  count = var.accept_cpd_license == "accept" && var.datastage  == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#ds#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh ds ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "ds Installation Failed" ; exit 1 ; fi
sed -i -e s#ds#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams_flows,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice ds-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_db2wh" {
  count = var.accept_cpd_license == "accept" && var.db2_warehouse  == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#db2wh#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh db2wh ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "db2wh Installation Failed" ; exit 1 ; fi
sed -i -e s#db2wh#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice db2wh-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_db2oltp" {
  count = var.accept_cpd_license == "accept" && var.db2_advanced_edition  == "yes" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#db2oltp#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh db2oltp ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "db2oltp Installation Failed" ; exit 1 ; fi
sed -i -e s#db2oltp#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_db2wh,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice db2oltp-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_dmc" {
  count = var.data_management_console == "yes" && var.accept_cpd_license == "accept" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#dmc#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh dmc ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "dmc Installation Failed" ; exit 1 ; fi
sed -i -e s#dmc#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice dmc-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_datagate" {
  count = var.datagate == "yes" && var.accept_cpd_license == "accept" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#datagate#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh datagate ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "datagate Installation Failed" ; exit 1 ; fi
sed -i -e s#datagate#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_dmc,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice datagate-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_dods" {
  count = var.decision_optimization == "yes" && var.accept_cpd_license == "accept" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#dods#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh dods ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "dods Installation Failed" ; exit 1 ; fi
sed -i -e s#dods#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_dmc,
    null_resource.install_datagate,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice dods-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_ca" {
  count = var.cognos_analytics == "yes" && var.accept_cpd_license == "accept" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#ca#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh ca ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "ca Installation Failed" ; exit 1 ; fi
sed -i -e s#ca#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_dmc,
    null_resource.install_datagate,
    null_resource.install_dods,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice ca-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_spss" {
  count = var.spss_modeler == "yes" && var.accept_cpd_license == "accept" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#spss#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh spss ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "spss Installation Failed" ; exit 1 ; fi
sed -i -e s#spss#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_dmc,
    null_resource.install_datagate,
    null_resource.install_ca,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice spss-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_bigsql" {
  count = var.db2_bigsql == "yes" && var.accept_cpd_license == "accept" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#big-sql#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh big-sql ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "big-sql Installation Failed" ; exit 1 ; fi
sed -i -e s#big-sql#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_dmc,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_spss,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice big-sql-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}

resource "null_resource" "install_pa" {
  count = var.planning_analytics == "yes" && var.accept_cpd_license == "accept" ? 1 : 0
  triggers = {
    openshift_api         = var.openshift_api
    openshift_username    = var.openshift_username
    openshift_password    = var.openshift_password
    openshift_token       = var.openshift_token
    cpd_namespace         = var.cpd_namespace
    cpd_workspace = local.cpd_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
sed -i -e s#SERVICE#pa#g ${self.triggers.cpd_workspace}/cpd_service.yaml
oc create -f ${self.triggers.cpd_workspace}/cpd_service.yaml -n ${self.triggers.cpd_namespace}
chmod + cpd/scripts/wait-for-service-install.sh
bash cpd/scripts/wait-for-service-install.sh pa ${self.triggers.cpd_namespace} ; if [ $? -ne 0 ] ; then echo "pa Installation Failed" ; exit 1 ; fi
sed -i -e s#pa#SERVICE#g ${self.triggers.cpd_workspace}/cpd_service.yaml
EOF
  }
  depends_on = [
    local_file.cpd_service_yaml,
    null_resource.configure_cluster,
    null_resource.install_operator,
    null_resource.install_lite,
    null_resource.install_dv,
    null_resource.install_spark,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_dmc,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_spss,
    null_resource.install_bigsql,
  ]
  /* provisioner "local-exec" {
    when = destroy
    command = <<EOF
echo "Logging in..."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
oc delete cpdservice pa-cpdservice -n ${self.triggers.cpd_namespace}
EOF
  } */
}