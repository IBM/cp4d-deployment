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
    systemReserved:
      cpu: 1000m
      memory: 1Gi
    allowedUnsafeSysctls:
      - "kernel.msg*"
      - "kernel.shm*"
      - "kernel.sem"
EOF
}

data "template_file" "ccs_dr_catalogs" {
  template = <<EOF
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-cpd-datarefinery-operator-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: icr.io/cpopen/ibm-cpd-datarefinery-operator-catalog@sha256:27c6b458244a7c8d12da72a18811d797a1bef19dadf84b38cedf6461fe53643a
  imagePullPolicy: Always
  displayName: Cloud Pak for Data IBM DataRefinery
  publisher: IBM
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-cpd-ccs-operator-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: icr.io/cpopen/ibm-cpd-ccs-operator-catalog@sha256:34854b0b5684d670cf1624d01e659e9900f4206987242b453ee917b32b79f5b7
  imagePullPolicy: Always
  displayName: CPD Common Core Services
  publisher: IBM
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

data "template_file" "db2aaservice_catalog_source" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-db2aaservice-cp4d-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: IBM Db2aaservice CP4D Catalog
  image: icr.io/cpopen/ibm-db2aaservice-cp4d-operator-catalog@sha256:a0d9b6c314193795ec1918e4227ede916743381285b719b3d8cfb05c35fec071
  imagePullPolicy: Always
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
  channel: v1.0
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
  license:
    accept: true
    license: "Enterprise"
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

data "template_file" "ibm_common_services_operator" {
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
  name: ibm-common-service-operator
  namespace: ${local.operator_namespace}
spec:
  channel: v3
  installPlanApproval: Automatic
  name: ibm-common-service-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cpd-operator
  namespace: ${local.operator_namespace}
spec:
  channel: stable-v1
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
  name: zen-service
  namespace: ${var.cpd_namespace}
spec:
  requests:
    - operands:
        - name: ibm-cert-manager-operator
        - name: ibm-licensing-operator
        - name: ibm-zen-operator
        - name: ibm-db2u-operator
      registry: common-service
      registryNamespace: ${local.operator_namespace}
EOF
}

data "template_file" "lite_cr" {
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
  labels:
    app.kubernetes.io/instance: ibm-analyticsengine-operator
    app.kubernetes.io/managed-by: ibm-analyticsengine-operator
    app.kubernetes.io/name: ibm-analyticsengine-operator
    build: 4.0.0
spec:
  version: "4.0.0"
  storageClass: ${local.storage_class}
  license:
    accept: true
EOF
}

#DB2WH
data "template_file" "db2wh_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-db2wh-cp4d-operator
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

#WSL
data "template_file" "ws_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  annotations: {}
  name: ibm-cpd-ws-operator-catalog
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
spec:
  version: "4.0.0"
  size: "small"
  storageClass: ${local.storage_class}
  storageVendor: ${var.storage_option}
  license:
    accept: true
    license: Enterprise
  docker_registry_prefix: "cp.icr.io/cp/cpd"
EOF
}

#CCS
data "template_file" "ccs_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  annotations: {}
  name: ibm-cpd-ccs-operator
  namespace: ${local.operator_namespace}
spec:
  channel: v1.0
  config:
    resources: {}
  installPlanApproval: Automatic
  name: ibm-cpd-ccs
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "ccs_cr" {
  template = <<EOF
apiVersion: ccs.cpd.ibm.com/v1beta1
kind: CCS
metadata:
  name: ccs-cr
  namespace: ${var.cpd_namespace}
spec:
  size: "small"
  storageVendor: ${var.storage_option}
  license:
    accept: true
    license: Enterprise
  docker_registry_prefix: "cp.icr.io/cp/cpd"
EOF
}


#WML
data "template_file" "wml_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    app.kubernetes.io/instance: ibm-cpd-wml-operator
    app.kubernetes.io/managed-by: ibm-cpd-wml-operator
    app.kubernetes.io/name: ibm-cpd-wml-operator
  name: ibm-cpd-wml-operator
  namespace: ${local.operator_namespace}
spec:
    channel: alpha
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
    app.kubernetes.io/instance: wml
    app.kubernetes.io/managed-by: ibm-cpd-wml-operator
    app.kubernetes.io/name: ibm-cpd-wml-operator
spec:
  scaleConfig: small
  is_35_upgrade: false
  ignoreForMaintenance: false
  docker_registry_prefix: "cp.icr.io/cp/cpd"
  storageClass: ${local.storage_class}
  storageVendor: ${var.storage_option}
  version: "4.0.0"
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
  name: ibm-watson-openscale-operator
  labels:
    app.kubernetes.io/instance: ibm-watson-openscale-operator
    app.kubernetes.io/managed-by: ibm-watson-openscale-operator
    app.kubernetes.io/name: ibm-watson-openscale-operator
  namespace: ${local.operator_namespace}
spec:
  channel: alpha
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
  version: 4.0.0
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
    app.kubernetes.io/instance: ibm-cpd-spss-operator
    app.kubernetes.io/managed-by: ibm-cpd-spss-operator
    app.kubernetes.io/name: ibm-cpd-spss-operator
  name: ibm-cpd-spss-operator
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
spec:
  version: "4.0.0"
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
    app.kubernetes.io/instance:  ibm-cpd-wkc-operator
    app.kubernetes.io/managed-by: ibm-cpd-wkc-operator
    app.kubernetes.io/name:  ibm-cpd-wkc-operator
  name: ibm-cpd-wkc-operator
  namespace: ibm-common-services
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
  version: "4.0.0"
  storageVendor: "${var.storage_option}"
  license:
    accept: true
    license: Enterprise
  docker_registry_prefix: cp.icr.io/cp/cpd
EOF
}

data "template_file" "wkc_iis_cr" {
  template = <<EOF
apiVersion: iis.cpd.ibm.com/v1alpha1
kind: IIS
metadata:
  name: iis-cr
  namespace: ${var.cpd_namespace}
spec:
  storageVendor: "${var.storage_option}"
  license:
    accept: true
    license: Enterprise
  docker_registry_prefix: cp.icr.io/cp/cpd
  use_dynamic_provisioning: true
EOF
}

data "template_file" "wkc_ug_cr" {
  template = <<EOF
apiVersion: wkc.cpd.ibm.com/v1beta1
kind: UG
metadata:
  name: ug-cr
  namespace: ${var.cpd_namespace}
spec:
  version: "4.0.0"
  size: "small"
  storageVendor: "${var.storage_option}"
  license:
    accept: true
    license: "Enterprise"
  docker_registry_prefix: cp.icr.io/cp/cpd
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
##################

#CA
data "template_file" "ca_sub" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-ca-operator
  labels:
    app.kubernetes.io/instance: ibm-ca-operator
    app.kubernetes.io/managed-by: ibm-ca-operator
    app.kubernetes.io/name: ibm-ca-operator
  namespace: ${local.operator_namespace}
spec:
  channel: v4
  name: ibm-ca-operator
  installPlanApproval: Automatic
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
}

#DV
data "template_file" "dv_catalog_source" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-dv-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: IBM Data Virtualization
  image: icr.io/cpopen/ibm-cpd-dv-operator-catalog@sha256:96398727f1b37137ec268c6f6dd2e3a0fd38c88b144abe0fd0d32361e82d47e6
  imagePullPolicy: Always
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
  labels:
    app.kubernetes.io/instance: ibm-dv-operator-subscription
    app.kubernetes.io/managed-by: ibm-dv-operator
    app.kubernetes.io/name: ibm-dv-operator-subscription
  name: ibm-dv-operator-catalog-subscription
  namespace: ${local.operator_namespace}
spec:
    channel: v1.0
    installPlanApproval: Automatic
    name: ibm-dv-operator
    source: ibm-dv-operator-catalog
    sourceNamespace: openshift-marketplace
    startingCSV: ibm-dv-operator.v1.7.0     # DO NOT CHANGE THIS VERSION NUMBER
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
  version: 1.7.0
  size: "small"
  docker_registry_prefix: cp.icr.io/cp/cpd
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
  version: 4.0.0
EOF
}

#DMC
data "template_file" "dmc_catalog_source" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-cloud-databases-redis-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-cloud-databases-redis-operator-catalog
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/ibm-cloud-databases-redis-catalog@sha256:980e4182ec20a01a93f3c18310e0aa5346dc299c551bd8aca070ddf2a5bf9ca5
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-dmc-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-dmc-operator-catalog
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/ibm-dmc-operator-catalog@sha256:a3a395ffec07b3f426718aed54ec164badfd55a7445c29f317da242409ae5d00
  updateStrategy:
    registryPoll:
      interval: 45m
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
  namespace: zen
  storageClass: ${local.storage_class}
  pullPrefix: cp.icr.io/cp/cpd
  version: "4.0.0"
  license:
    accept: true
    license: Standard 
EOF
}

#CDE
data "template_file" "cde_cr" {
  template = <<EOF
apiVersion: cde.cpd.ibm.com/v1
kind: CdeProxyService
metadata:
  name: cde-cr
  namespace: ${var.cpd_namespace}
spec:
  version: 4.0.0
  size: "small"
  namespace: "${var.cpd_namespace}"
  storageClass: "${local.storage_class}"
  cert_manager_enabled: true
  license:
    accept: true
    license: Enterprise
EOF
}

#CA
data "template_file" "ca_catalog_source" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-ca-operator-catalog
  labels:
    app.kubernetes.io/instance: ibm-ca-operator
    app.kubernetes.io/managed-by: ibm-ca-operator
    app.kubernetes.io/name: ibm-ca-operator
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: icr.io/cpopen/ibm-ca-operator-catalog@sha256:b77c74d35a7405eb4997bd09d249266d1d2c007634f3b76afd3c7fa8e12280ee
  displayName: ibm-ca-operator-catalog
  publisher: IBM
  updateStrategy:
    registryPoll:
      interval: 45m
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
  version: "4.0.0"
  license:
    accept: true
    license: "Enterprise"
  storage_class: "${local.storage_class}"
  namespace: "${var.cpd_namespace}"
EOF
}

#DB2uOperator
data "template_file" "db2u_operator" {
  template = <<EOF
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-db2uoperator-catalog
  namespace: openshift-marketplace
spec:
  displayName: IBM Db2U Catalog
  image: docker.io/ibmcom/ibm-db2uoperator-catalog@sha256:5b7571e2220e2b706a2de151ea8be2a6c7df2fbce974d0e77bf97e4cbcdcac80
  imagePullPolicy: Always
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-db2uoperator-catalog-subscription
  namespace: ${local.operator_namespace}
spec:
  channel: v1.1
  name: db2u-operator
  installPlanApproval: Automatic
  source: ibm-db2uoperator-catalog
  sourceNamespace: openshift-marketplace
  startingCSV: db2u-operator.v1.1.2
EOF
}
