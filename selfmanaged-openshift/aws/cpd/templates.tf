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

data "template_file" "cpd_service" {
  template = <<EOF
apiVersion: metaoperator.cpd.ibm.com/v1
kind: CPDService
metadata:
  name: SERVICE-cpdservice
  labels:
    app.kubernetes.io/instance: ibm-cp-data-operator-SERVICE-cpdservice
    app.kubernetes.io/managed-by: ibm-cp-data-operator
    app.kubernetes.io/name: ibm-cp-data-operator-SERVICE-cpdservice
spec:
  serviceName: SERVICE
  skipImageTransfer: false
  version: "latest"
  storageClass: ${local.storage_class}
  overrideConfig: "${local.override}"
  flags: ""
  autoPatch: false
  scale: ""
  optionalModules: []
  license:
    accept: ${local.license}
EOF
}