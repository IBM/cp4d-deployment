data "template_file" "portworx_storagecluster" {
  template = <<EOF
kind: StorageCluster
apiVersion: core.libopenstorage.org/v1
metadata:
  name: ${var.px_generated_cluster_name}
  namespace: ${var.px_namespace}
  annotations:
    portworx.io/is-openshift: "true"
spec:
  image: portworx/oci-monitor:2.6.3
  imagePullPolicy: Always
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

data "template_file" "portworx_subscription" {
  template = <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  generation: 1
  name: portworx-certified
  namespace: kube-system
spec:
  channel: stable
  installPlanApproval: Automatic
  name: portworx-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
  startingCSV:  portworx-operator.v1.4.2
EOF
}

data "template_file" "portworx_operator_group" {
  template = <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kube-system-operatorgroup
  namespace: kube-system
spec:
  serviceAccount:
    metadata:
      creationTimestamp: null
  targetNamespaces:
  - kube-system
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