locals {
  storage_type_key   = var.storage_option == "portworx" ? "storageVendor: portworx" : "fileStorageClass: ${local.storage_class}\n  blockStorageClass: ${local.rwo_storage_class}"
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

data "template_file" "wkc_cr" {
  template = <<EOF
apiVersion: wkc.cpd.ibm.com/v1beta1
kind:  WKC
metadata:
  name: wkc-cr
  namespace: ${var.cpd_namespace}
spec:
  license:
    accept: true
    license: Enterprise
  ${local.storage_type_key}
  wkc_db2u_set_kernel_params: True
  iis_db2u_set_kernel_params: True
  version: ${var.cpd_version}
EOF
}

