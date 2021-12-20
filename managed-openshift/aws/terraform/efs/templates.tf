locals {}

data "template_file" "efs_test_pvc" {
  template = <<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: efs-csi-claim
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: aws-efs-csi
  volumeMode: Filesystem
EOF
}

data "template_file" "efs_sc" {
  template = <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: aws-efs-csi
provisioner: efs.csi.aws.com
mountOptions:
  - tls
parameters:
  provisioningMode: efs-ap
  fileSystemId: ${aws_efs_file_system.cpd_efs.id} 
  directoryPerms: "777"
  gid: "1000" 
  uid: "500" 
  basePath: "/cpd"
EOF
}