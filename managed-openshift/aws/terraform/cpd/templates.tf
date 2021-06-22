locals {
  crio_config_data = base64encode(file("cpd/config/crio.conf"))
  limits_config_data = base64encode(file("cpd/config/limits.conf"))
  sysctl_config_data = base64encode(file("cpd/config/sysctl.conf"))
  license = var.accept_cpd_license == "accept" ? true : false
  override = var.storage_option == "efs" ? "" : var.storage_option
  storage_class = lookup(var.cpd_storageclass, var.storage_option)
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

data "template_file" "bedrock_catalog_source" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Test Operators
  publisher: IBM
  sourceType: grpc
  image: hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com/ibmcom/ibm-common-service-catalog:latest-validated 
  # Alternatively use docker.io/ibmcom/ibm-common-service-catalog:latest for GA untested bedrock build
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

data "template_file" "cpd_platform_operator_catalogsource" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: cpd-platform
  namespace: openshift-marketplace
spec:
  displayName: Cloud Pak for Data
  publisher: IBM
  sourceType: grpc
  image: hyc-cp4d-team-bootstrap-2-docker-local.artifactory.swg-devops.com/cpd-platform-operator-catalog:2.0.0-amd64-122
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
}

data "template_file" "cpd_platform_operator_setup" {
  template = <<EOF
---
apiVersion: operators.coreos.com/v1
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
  channel: stable-v1
  installPlanApproval: Automatic
  name: cpd-platform-operator
  source: cpd-platform
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "cpd_platform_operator_operandrequest" {
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

data "template_file" "zen_catalog_source" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-zen-operator-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: hyc-cp4d-team-bootstrap-2-docker-local.artifactory.swg-devops.com/ibm-zen-operator-catalog:1.1.0-amd64-305
  imagePullPolicy: Always
  displayName: Cloud Pak for Data
  publisher: IBM
EOF
}

data "template_file" "ibm_cpd_lite" {
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
  version: "4.0.0"
  storageClass: ${lookup(var.cpd_storageclass, var.storage_option)}
EOF
}

data "template_file" "operand_registry" {
  template = <<EOF
apiVersion: v1
items:
- apiVersion: operator.ibm.com/v1alpha1
  kind: OperandRegistry
  metadata:
    annotations:
      version: 3.8.0
    creationTimestamp: null
    generation: 1
    name: common-service
    namespace: ${local.operator_namespace}
  spec:
    operators:
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-licensing-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-licensing-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-mongodb-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-mongodb-operator-app
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-cert-manager-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-cert-manager-operator
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-iam-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-iam-operator
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-healthcheck-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-healthcheck-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-commonui-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-commonui-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-management-ingress-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-management-ingress-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-ingress-nginx-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-ingress-nginx-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-auditlogging-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-auditlogging-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-platform-api-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-platform-api-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-monitoring-exporters-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-monitoring-exporters-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-monitoring-prometheusext-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-monitoring-prometheusext-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-monitoring-grafana-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-monitoring-grafana-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-events-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-events-operator
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: stable
      installPlanApproval: Automatic
      name: redhat-marketplace-operator
      namespace: openshift-redhat-marketplace
      packageName: redhat-marketplace-operator
      scope: public
      sourceName: certified-operators
      sourceNamespace: openshift-marketplace
    - channel: stable-v1
      installPlanApproval: Automatic
      name: ibm-zen-operator
      namespace: ${local.operator_namespace}
      packageName: ibm-zen-operator
      scope: public
      sourceName: ibm-zen-operator-catalog
      sourceNamespace: openshift-marketplace
    - channel: v1.1
      installPlanApproval: Automatic
      name: ibm-db2u-operator
      namespace: ${local.operator_namespace}
      packageName: db2u-operator
      scope: public
kind: List
metadata:
  resourceVersion: ""
  selfLink: ""
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
  version: "4.0.0"
  size: "small"
  storageVendor: ${var.storage_option}
  license:
    accept: true
  docker_registry_prefix: cp.stg.icr.io/cp/cpd
EOF
}

data "template_file" "cpd_mirror" {
  template = <<EOF
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: mirror-config
spec:
  repositoryDigestMirrors:
  - mirrors:
    - cp.stg.icr.io/cp/cpd
    source: cp.icr.io/cp/cpd
  - mirrors:
    - cp.stg.icr.io/cp
    - cp.stg.icr.io/cp/cpd
    source: icr.io/cpopen
  - mirrors:
    - hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com/ibmcom
    - hyc-cp4d-team-bootstrap-2-docker-local.artifactory.swg-devops.com
    source: quay.io/opencloudio
  - mirrors:
    - hyc-cp4d-team-bootstrap-docker-local.artifactory.swg-devops.com
    source: docker.io/ibmcom
  - mirrors:
    - hyc-cp4d-team-bootstrap-docker-local.artifactory.swg-devops.com
    - cp.stg.icr.io/cp/cpd
    source: cp.icr.io/cp/cpd
  - mirrors:
    - hyc-cp4d-team-bootstrap-docker-local.artifactory.swg-devops.com
    - hyc-cp4d-team-bootstrap-2-docker-local.artifactory.swg-devops.com
    - cp.stg.icr.io/cp
    - cp.stg.icr.io/cp/cpd
    source: icr.io/cpopen
EOF
}

data "template_file" "openscale_cr" {
  template = <<EOF
apiVersion: wos.cpd.ibm.com/v1
kind: WOService
metadata:
  name: aiopenscale
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

data "template_file" "wml_cr" {
  template = <<EOF
apiVersion: wml.cpd.ibm.com/v1beta1
kind: WmlBase
metadata:
  name: wml-cr
  labels:
    app.kubernetes.io/instance: wml-cr
    app.kubernetes.io/managed-by: ibm-cpd-wml-operator
    app.kubernetes.io/name: ibm-cpd-wml-operator
spec:
  scaleConfig: small
  is_35_upgrade: false
  ignoreForMaintenance: false
  docker_registry_prefix: "cp.icr.io/cp/cpd"
  storageClass: "${local.storage_class}"
  storageVendor: "${var.storage_option}"
  version: "4.0.0"
  license:
    accept: true
    license: "Enterprise"
EOF
}