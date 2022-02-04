locals {
  license            = var.accept_cpd_license == "accept" ? true : false
  storage_class      = lookup(var.cpd_storageclass, var.storage_option)
  rwo_storage_class  = lookup(var.rwo_cpd_storageclass, var.storage_option)

  wa_storage_class   = lookup(var.wa_storageclass, var.storage_option)

  wd_storage_class   = lookup(var.wd_storageclass, var.storage_option)
  storage_type_key   = var.storage_option == "ocs" || var.storage_option == "portworx" ? "storageVendor" : "storageClass"
  storage_type_value = var.storage_option == "ocs" || var.storage_option == "portworx" ? var.storage_option : lookup(var.cpd_storageclass, var.storage_option)
  wa_instance        = "wa"
  wa_kafka_sc        = lookup(var.wa_kafka_storage_class, var.storage_option)
  wa_sc_size         = lookup(var.wa_storage_size, var.storage_option)
  storage_type_value_wkc = var.storage_option == "efs" ? lookup(var.wkc_storageclass, var.storage_option): local.storage_type_value
}

data "template_file" "sysctl_worker" {
  template = <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: db2u-kubelet
spec:
  machineConfigPoolSelector:
    matchLabels:
      db2u-kubelet: sysctl
  kubeletConfig:
    allowedUnsafeSysctls:
      - "kernel.msg*"
      - "kernel.shm*"
      - "kernel.sem"
EOF
}

data "template_file" "wkc_iis_scc" {
  template = <<EOF
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegeEscalation: true
allowPrivilegedContainer: false
allowedCapabilities: null
apiVersion: security.openshift.io/v1
defaultAddCapabilities: null
fsGroup:
  type: RunAsAny
kind: SecurityContextConstraints
metadata:
  annotations:
    kubernetes.io/description: WKC/IIS provides all features of the restricted SCC
      but runs as user 10032.
  name: wkc-iis-scc
readOnlyRootFilesystem: false
requiredDropCapabilities:
- KILL
- MKNOD
- SETUID
- SETGID
runAsUser:
  type: MustRunAs
  uid: 10032
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
users:
- system:serviceaccount:${var.cpd_namespace}:wkc-iis-sa
EOF
}

data "template_file" "ibm_operator_catalog_source" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: "IBM Operator Catalog"
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/ibm-operator-catalog:latest
  imagePullPolicy: IfNotPresent
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

data "template_file" "db2u_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-db2uoperator-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ${var.db2u_catalog_source}
  imagePullPolicy: Always
  displayName: IBM Db2U Catalog
  publisher: IBM
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

data "template_file" "cpd_operator" {
  template = <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${local.operator_namespace}
---
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: operatorgroup
  namespace: ${local.operator_namespace}
spec:
  targetNamespaces:
  - ${local.operator_namespace}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cpd-operator
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.cpd_platform.channel}
  installPlanApproval: Automatic
  name: cpd-platform-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "operand_requests" {
  template = <<EOF
apiVersion: operator.ibm.com/v1alpha1
kind: OperandRequest
metadata:
  name: empty-request
  namespace: ${var.cpd_namespace}
spec:
  requests: []
EOF
}

data "template_file" "ibmcpd_cr" {
  template = <<EOF
apiVersion: cpd.ibm.com/v1
kind: Ibmcpd
metadata:
  name: ibmcpd-cr
  namespace: ${var.cpd_namespace}
spec:
  license:
    accept: true
    license: Enterprise
  storageClass: ${local.storage_class}
  zenCoreMetadbStorageClass: ${local.rwo_storage_class}
  version: ${var.cpd_platform.version}
EOF
}

#Db2aaservice
data "template_file" "db2aaservice_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-db2aaservice-cp4d-operator
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.db2_aaservice.channel}
  name: ibm-db2aaservice-cp4d-operator
  installPlanApproval: Automatic
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "db2aaservice_cr" {
  template = <<EOF
apiVersion: databases.cpd.ibm.com/v1
kind: Db2aaserviceService
metadata:
  name: db2aaservice-cr
  namespace: ${var.cpd_namespace}
spec:
  storageClass: ${local.storage_class}
  version: ${var.db2_aaservice.version}
  license:
    accept: true
    license: "Enterprise"
EOF
}

# SPARK (AnalyticsEngine)
data "template_file" "analyticsengine_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    app.kubernetes.io/instance: ibm-cpd-ae-operator-subscription
    app.kubernetes.io/managed-by: ibm-cpd-ae-operator
    app.kubernetes.io/name: ibm-cpd-ae-operator-subscription
  name: ibm-cpd-ae-operator-subscription
  namespace: ${local.operator_namespace}
spec:
    channel: ${var.analytics_engine.channel}
    installPlanApproval: Automatic
    name: analyticsengine-operator
    source: ibm-operator-catalog
    sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "analyticsengine_cr" {
  template = <<EOF
apiVersion: ae.cpd.ibm.com/v1
kind: AnalyticsEngine
metadata:
  name: analyticsengine-cr
  namespace: ${var.cpd_namespace}
spec:
  version: ${var.analytics_engine.version}
  ${local.storage_type_key}: "${local.storage_type_value}"
  license:
    accept: true
    license: Enterprise
EOF
}

#DB2WH
data "template_file" "db2wh_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-db2wh-cp4d-operator-catalog-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.db2_warehouse.channel}
  installPlanApproval: Automatic
  name: ibm-db2wh-cp4d-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "db2wh_cr" {
  template = <<EOF
apiVersion: databases.cpd.ibm.com/v1
kind: Db2whService
metadata:
  name: db2wh-cr
  namespace: ${var.cpd_namespace}
spec:
  storageClass: ${local.storage_class}
  license:
    accept: true
    license: "Enterprise"
EOF
}

#DB2OLTP
data "template_file" "db2oltp_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-db2oltp-cp4d-operator-catalog-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.db2_oltp.channel}
  installPlanApproval: Automatic
  name: ibm-db2oltp-cp4d-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "db2oltp_cr" {
  template = <<EOF
apiVersion: databases.cpd.ibm.com/v1
kind: Db2oltpService
metadata:
  name: db2oltp-cr
  namespace: ${var.cpd_namespace}
spec:
  storageClass: ${local.storage_class}
  license:
    accept: true
    license: Advanced
EOF
}

#WSL
data "template_file" "ws_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  annotations: {}
  name: ibm-cpd-ws-operator-catalog-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.watson_studio.channel}
  installPlanApproval: Automatic
  name: ibm-cpd-wsl
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "ws_cr" {
  template = <<EOF
apiVersion: ws.cpd.ibm.com/v1beta1
kind: WS
metadata:
  name: ws-cr
  namespace: ${var.cpd_namespace}
spec:
  version: ${var.watson_studio.version}
  size: "small"
  storageClass: ${local.storage_class}
  ${local.storage_type_key}: "${local.storage_type_value}"
  license:
    accept: true
    license: Enterprise
EOF
}

#WML
data "template_file" "wml_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  abels:
    app.kubernetes.io/instance: ibm-cpd-wml-operator-subscription
    app.kubernetes.io/managed-by: ibm-cpd-wml-operator
    app.kubernetes.io/name: ibm-cpd-wml-operator-subscription
  name: ibm-cpd-wml-operator-subscription
  namespace: ${local.operator_namespace}
spec:
    channel: ${var.watson_machine_learning.channel}
    installPlanApproval: Automatic
    name: ibm-cpd-wml-operator
    source: ibm-operator-catalog
    sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "wml_cr" {
  template = <<EOF
apiVersion: wml.cpd.ibm.com/v1beta1
kind: WmlBase
metadata:
  name: wml-cr
  namespace: ${var.cpd_namespace}
  labels:
    app.kubernetes.io/instance: wml-cr
    app.kubernetes.io/managed-by: ibm-cpd-wml-operator
    app.kubernetes.io/name: ibm-cpd-wml-operator
spec:
  scaleConfig: small
  is_35_upgrade: false
  ignoreForMaintenance: false
  docker_registry_prefix: "cp.icr.io/cp/cpd"
  storageClass: ${local.storage_class}
  ${local.storage_type_key}: "${local.storage_type_value}"
  version: ${var.watson_machine_learning.version}
  license:
    accept: true
    license: "Enterprise"
EOF
}

#WOS
data "template_file" "wos_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-watson-openscale-operator-subscription
  labels:
    app.kubernetes.io/instance: ibm-watson-openscale-operator-subscription
    app.kubernetes.io/managed-by: ibm-watson-openscale-operator
    app.kubernetes.io/name: ibm-watson-openscale-operator-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.watson_ai_openscale.channel}
  installPlanApproval: Automatic
  name: ibm-cpd-wos
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "wos_cr" {
  template = <<EOF
apiVersion: wos.cpd.ibm.com/v1
kind: WOService
metadata:
  name: aiopenscale-cr
  namespace: ${var.cpd_namespace}
spec:
  scaleConfig: small
  storageClass: "${local.storage_class}"
  version: ${var.watson_ai_openscale.version}
  type: service
  license:
    accept: true
    license: Enterprise
EOF
}

#Data Refinery
data "template_file" "data_refinery_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-cpd-datarefinery-operator
  namespace: ibm-common-services
spec
  channel: v1.0
  config:
    resources: {}
  installPlanApproval: Automatic
  name: ibm-cpd-datarefinery
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

#SPSS
data "template_file" "spss_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    app.kubernetes.io/instance: ibm-cpd-spss-operator-catalog-subscription
    app.kubernetes.io/managed-by: ibm-cpd-spss-operator
    app.kubernetes.io/name: ibm-cpd-spss-operator-catalog-subscription
  name: ibm-cpd-spss-operator-catalog-subscription
  namespace: ${local.operator_namespace}
spec:
    channel: ${var.spss_modeler.channel}
    installPlanApproval: Automatic
    name: ibm-cpd-spss
    source: ibm-operator-catalog
    sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "spss_cr" {
  template = <<EOF
apiVersion: spssmodeler.cpd.ibm.com/v1
kind: Spss
metadata:
  name: spss-cr
  namespace: ${var.cpd_namespace}
  labels:
    app.kubernetes.io/instance: ibm-cpd-spss-operator
    app.kubernetes.io/managed-by: ibm-cpd-spss-operator
    app.kubernetes.io/name: ibm-cpd-spss-operator
spec:
  version: ${var.spss_modeler.version}
  scaleConfig: "small"
  architecture: "amd64"
  docker_registry_prefix: "cp.icr.io/cp/cpd"
  storageClass: ${local.storage_class}
  namespace: "${var.cpd_namespace}"
  operation: "install"
  license:
    accept: true
    license: Enterprise
EOF
}

#WKC
data "template_file" "wkc_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    app.kubernetes.io/instance:  ibm-cpd-wkc-operator-catalog-subscription
    app.kubernetes.io/managed-by: ibm-cpd-wkc-operator
    app.kubernetes.io/name:  ibm-cpd-wkc-operator-catalog-subscription
  name: ibm-cpd-wkc-operator-catalog-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.watson_knowledge_catalog.channel}
  installPlanApproval: Automatic
  name: ibm-cpd-wkc
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "wkc_cr" {
  template = <<EOF
apiVersion: wkc.cpd.ibm.com/v1beta1
kind: WKC
metadata:
  name: wkc-cr
  namespace: ${var.cpd_namespace}
spec:
  version: ${var.watson_knowledge_catalog.version}
  ${local.storage_type_key}: "${local.storage_type_value_wkc}"
  license:
    accept: true
    license: Enterprise
  docker_registry_prefix: cp.icr.io/cp/cpd
  useODLM: true
  wkc_db2u_set_kernel_params: True
  iis_db2u_set_kernel_params: True
  # install_wkc_core_only: true     # To install the core version of the service, remove the comment tagging from the beginning of the line.
EOF
}

#Datastage
data "template_file" "ds_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-cpd-datastage-operator-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.datastage.channel}
  installPlanApproval: Automatic
  name: ibm-cpd-datastage-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "ds_cr" {
  template = <<EOF
apiVersion: ds.cpd.ibm.com/v1alpha1
kind: DataStage
metadata:
  name: datastage-cr
  namespace: ${var.cpd_namespace}
spec:
  license:
    accept: true
    license: Enterprise
  version: ${var.datastage.version}
  storageClass: "${local.storage_class}"
EOF
}

#CA

data "template_file" "ca_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-ca-operator-catalog-subscription
  labels:
    app.kubernetes.io/instance: ibm-ca-operator
    app.kubernetes.io/managed-by: ibm-ca-operator
    app.kubernetes.io/name: ibm-ca-operator
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.cognos_analytics.channel}
  name: ibm-ca-operator
  installPlanApproval: Automatic
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "ca_cr" {
  template = <<EOF
apiVersion: ca.cpd.ibm.com/v1
kind: CAService
metadata:
  name: ca-cr
  namespace: ${var.cpd_namespace}
spec:
  version: ${var.cognos_analytics.version}
  license:
    accept: true
    license: "Enterprise"
  storage_class: "${local.storage_class}"
  namespace: "${var.cpd_namespace}"
EOF
}

#DV

data "template_file" "dv_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-dv-operator-catalog-subscription
  namespace: ${local.operator_namespace}        # Pick the project that contains the Cloud Pak for Data operator
spec:
  channel: ${var.data_virtualization.channel}
  installPlanApproval: Automatic
  name: ibm-dv-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "dv_cr" {
  template = <<EOF
apiVersion: db2u.databases.ibm.com/v1
kind: DvService
metadata:
  name: dv-service-cr
  namespace: ${var.cpd_namespace}
spec:
  license:
    accept: true
    license: Enterprise
  version: ${var.data_virtualization.version}
  size: "small"
  docker_registry_prefix: cp.icr.io/cp/cpd
EOF
}

#BIGSQL
data "template_file" "bigsql_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-bigsql-operator-catalog-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.bigsql.channel}
  installPlanApproval: Automatic
  name: ibm-bigsql-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "bigsql_cr" {
  template = <<EOF
apiVersion: db2u.databases.ibm.com/v1
kind: BigsqlService
metadata:
  name: bigsql-service-cr     # This is the recommended name, but you can change it
  namespace: ${var.cpd_namespace}    # Replace with the project where you will install Db2 Big SQL
labels:
  app.kubernetes.io/component: operator
  app.kubernetes.io/instance: db2-bigsql
  app.kubernetes.io/managed-by: ibm-bigsql-operator
  app.kubernetes.io/name: db2-bigsql
spec:
  license:
    accept: true
    license: Enterprise    # Specify the license you purchased
  version: ${var.bigsql.version}
  storageClass: ${local.storage_class}     # See the guidance in "Information you need to complete this task"
EOF
}

#DMC
data "template_file" "dmc_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-databases-dmc-operator-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.data_management_console.channel}
  installPlanApproval: Automatic
  name: ibm-dmc-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "dmc_cr" {
  template = <<EOF
apiVersion: dmc.databases.ibm.com/v1
kind: Dmcaddon
metadata:
  name: data-management-console-addon
  namespace: ${var.cpd_namespace}
spec:
  namespace: "${var.cpd_namespace}"
  storageClass: ${local.storage_class}
  pullPrefix: cp.icr.io/cp/cpd
  version: ${var.data_management_console.version}
  license:
    accept: true
    license: Standard
EOF
}

#CDE
data "template_file" "cde_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    app.kubernetes.io/instance: ibm-cde-operator-subscription
    app.kubernetes.io/managed-by: ibm-cde-operator
    app.kubernetes.io/name: ibm-cde-operator-subscription
  name: ibm-cde-operator-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.cognos_dashboard_embedded.channel}
  installPlanApproval: Automatic
  name: ibm-cde-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "cde_cr" {
  template = <<EOF
apiVersion: cde.cpd.ibm.com/v1
kind: CdeProxyService
metadata:
  name: cdeproxyservice-cr
  namespace: ${var.cpd_namespace}
spec:
  version: ${var.cognos_dashboard_embedded.version}
  namespace: "${var.cpd_namespace}"
  storageClass: "${local.storage_class}"
  cert_manager_enabled: true
  license:
    accept: true
    license: Enterprise
EOF
}

#MDM
data "template_file" "mdm_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    app.kubernetes.io/instance: ibm-mdm-operator-subscription
    app.kubernetes.io/managed-by: ibm-mdm-operator
    app.kubernetes.io/name: ibm-mdm-operator-subscription
  name: ibm-mdm-operator-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.master_data_management.channel}
  installPlanApproval: Automatic
  name: ibm-mdm
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}


data "template_file" "mdm_ocs_cr" {
  template = <<EOF
apiVersion: mdm.cpd.ibm.com/v1
kind: MasterDataManagement
metadata:
  name: mdm-cr
  namespace: ${var.cpd_namespace}
spec:
  license:
    accept: true
    license: Enterprise
  persistence:
    storage_class: "ocs-storagecluster-ceph-rbd"     # See the guidance in "Information you need to complete this task"
    storage_vendor: "ocs"
  shared_persistence:     # Include this for OCS storage
    storage_class: "${local.storage_class}"     # Include this for OCS storage. See the guidance in "Information you need to complete this task"
  wkc:
    enabled: true     # Include this if you have installed Watson Knowledge Catalog
EOF
}

data "template_file" "mdm_cr" {
  template = <<EOF
apiVersion: mdm.cpd.ibm.com/v1
kind: MasterDataManagement
metadata:
  name: mdm-cr     # This is the recommended name, but you can change it
  namespace: ${var.cpd_namespace}   # Replace with the project where you will install IBM Match 360 with Watson
spec:
  license:
    accept: true
    license: Enterprise     # Specify the license you purchased
  persistence:
    storage_class: ${local.storage_class}   # See the guidance in "Information you need to complete this task"
  wkc:
    enabled: true     # Include this if you have installed Watson Knowledge Catalog
EOF
}

#DOD
data "template_file" "dods_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    app.kubernetes.io/instance: ibm-cpd-dods-operator-catalog-subscription
    app.kubernetes.io/managed-by: ibm-cpd-dods-operator
    app.kubernetes.io/name: ibm-cpd-dods-operator-catalog-subscription
  name: ibm-cpd-dods-operator-catalog-subscription
  namespace: ${local.operator_namespace}        # Pick the project that contains the Cloud Pak for Data operator
spec:
    channel: ${var.decision_optimization.channel}
    installPlanApproval: Automatic
    name: ibm-cpd-dods
    source: ibm-operator-catalog
    sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "dods_cr" {
  template = <<EOF
apiVersion: dods.cpd.ibm.com/v1beta1
kind: DODS
metadata:
  name: dods-cr
  namespace: ${var.cpd_namespace}
spec:
  license:
    accept: true
    license: Enterprise
  version: ${var.decision_optimization.version}
EOF
}

#PA
data "template_file" "pa_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-planning-analytics-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: ${var.planning_analytics.channel}
  installPlanApproval: Automatic
  name: ibm-planning-analytics-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "pa_cr" {
  template = <<EOF
apiVersion: pa.cpd.ibm.com/v1
kind: PAService
metadata:
  name: ibm-planning-analytics-service
  namespace: ${var.cpd_namespace}
  labels:
    app.kubernetes.io/instance: ibm-planning-analytics-service
    app.kubernetes.io/managed-by: ibm-planning-analytics-operator
    app.kubernetes.io/name: ibm-planning-analytics-service
  annotations:
    ansible.sdk.operatorframework.io/verbosity: '3'
spec:
  license:
    accept: true
  version: ${var.planning_analytics.version}
EOF
}

#WA
data "template_file" "wa_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-watson-assistant-operator-subscription
  namespace: ${local.operator_namespace}    # Pick the project that contains the Cloud Pak for Data operator
spec:
  channel: ${var.watson_assistant.channel}
  name: ibm-watson-assistant-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF
}

data "template_file" "wa_cr" {
  template = <<EOF
apiVersion: assistant.watson.ibm.com/v1
kind: WatsonAssistant
metadata:
  name: wa     # This is the recommended name, but you can change it
  namespace: ${var.cpd_namespace}     # Replace with the project where you will install
  annotations:
    oppy.ibm.com/disable-rollback: "true"
    oppy.ibm.com/log-default-level: "debug"
    oppy.ibm.com/log-filters: ""
    oppy.ibm.com/log-thread-id: "false"
    oppy.ibm.com/log-json: "false"
    oppy.ibm.com/temporary-patches: '{"wa-fix-wa-certs": {"timestamp": "2021-10-13T18:45:57.959534", "api_version": "assistant.watson.ibm.com/v1"}}'     # If your instance name is not "wa", then substitute the first occurrence of "wa" in "wa-fix-wa-certs" with the name of your instance. Do not change the timestamp
  labels:
    app.kubernetes.io/managed-by: "Ansible"
    app.kubernetes.io/name: "watson-assistant"
    app.kubernetes.io/instance: "wa"     # This should match the value for metadata.name
spec:
  backup:
    offlineQuiesce: false
    onlineQuiesce: false
  cluster:
    dockerRegistryPrefix: ""
    imagePullSecrets: []
    storageClassName: ${local.wa_storage_class}    # If you use a different storage class, replace it with the appropriate storage class
    type: private
    name: prod     # Do not change this value
  cpd:
    namespace: ${var.cpd_namespace}     # Replace with the project where Cloud Pak for Data is installed. This value will most likely match metadata.namespace
  datastores:
    cos:
      storageClassName: ""
      storageSize: 20Gi
    datagovernor:
      elasticSearch:
        storageSize: ${local.wa_sc_size}
      etcd:
        storageSize: ${local.wa_sc_size}
      kafka:
        storageSize: ${local.wa_sc_size}
      storageClassName: ${local.wa_kafka_sc}
      zookeeper:
        storageSize: ${local.wa_sc_size}
    elasticSearch:
      analytics:
        storageClassName: ""
        storageSize: ""
      store:
        storageClassName: ""
        storageSize: ""
    etcd:
      storageClassName: ""
      storageSize: 2Gi
    kafka:
      storageClassName: ""
      storageSize: 5Gi
      zookeeper:
        storageSize: 1Gi
    modelTrain:
      postgres:
        storageClassName: ${local.wa_storage_class}
        storageSize: ${local.wa_sc_size}
      rabbitmq:
        storageClassName: ${local.wa_storage_class}
        storageSize: ${local.wa_sc_size}
    postgres:
      backupStorageClassName: ""
      storageClassName: ""
      storageSize: 5Gi
    redis:
      storageClassName: ""
      storageSize: ""
  features:
    analytics:
      enabled: true
    recommends:
      enabled: true
    tooling:
      enabled: true
    voice:
      enabled: false
  labels: {}
  languages:
  - en
  license:
    accept: true     # Change to true if you accept the WA license terms
  size: medium     # Options are small, medium, and large
  version: ${var.watson_assistant.version}
EOF
}

data "template_file" "wa_temporary_patch" {
  template = <<EOF
apiVersion: assistant.watson.ibm.com/v1
kind: TemporaryPatch
metadata:
  name: ${local.wa_instance}-fix-clu-certs
spec:
  apiVersion: assistant.watson.ibm.com/v1
  kind: WatsonAssistantClu
  name: ${local.wa_instance}
  patchType: patchJson6902
  patch:
      certmanager:
        cert-nlu:
          - op: remove
            path: /spec/dnsNames/3
          - op: remove
            path: /spec/dnsNames/2
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
        cert-clu-embedding:
          - op: remove
            path: /spec/dnsNames/3
          - op: remove
            path: /spec/dnsNames/2
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
        cert-clu-serving:
          - op: remove
            path: /spec/dnsNames/3
          - op: remove
            path: /spec/dnsNames/2
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
        cert-clu-training:
          - op: remove
            path: /spec/dnsNames/3
          - op: remove
            path: /spec/dnsNames/2
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
        cert-dragonfly-clu-mm:
          - op: remove
            path: /spec/dnsNames/3
          - op: remove
            path: /spec/dnsNames/2
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
        cert-ed:
          - op: remove
            path: /spec/dnsNames/4
          - op: remove
            path: /spec/dnsNames/3
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
        cert-master:
          - op: remove
            path: /spec/dnsNames/3
          - op: remove
            path: /spec/dnsNames/2
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
        cert-recommends:
          - op: remove
            path: /spec/dnsNames/2
          - op: remove
            path: /spec/dnsNames/1
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
        cert-spellchecker-mm:
          - op: remove
            path: /spec/dnsNames/15
          - op: remove
            path: /spec/dnsNames/14
          - op: remove
            path: /spec/dnsNames/3
          - op: remove
            path: /spec/dnsNames/2
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
        cert-system-entities:
          - op: remove
            path: /spec/dnsNames/3
          - op: remove
            path: /spec/dnsNames/2
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
        cert-tfmm:
          - op: remove
            path: /spec/dnsNames/3
          - op: remove
            path: /spec/dnsNames/2
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
---
apiVersion: assistant.watson.ibm.com/v1
kind: TemporaryPatch
metadata:
  name: ${local.wa_instance}-fix-analytics-certs
spec:
  apiVersion: assistant.watson.ibm.com/v1
  kind: WatsonAssistantAnalytics
  name: ${local.wa_instance}
  patchType: patchJson6902
  patch:
      certmanager:
        cert-analytics:
          - op: remove
            path: /spec/dnsNames/3
          - op: remove
            path: /spec/dnsNames/2
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
---
apiVersion: assistant.watson.ibm.com/v1
kind: TemporaryPatch
metadata:
  name: ${local.wa_instance}-fix-integrations-certs
spec:
  apiVersion: assistant.watson.ibm.com/v1
  kind: WatsonAssistantIntegrations
  name: ${local.wa_instance}
  patchType: patchJson6902
  patch:
      certmanager:
        cert-integrations:
          - op: remove
            path: /spec/dnsNames/2
          - op: remove
            path: /spec/dnsNames/1
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
---
apiVersion: assistant.watson.ibm.com/v1
kind: TemporaryPatch
metadata:
  name: ${local.wa_instance}-fix-recommends-certs
spec:
  apiVersion: assistant.watson.ibm.com/v1
  kind: WatsonAssistantRecommends
  name: ${local.wa_instance}
  patchType: patchJson6902
  patch:
      certmanager:
        cert-recommends:
          - op: remove
            path: /spec/dnsNames/2
          - op: remove
            path: /spec/dnsNames/1
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
---
apiVersion: assistant.watson.ibm.com/v1
kind: TemporaryPatch
metadata:
  name: ${local.wa_instance}-fix-ui-certs
spec:
  apiVersion: assistant.watson.ibm.com/v1
  kind: WatsonAssistantUi
  name: ${local.wa_instance}
  patchType: patchJson6902
  patch:
      certmanager:
        cert-ui:
          - op: remove
            path: /spec/dnsNames/2
          - op: remove
            path: /spec/dnsNames/1
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1", "::1"]
---
apiVersion: assistant.watson.ibm.com/v1
kind: TemporaryPatch
metadata:
  name: ${local.wa_instance}-fix-wa-certs
spec:
  apiVersion: assistant.watson.ibm.com/v1
  kind: WatsonAssistant
  name: ${local.wa_instance}
  patchType: patchJson6902
  patch:
      certmanager:
        cert-elasticSearch-store:
          - op: remove
            path: /spec/dnsNames/1
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1"]
          - op: add
            path: /spec/commonName
            value: localhost
        cert-cos:
          - op: remove
            path: /spec/dnsNames/1
          - op: add
            path: /spec/ipAddresses
            value: ["127.0.0.1"]
EOF
}

data "template_file" "wd_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    app.kubernetes.io/instance: ibm-watson-discovery-operator-subscription
    app.kubernetes.io/managed-by: ibm-watson-discovery-operator
    app.kubernetes.io/name: ibm-watson-discovery-operator-subscription
  name: ibm-watson-discovery-operator-subscription
  namespace: ${local.operator_namespace}   # Pick the project that contains the Cloud Pak for Data operator
spec:
  channel: ${var.watson_discovery.channel}
  name: ibm-watson-discovery-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF
}

data "template_file" "wd_cr" {
  template = <<EOF
apiVersion: discovery.watson.ibm.com/v1
kind: WatsonDiscovery
metadata:
  annotations:
    oppy.ibm.com/disable-rollback: 'true'
  name: wd     # This is the recommended name, but you can change it
  namespace: ${var.cpd_namespace}     # Replace with the project where you will install Watson Discovery
spec:
  license:
    accept: true
  version: ${var.watson_discovery.version}
  shared:
    storageClassName: ${local.wd_storage_class}     # See the guidance in "Information you need to complete this task"
  watsonGateway:
    version: main
EOF
}

data "template_file" "op_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-cpd-openpages-operator
  namespace: ${local.operator_namespace}    # Pick the project that contains the Cloud Pak for Data operator
spec:
  channel: ${var.openpages.channel}
  installPlanApproval: Automatic
  name: ibm-cpd-openpages-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "op_cr" {
  template = <<EOF
apiVersion: openpages.cpd.ibm.com/v1
kind: OpenPagesService
metadata:
  name: openpages
  namespace: ${var.cpd_namespace}
  labels:
    app.kubernetes.io/name: openpages
    app.kubernetes.io/instance: openpages-service
    app.kubernetes.io/version: "${var.openpages.version}"
    app.kubernetes.io/managed-by: ibm-cpd-openpages-operator
spec:
  version: "${var.openpages.version}"
  license:
    accept: true
    license: Enterprise     # Specify the license that you purchased
EOF
}
