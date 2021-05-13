data "template_file" "portworx_operator" {
    template = <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: portworx-operator
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: portworx-operator
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: portworx-operator
subjects:
  - kind: ServiceAccount
    name: portworx-operator
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: portworx-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portworx-operator
  namespace: kube-system
spec:
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  replicas: 1
  selector:
    matchLabels:
      name: portworx-operator
  template:
    metadata:
      labels:
        name: portworx-operator
    spec:
      containers:
      - name: portworx-operator
        image: ${local.priv_image_registry}/px-operator:1.4.4
        imagePullPolicy: IfNotPresent
        command:
        - /operator
        - --verbose
        - --driver=portworx
        - --leader-elect=true
        env:
        - name: OPERATOR_NAME
          value: portworx-operator
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: "name"
                    operator: In
                    values:
                    - portworx-operator
              topologyKey: "kubernetes.io/hostname"
      serviceAccountName: portworx-operator
EOF
}

data "template_file" "portworx_storagecluster" {
  template = <<EOF
kind: StorageCluster
apiVersion: core.libopenstorage.org/v1
metadata:
  name: px-storage-cluster
  namespace: kube-system
  annotations:
    portworx.io/misc-args: "--oem ibm-icp4d"
    portworx.io/is-openshift: "true"
spec:
  image: kube-system/oci-monitor:2.7.0
  customImageRegistry: ${local.priv_image_registry}
  imagePullPolicy: IfNotPresent
  kvdb:
    internal: true
  cloudStorage:
    deviceSpecs:
    - type=gp2,size=${var.disk_size}
    kvdbDeviceSpec: type=gp2,size=${var.kvdb_disk_size}
  secretsProvider: ${var.secret_provider}
  stork:
    enabled: true
    args:
      webhook-controller: "false"
  autopilot:
    enabled: true
    providers:
    - name: default
      type: prometheus
      params:
        url: http://prometheus:9090%{if var.px_enable_monitoring}${indent(2, "\nmonitoring:")}
    prometheus:
      enabled: true%{endif}
      exportMetrics: true%{if var.px_enable_csi}${indent(2, "\nfeatureGates:")}
    CSI: "true"%{endif}
  deleteStrategy:
    type: UninstallAndWipe
  env:
  - name: "AWS_ACCESS_KEY_ID"
    value: "${var.aws_access_key_id}"
  - name: "AWS_SECRET_ACCESS_KEY"
    value: "${var.aws_secret_access_key}"
  - name: "AWS_CMK"
    value: "${aws_kms_key.px_key.key_id}"
  - name: "AWS_REGION"
    value: "${var.region}"
EOF
}

data "template_file" "storage_classes" {
  template = <<EOF
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: portworx-shared-sc
provisioner: kubernetes.io/portworx-volume
parameters:
  repl: "1"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  priority_io: "high"
  sharedv4: "true"
allowVolumeExpansion: true
volumeBindingMode: Immediate
reclaimPolicy: Retain
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: portworx-couchdb-sc
provisioner: kubernetes.io/portworx-volume
parameters:
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  priority_io: "high"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: portworx-elastic-sc
provisioner: kubernetes.io/portworx-volume
parameters:
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  priority_io: "high"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: portworx-solr-sc
provisioner: kubernetes.io/portworx-volume
parameters:
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  priority_io: "high"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: portworx-cassandra-sc
provisioner: kubernetes.io/portworx-volume
parameters:
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  priority_io: "high"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: portworx-kafka-sc
provisioner: kubernetes.io/portworx-volume
parameters:
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  priority_io: "high"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-metastoredb-sc
parameters:
  priority_io: high
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-shared-gp
parameters:
  priority_io: high
  repl: "1"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  sharedv4: "true"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-shared-gp2
parameters:
  priority_io: high
  repl: "2"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  sharedv4: "true"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-shared-gp3
parameters:
  priority_io: high
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  sharedv4: "true"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db-gp
parameters:
  repl: "1"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db-gp3
parameters:
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-nonshared-gp
parameters:
  priority_io: high
  repl: "1"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-nonshared-gp2
parameters:
  priority_io: high
  repl: "2"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-gp3-sc
parameters:
  priority_io: high
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-shared-gp-allow
parameters:
  priority_io: high
  repl: "2"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  sharedv4: "true"
  io_profile: "cms"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-rwx-sc
parameters:
  block_size: 4096b
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  sharedv4: "true"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-rwo-sc
parameters:
  priority_io: high
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  sharedv4: "false"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-dv-shared-gp
parameters:
  priority_io: high 
  repl: "1"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  shared: "true"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-assistant
parameters:
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  priority_io: "high"
  block_size: "64k"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-fci-sc
provisioner: kubernetes.io/portworx-volume
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
parameters:
  block_size: 512b
  priority_io: high
  repl: "3"%{if var.px_encryption}${indent(2, "\nsecure: \"true\"")}%{endif}
  sharedv4: "false"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
EOF
}