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

data "template_file" "bedrock_setup" {
  template = <<EOF
---
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: bedrock-zen-edge-mirror
spec:
  repositoryDigestMirrors:
  - mirrors:
    - hyc-cp4d-team-bootstrap-2-docker-local.artifactory.swg-devops.com
    - hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com/ibmcom
    source: quay.io/opencloudio
  - mirrors:
    - hyc-cp4d-team-bootstrap-docker-local.artifactory.swg-devops.com
    - hyc-cp4d-team-bootstrap-2-docker-local.artifactory.swg-devops.com
    source: icr.io/cpopen
---
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
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    openshift.io/cluster-monitoring: "true"
  name: ibm-common-services
spec: {}
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: common-service-operator-group
  namespace: ibm-common-services
spec:
  targetNamespaces:
    - ibm-common-services
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-common-service-operator
  namespace: ibm-common-services
spec:
  channel: v3
  installPlanApproval: Automatic
  name: ibm-common-service-operator
  source: opencloud-operators
  sourceNamespace: openshift-marketplace
EOF
}

data "template_file" "zen_setup" {
  template = <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    openshift.io/cluster-monitoring: "true"
  name: zen
spec: {}
---
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

data "template_file" "zen_operand_request" {
  template = <<EOF
apiVersion: operator.ibm.com/v1alpha1
kind: OperandRequest
metadata:
  name: zen-service
  namespace: zen
spec:
  requests:
    - operands:
        - name: ibm-zen-operator
        - name: ibm-cert-manager-operator
      registry: common-service
      registryNamespace: ibm-common-services
EOF
}

data "template_file" "zen_service_lite" {
  template = <<EOF
apiVersion: zen.cpd.ibm.com/v1
kind: ZenService
metadata:
  name: lite
  namespace: zen
spec:
  csNamespace: ibm-common-services
  iamIntegration: true
  version: ${var.cpd_version}
  storageClass: ${lookup(var.cpd_storageclass, var.storage_option)}
  cloudpakfordata: true 
  zenCoreMetaDbStorageClass: ${lookup(var.cpd_storageclass, var.storage_option)}
  #cert_manager_enabled: false
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
    namespace: ibm-common-services
  spec:
    operators:
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-licensing-operator
      namespace: ibm-common-services
      packageName: ibm-licensing-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-mongodb-operator
      namespace: ibm-common-services
      packageName: ibm-mongodb-operator-app
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-cert-manager-operator
      namespace: ibm-common-services
      packageName: ibm-cert-manager-operator
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-iam-operator
      namespace: ibm-common-services
      packageName: ibm-iam-operator
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-healthcheck-operator
      namespace: ibm-common-services
      packageName: ibm-healthcheck-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-commonui-operator
      namespace: ibm-common-services
      packageName: ibm-commonui-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-management-ingress-operator
      namespace: ibm-common-services
      packageName: ibm-management-ingress-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-ingress-nginx-operator
      namespace: ibm-common-services
      packageName: ibm-ingress-nginx-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-auditlogging-operator
      namespace: ibm-common-services
      packageName: ibm-auditlogging-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-platform-api-operator
      namespace: ibm-common-services
      packageName: ibm-platform-api-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-monitoring-exporters-operator
      namespace: ibm-common-services
      packageName: ibm-monitoring-exporters-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-monitoring-prometheusext-operator
      namespace: ibm-common-services
      packageName: ibm-monitoring-prometheusext-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-monitoring-grafana-operator
      namespace: ibm-common-services
      packageName: ibm-monitoring-grafana-operator-app
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v3
      installPlanApproval: Automatic
      name: ibm-events-operator
      namespace: ibm-common-services
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
      namespace: ibm-common-services
      packageName: ibm-zen-operator-catalog
      scope: public
      sourceName: opencloud-operators
      sourceNamespace: openshift-marketplace
    - channel: v1.1
      installPlanApproval: Automatic
      name: ibm-db2u-operator
      namespace: ibm-common-services
      packageName: db2u-operator
      scope: public
kind: List
metadata:
  resourceVersion: ""
  selfLink: ""
EOF
}