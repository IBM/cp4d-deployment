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

data "template_file" "iis_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-iis-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-iis-operator-catalog@sha256:90d087b5721e979f030f47c8fa379f73a953d64256f14fd7006ab2b2b283a0c8
  displayName: CPD IBM Information Server
  publisher: IBM
  sourceType: grpc
EOF
}

data "template_file" "cpd_operator_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: cpd-platform
spec:
  image: icr.io/cpopen/ibm-cpd-platform-operator-catalog@sha256:5550dbf568c0efa04e60efda893acf55be6ad06ebe1b128dce41f0eca5a59832
  displayName: Cloud Pak for Data
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

data "template_file" "opencloud_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: opencloud-operators
spec:
  image: icr.io/cpopen/ibm-common-service-catalog@sha256:9ab2741ebcad19a6416a952bf1103900bd9fc1c5525be782744a2c9115982e5b
  displayName: IBMCS Operators
  publisher: IBM
  sourceType: grpc
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
  source: cpd-platform
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

data "template_file" "ccs_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-ccs-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-ccs-operator-catalog@sha256:4a81b9133c9d797ef1d40673d57cf3b1d5463dea710a3d0587628650a7eef817
  displayName: CPD Common Core Services
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

data "template_file" "ccs_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-cpd-ccs-operator
  namespace: ibm-common-services
spec:
  channel: v1.0
  installPlanApproval: Automatic
  name: ibm-cpd-ccs
  source: ibm-cpd-ccs-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}



#Db2aaservice
data "template_file" "db2aaservice_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-db2aaservice-cp4d-operator-catalog
spec:
  image: icr.io/cpopen/ibm-db2aaservice-cp4d-operator-catalog@sha256:a27cad8bd77eff44ef07952e0cd413505bafacc1567513f6e1f314cf7b5bb4ef
  displayName: IBM Db2aaservice CP4D Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

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
  source: ibm-db2aaservice-cp4d-operator-catalog
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
data "template_file" "analyticsengine_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-ae-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-analyticsengine-operator-catalog@sha256:00fb0cd9bf834ee1af99675602be5feae2c1c9d27c97aa2732e665f7d5333c01
  displayName: Cloud Pak for Data IBM Analytics Engine powered by Apache Spark
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

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
    source: ibm-cpd-ae-operator-catalog
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

data "template_file" "db2wh_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-db2wh-cp4d-operator-catalog
spec:
  image: icr.io/cpopen/ibm-db2wh-cp4d-operator-catalog@sha256:e88dbec35584ac8bf6ca97d1016f1a640f665ce4bd9d6b7d5f9f18761c78ebf5
  displayName: IBM Db2wh CP4D Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}
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
  source: ibm-db2wh-cp4d-operator-catalog
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

data "template_file" "db2oltp_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-db2oltp-cp4d-operator-catalog
spec:
  image: icr.io/cpopen/ibm-db2oltp-cp4d-operator-catalog@sha256:df4af62d05c5e346741a88684300aec70468a481a799cfc42564d4090fa86030
  displayName: IBM Db2oltp CP4D Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

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
  source: ibm-db2oltp-cp4d-operator-catalog
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

# Catalog source
data "template_file" "ws_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-ws-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-ws-operator-catalog@sha256:6b4c184c9de257441cb15e4e05141ec7bfb6e45177625b31387a860b3c4c875f
  displayName: CPD IBM Watson Studio
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

data "template_file" "ws_runtime_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-ws-runtimes-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-ws-runtimes-operator-catalog@sha256:14352ea4f71c1917cdeb860b64645fd56a3812ff69255b26dfb0c7199005e1a0
  displayName: CPD Watson Studio Runtimes
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}  

# Subscription
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
  source: ibm-cpd-ws-operator-catalog
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
data "template_file" "wml_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-wml-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-wml-operator-catalog@sha256:59e9a917d3007c5932d3991409a93bc1f7a7fd6e3412eb4e5be17abe2456a02c
  displayName: Cloud Pak for Data Watson Machine Learning
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

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
    source: ibm-cpd-wml-operator-catalog
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
data "template_file" "wos_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-openscale-operator-catalog
  namespace: openshift-marketplace
  generation: 1
spec:
  displayName: IBM Watson OpenScale
  image: icr.io/cpopen/ibm-watson-openscale-operator-catalog@sha256:d8b96670d577bfb00ea072b3855aae997972865f23a6d0c9dc29deff8972f47b
  publisher: IBM
  sourceType: grpc
EOF
}
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
  source: ibm-openscale-operator-catalog
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
data "template_file" "data_refinery_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-datarefinery-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-datarefinery-operator-catalog@sha256:47d5e286326f81056f9a473e885922bfd2943b49e74c1f44d8531fd02e5da82f
  displayName: Cloud Pak for Data IBM DataRefinery
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

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
  source: ibm-cpd-datarefinery-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

#SPSS
data "template_file" "spss_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-spss-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-spss-operator-catalog@sha256:1750f9fdb0e65ec0f7b808730575bfc3bb8295b2e17f2b38c13b18a7fe543d3c
  displayName: CPD Spss Modeler Services
  publisher: IBM
  sourceType: grpc
EOF

}
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
    source: ibm-cpd-spss-operator-catalog
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
data "template_file" "wkc_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-wkc-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-wkc-operator-catalog@sha256:4c7278c0591b123a08ada59aacdd96c83b04ff77ce80ce0c1f0be710954dc1be
  displayName: CPD WKC
  publisher: IBM
  sourceType: grpc
EOF
}

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
  source: ibm-cpd-wkc-operator-catalog
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
data "template_file" "ds_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-datastage-operator-catalog
spec:
  image: icr.io/cpopen/ds-ent-operator-catalog@sha256:7f3be6cb51c3bbd1caa044845e415ae1663b02e805f82a96c965d452b0edefaa
  displayName: IBM CPD DataStage
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 60m
EOF
}

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
  source: ibm-cpd-datastage-operator-catalog
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

data "template_file" "ca_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-ca-operator-catalog
spec:
  image: icr.io/cpopen/ibm-ca-operator-catalog@sha256:b6c6d86c748169823247a3290dcd65d26dd1683c0a36feee5b01b87b4d9ae98b
  displayName: ibm-ca-operator-catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}
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
  source: ibm-ca-operator-catalog
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
data "template_file" "dv_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-dv-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-dv-operator-catalog@sha256:45753b4b15bd3902c497a12d4b2b8db2cf8746d13836c4dbc7fd3d4afedb5523
  displayName: IBM Data Virtualization
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

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
  source: ibm-dv-operator-catalog
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
data "template_file" "bigsql_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-bigsql-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-bigsql-operator-catalog@sha256:a8e5b3b0112080a2907ed1a89ed594dfad51271702a9cdc84cf6d07c9b6ab3a3
  displayName: IBM Db2 Big SQL
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

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
  source: ibm-bigsql-operator-catalog
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
data "template_file" "dmc_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-dmc-operator-catalog
spec:
  image: icr.io/cpopen/ibm-dmc-operator-catalog@sha256:29c5044364843cbdd50abc7a6bfc6ee457cc474eaacac911bfd2a3a31cbe7c1a
  displayName: ibm-dmc-operator-catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

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
  source: ibm-dmc-operator-catalog
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
data "template_file" "cde_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cde-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-cde-operator-catalog@sha256:11b503b9e4d871f43f878e3ca3e25b7d60546a61a383bc6e8058e3a45340e3a0
  displayName: Cloud Pak for Data Cognos Dashboard Embedded
  publisher: IBM
  sourceType: grpc
EOF
}

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
  source: ibm-cde-operator-catalog
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

#REDIS
data "template_file" "redis_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cloud-databases-redis-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cloud-databases-redis-catalog@sha256:d1652894fbeae92a3b904ab6b54f748291e12901510a874e8dec8248e867a960
  displayName: ibm-cloud-databases-redis-operator-catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

data "template_file" "redis_sub"{
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-cloud-databases-redis-operator-v1.4-ibm-cloud-databases-redis-operator-catalog-openshift-marketplace
  namespace: ibm-common-services
spec:
  channel: v1.4
  installPlanApproval: Automatic
  name: ibm-cloud-databases-redis-operator
  source: ibm-cloud-databases-redis-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

#Catalog Source elasticsearch
data "template_file" "elasticsearch_catalog"{
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-elasticsearch-catalog
spec:
  image: icr.io/cpopen/opencontent-elasticsearch-operator-catalog@sha256:41921fb0f258e37cc069c52148a32e9c420340142ce5150d0f9f2ceef483a103
  displayName: IBM elasticsearch Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}


#MDM
data "template_file" "mdm_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-mdm-operator-catalog
spec:
  image: icr.io/cpopen/mdm-operator-catalog@sha256:ac885ccfdd1b55dca55bcc48fb32522e11b676c7ee9724024f7016c8a5d5555a
  displayName: IBM Match 360
  publisher: IBM
  sourceType: grpc
EOF
}
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
  source: ibm-mdm-operator-catalog
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

#DODS
data "template_file" "dods_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-dods-operator-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-dods-operator-catalog@sha256:de9184ac29304628cab6214378f00620dbdc945f10405f354648268359e98c6b
  displayName: IBM Decision Optimization Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 5m
EOF
}

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
    source: ibm-cpd-dods-operator-catalog
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
data "template_file" "pa_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-planning-analytics-operator-catalog
spec:
  image: icr.io/cpopen/ibm-planning-analytics-operator-catalog@sha256:91fd561044adfdf537fa3648f9350b9b1ecbe155e3393284b278af6afd2d96d7
  displayName: IBM Planning Analytics Operator Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}
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
  source: ibm-planning-analytics-operator-catalog
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
data "template_file" "common_services_edb_operandrequest" {
  template = <<EOF
apiVersion: operator.ibm.com/v1alpha1
kind: OperandRequest
metadata:
  name: common-service-edb
  namespace: ibm-common-services
spec:
  requests:
    - operands:
        - name: cloud-native-postgresql
      registry: common-service
EOF
}
data "template_file" "wa_redis_operandrequest" {
  template = <<EOF
apiVersion: operator.ibm.com/v1alpha1
kind: OperandRequest
metadata:
  name: watson-assistant-redis
  namespace: ibm-common-services
spec:
  requests:
    - operands:
        - name: ibm-cloud-databases-redis-operator
      registry: common-service
      registryNamespace: ibm-common-services
EOF
}

data "template_file" "wa_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-watson-assistant-operator-catalog
spec:
  image: icr.io/cpopen/ibm-watson-assistant-operator-catalog@sha256:b239455035a0bbe8d31c7c62810d7926b642952e091a814f9a8040206e458902
  displayName: IBM Watson Assistant Operator Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 15m
EOF
}

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
  source: ibm-watson-assistant-operator-catalog
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
  size: small     # Options are small, medium, and large
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
#WD
data "template_file" "wd_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-watson-discovery-operator-catalog
spec:
  image: icr.io/cpopen/ibm-watson-discovery-operator-catalog@sha256:02006f98ca4276615b6a7e109d961625276ac1ff4c9f103f1cd0e70cc44f6af0
  displayName: Watson Discovery
  publisher: IBM
  sourceType: grpc
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
  source: ibm-watson-discovery-operator-catalog
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
data "template_file" "op_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-cpd-openpages-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: IBM OpenPages Catalog
  publisher: IBM
  sourceType: grpc
  image: "icr.io/cpopen/ibm-cpd-openpages-operator-catalog@sha256:322308f51dd35e4702543859f51a9902c1691051ed9f58ee52dc8999010a1d6e"
  updateStrategy:
    registryPoll:
      interval: 45m
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
  source: ibm-cpd-openpages-operator-catalog
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

data "template_file" "mongodb_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-cpd-mongodb-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-mongodb-operator-catalog@sha256:7ca2c57547bfb759eebf64fcf129f93a33eea5bb9920299ff4dcfdc06b8ff9fa
  displayName: IBM CPD Mongodb Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}
# Watson_gateway
data "template_file" "watson_gateway_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-watson-gateway-operator-catalog
spec:
  image: icr.io/cpopen/watson-gateway-operator-catalog@sha256:d0e5c84cb93e10bc08c20d1e7d9465ffbdd4dd756549351653c4ad297d2230a7
  displayName: IBM Watson Gateway Operator Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}
# rabbitmq
data "template_file" "rabbitmq_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-rabbitmq-operator-catalog
spec:
  image: icr.io/cpopen/opencontent-rabbitmq-operator-catalog@sha256:7eff2d8ddaa95cc965ff2c41c961bef54b3d2fb16d04a48fc11c1bfb582bf54d
  displayName: IBM RabbitMQ operator Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

# Catalog Source ibm-model-train-operator-catalog 
data "template_file" "model_train_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-model-train-operator-catalog
spec:
  image: icr.io/cpopen/ibm-model-train-operator-catalog@sha256:0b4b14e1e7fa6fb2d805c56e18f37b28a706351b1ff99db4f222ad928ba42b89
  displayName: ibm-model-train-operator-catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

# Catalog Source ibm-minio-operator-catalog 
data "template_file" "minio_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-minio-operator-catalog
spec:
  image: icr.io/cpopen/opencontent-minio-operator-catalog@sha256:56e0f265d58a8a9251fadd87d06690d83de2619f8c2838872ae72e657b8cc7ea
  displayName: IBM Minio Operator Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

# Catalog Source ibm-etcd-operator-catalog 
data "template_file" "etcd_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-etcd-operator-catalog
spec:
  image: icr.io/cpopen/ibm-etcd-operator-catalog@sha256:cfa5abdf2231475d7771254ee7115194624a4c84f2883768e1983b4441047b24
  displayName: IBM etcd operator Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

# Catalog Source cloud-native-postgresql-catalog 
data "template_file" "cloud_native_postgres_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: cloud-native-postgresql-catalog
spec:
  image: icr.io/cpopen/ibm-cpd-cloud-native-postgresql-operator-catalog@sha256:37814b7c96b58451f4a060d8fe987d569c3ef1e6da1ea6b4354fd04a521ff9ca
  displayName: Cloud Native Postgresql Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

# Catalog Source ibm-data-governor-operator-catalog
data "template_file" "data_governor_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-data-governor-operator-catalog
spec:
  image: icr.io/cpopen/ibm-data-governor-operator-catalog@sha256:e56a42b12366248ef173af502f77175a9041fe5798756c557f2f107d083942e6
  displayName: IBM Data Governor operator Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}
 
# Catalog Source ibm-auditwebhook-operator-catalog
data "template_file" "auditwebhook_catalog" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  namespace: openshift-marketplace
  name: ibm-auditwebhook-operator-catalog
spec:
  image: icr.io/cpopen/ibm-auditwebhook-operator-catalog@sha256:b1606c9363a87c6fa5dd6043cd0bc8de63b1592ec2567c5a25ff47c353953d31
  displayName: IBM Audit Webhook Operator Catalog
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

 
