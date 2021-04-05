data "template_file" "efs_configmap" {
  template = <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: efs-provisioner
  namespace: efs-storage
data:
  file.system.id: ${aws_efs_file_system.efs.id}
  aws.region: ${var.region}
  provisioner.name: openshift.org/aws-efs
  dns.name: ${local.dns_name}
EOF
}

data "template_file" "service_account" {
  template = <<EOF
kind: ServiceAccount
apiVersion: v1
metadata:
  name: efs-provisioner
  namespace: efs-storage
EOF
}

data "template_file" "efs_provisioner" {
  template = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: efs-provisioner
  namespace: efs-storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: efs-provisioner
  template:
    metadata:
      labels:
        app: efs-provisioner
    spec:
      serviceAccount: efs-provisioner
      containers:
        - name: efs-provisioner
          image: quay.io/external_storage/efs-provisioner:latest
          env:
            - name: PROVISIONER_NAME
              valueFrom:
                configMapKeyRef:
                  name: efs-provisioner
                  key: provisioner.name
            - name: FILE_SYSTEM_ID
              valueFrom:
                configMapKeyRef:
                  name: efs-provisioner
                  key: file.system.id
            - name: AWS_REGION
              valueFrom:
                configMapKeyRef:
                  name: efs-provisioner
                  key: aws.region
            - name: DNS_NAME
              valueFrom:
                configMapKeyRef:
                  name: efs-provisioner
                  key: dns.name
                  optional: true
          volumeMounts:
            - name: pv-volume
              mountPath: /persistentvolumes
      volumes:
        - name: pv-volume
          nfs:
            server: ${local.dns_name}
            path: /
EOF
}

data "template_file" "efs_namespace" {
  template = <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: efs-storage
spec: {}
EOF
}

data "template_file" "efs_storageclass" {
  template = <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-efs
provisioner: openshift.org/aws-efs
parameters:
  gidMin: "2048"
  gidMax: "2147483647"
  gidAllocate: "true"
EOF
}

data "template_file" "efs_roles" {
  template = <<EOF
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: efs-provisioner-runner
  namespace: efs-storage
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
  - apiGroups: ["security.openshift.io"]
    resources: ["securitycontextconstraints"]
    verbs: ["use"]
    resourceNames: ["hostmount-anyuid"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-efs-provisioner
  namespace: efs-storage
subjects:
  - kind: ServiceAccount
    name: efs-provisioner
    namespace: efs-storage
roleRef:
  kind: ClusterRole
  name: efs-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-efs-provisioner
  namespace: efs-storage
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-efs-provisioner
  namespace: efs-storage
subjects:
  - kind: ServiceAccount
    name: efs-provisioner
    namespace: efs-storage
roleRef:
  kind: Role
  name: leader-locking-efs-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF
}