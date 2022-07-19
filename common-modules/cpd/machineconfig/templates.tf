data "template_file" "crio_ctrcfg" {
  template = <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: ContainerRuntimeConfig
metadata:
  name: new-large-pidlimit
spec:
  containerRuntimeConfig:
    pidsLimit: 12288
  machineConfigPoolSelector:
    matchExpressions:
    - key: pools.operator.machineconfiguration.openshift.io/worker
      operator: Exists
EOF
}