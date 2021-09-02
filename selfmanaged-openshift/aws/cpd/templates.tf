locals {
  crio_config_data   = base64encode(file("cpd/config/crio.conf"))
  limits_config_data = base64encode(file("cpd/config/limits.conf"))
  sysctl_config_data = base64encode(file("cpd/config/sysctl.conf"))
  license            = var.accept_cpd_license == "accept" ? true : false
  storage_class      = lookup(var.cpd_storageclass, var.storage_option)
  rwo_storage_class  = lookup(var.rwo_cpd_storageclass, var.storage_option)
}

data "template_file" "crio_machineconfig" {
  template = <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 90-worker-crio
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,${local.crio_config_data}
        filesystem: root
        mode: 0644
        path: /etc/crio/crio.conf
EOF
}

data "template_file" "limits_machineconfig" {
  template = <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 90-worker-limits
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,${local.limits_config_data}
        filesystem: root
        mode: 0644
        path: /etc/security/limits.conf
EOF
}

data "template_file" "sysctl_machineconfig" {
  template = <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 90-worker-sysctl
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,${local.sysctl_config_data}
        filesystem: root
        mode: 0644
        path: /etc/sysctl.conf
EOF
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
  image: docker.io/ibmcom/ibm-db2uoperator-catalog:latest
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
  channel: v2.0
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
  version: "4.0.1"
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
  channel: v1.0
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
    channel: stable-v1
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
  version: "4.0.1"
  storageClass: ${local.storage_class}
  storageVendor: ${var.storage_option}
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
  channel: v1.0
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
  channel: v1.0
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
  channel: v2.0
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
  version: "4.0.1"
  size: "small"
  storageClass: ${local.storage_class}
  storageVendor: ${var.storage_option}
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
    channel: v1.1
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
  storageVendor: ${var.storage_option}
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
  channel: v1
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
  version: 4.0.1
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
    channel: v1.0
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
  version: "4.0.1"
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
  channel: v1.0
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
  version: "4.0.1"
  storageVendor: "${var.storage_option}"
  license:
    accept: true
    license: Enterprise
  docker_registry_prefix: cp.icr.io/cp/cpd
  useODLM: true
  # wkc_db2u_set_kernel_params: True
  # iis_db2u_set_kernel_params: True
  # install_wkc_core_only: true     # To install the core version of the service, remove the comment tagging from the beginning of the line.
EOF
}

#Datastage
data "template_file" "ds_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-datastage-operator
  namespace: ${local.operator_namespace}
spec: 
  channel: v1.0
  installPlanApproval: Automatic 
  name: ibm-datastage-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "ds_cr" {
  template = <<EOF
apiVersion: dfd.cpd.ibm.com/v1alpha1
kind: DataStageService
metadata:
  name: datastage-cr
  namespace: ${var.cpd_namespace}
spec:
  license:
    accept: true
    license: Enterprise
  scaleConfig: small
  version: 4.0.1
EOF
}

#IIS
data "template_file" "ds_iis_cr" {
  template = <<EOF
apiVersion: iis.cpd.ibm.com/v1alpha1
kind: IIS
metadata:
  name: iis-cr
  namespace: ${var.cpd_namespace}
spec:
  version: "4.0.1"
  size: small
  scaleConfig: small
  storageVendor: "${var.storage_option}"
  storageClass: ${local.storage_class}
  storageOverride:
  license:
    accept: true
    license: Enterprise
  docker_registry_prefix: cp.icr.io/cp/cpd
  use_dynamic_provisioning: true
  cert_manager_enabled: true
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
  channel: v4.0
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
  version: "4.0.1"
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
  channel: v1.7
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
  version: 1.7.1
  size: "small"
  docker_registry_prefix: cp.icr.io/cp/cpd
EOF
}

#DMC
data "template_file" "dmc_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-dmc-operator-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: v1.0
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
  name: dmcaddon-cr
  namespace: ${var.cpd_namespace}
spec:
  namespace: "${var.cpd_namespace}"
  storageClass: ${local.storage_class}
  pullPrefix: cp.icr.io/cp/cpd
  version: "4.0.1"
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
  channel: v1.0
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
  version: 4.0.1
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
  channel: v1.1
  installPlanApproval: Automatic
  name: ibm-mdm
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "mdm_cr" {
  template = <<EOF
apiVersion: mdm.cpd.ibm.com/v1
kind: MasterDataManagement
metadata:
  name: mdm-cr
  namespace: ${var.cpd_namespace}
spec:
  version: 4.0.1
  size: "small"
  docker_registry_prefix: "cp.icr.io/cp/cpd"
  namespace: "${var.cpd_namespace}"
  storageClass: "${local.storage_class}"
  cert_manager_enabled: true
  license:
    accept: true
    license: Enterprise
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
    channel: v4.0
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
  version: 4.0.1
EOF
}

