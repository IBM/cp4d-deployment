data "template_file" "px_install_yaml" {
  template = <<EOF
---
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
---
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
EOF
}

data "template_file" "px_storage_classes" {
  template = <<EOF
---
# CouchDB (Implemented application-level redundancy)
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-couchdb-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# ElasticSearch (Implemented application-level redundancy)
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-elastic-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "2"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Solr
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-solr-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Cassandra
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-cassandra-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Kafka
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-kafka-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# metastoredb:
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-metastoredb-sc
parameters:
  priority_io: high
  io_profile: db_remote
  repl: "3"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose, 3 Replicas - Default SC for other applications
# without specific SC defined and with RWX volume access mode - New Install
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-rwx-gp3-sc
parameters:
  priority_io: high
  repl: "3"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose, 3 Replicas [Default for other applications without
# specific SC defined and with RWX volume access mode] - SC portworx-shared-gp3 for upgrade purposes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-shared-gp3
parameters:
  priority_io: high
  repl: "3"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose, 2 Replicas RWX volumes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-rwx-gp2-sc
parameters:
  priority_io: high
  repl: "2"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# DV - Single replica
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-dv-shared-gp
parameters:
  block_size: 4096b
  priority_io: high
  repl: "1"
  shared: "true"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# DV - three replicas
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-dv-shared-gp3
parameters:
  block_size: 4096b
  priority_io: high
  repl: "3"
  shared: "true"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Streams 
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
 name: portworx-shared-gp-allow
parameters:
 priority_io: high
 repl: "3"
 io_profile: "cms"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Delete
volumeBindingMode: Immediate
---
#  General Purpose, 1 Replica - RWX volumes for TESTING ONLY.
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-rwx-gp-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "1"
 priority_io: "high"
 sharedv4: "true"
 io_profile: db_remote
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
volumeBindingMode: Immediate
reclaimPolicy: Delete
---
# General Purpose, 3 Replicas - RWX volumes - placeholder SC portworx-shared-gp for upgrade purposes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-shared-gp
parameters:
  priority_io: high
  repl: "3"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose, 3 Replicas RWO volumes rabbitmq and redis-ha - New Install 
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-gp3-sc
parameters:
  priority_io: high
  repl: "3"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose, 3 Replicas RWO volumes rabbitmq and redis-ha - placeholder SC portworx-nonshared-gp2 for upgrade purposes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-nonshared-gp2
parameters:
  priority_io: high
  repl: "3"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# gp db
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db-gp
parameters:
  io_profile: "db_remote"
  repl: "1"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose for Databases, 2 Replicas - MongoDB - (Implemented application-level redundancy)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db-gp2-sc
parameters:
  priority_io: "high"
  io_profile: "db_remote"
  repl: "2"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose for Databases, 3 Replicas
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db-gp3-sc
parameters:
  io_profile: "db_remote"
  repl: "3"
  priority_io: "high"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# DB2 RWX shared volumes for System Storage, backup storage, future load storage, and future diagnostic logs storage
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-rwx-sc
parameters:
  io_profile: cms
  block_size: 4096b
  repl: "3"
  sharedv4: "true"
  priority_io: high
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Db2 RWO volumes SC for user storage, future transaction logs storage, future archive/mirrors logs storage. This is also used for WKC DB2 Metastore
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-rwo-sc
parameters:
  block_size: 4096b
  io_profile: db_remote
  priority_io: high
  repl: "3"
  sharedv4: "false"
  disable_io_profile_protection: "1"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# WKC DB2 Metastore - SC portworx-db2-sc for upgrade purposes 
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-sc
parameters:
  io_profile: "db_remote"
  priority_io: high
  repl: "3"
  disable_io_profile_protection: "1"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Watson Assitant - This was previously named portworx-assitant 
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-watson-assistant-sc
parameters:
   repl: "3"
   priority_io: "high"
   io_profile: "db_remote"
   block_size: "64k"
   disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# FCI DB2 Metastore
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
  io_profile: db_remote
  priority_io: high
  repl: "3"
  disable_io_profile_protection: "1"
EOF
}

data "template_file" "px_secure_storage_classes" {
  template = <<EOF
---
# CouchDB (Implemented application-level redundancy)
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-couchdb-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 secure: "true"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# ElasticSearch (Implemented application-level redundancy)
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-elastic-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "2"
 secure: "true"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Solr
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-solr-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 secure: "true"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Cassandra
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-cassandra-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 secure: "true"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Kafka
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-kafka-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 secure: "true"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# metastoredb:
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-metastoredb-sc
parameters:
  priority_io: high
  io_profile: db_remote
  repl: "3"
  secure: "true"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose, 3 Replicas - Default SC for other applications
# without specific SC defined and with RWX volume access mode - New Install
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-rwx-gp3-sc
parameters:
  priority_io: high
  repl: "3"
  secure: "true"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose, 3 Replicas [Default for other applications without
# specific SC defined and with RWX volume access mode] - SC portworx-shared-gp3 for upgrade purposes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-shared-gp3
parameters:
  priority_io: high
  repl: "3"
  secure: "true"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose, 2 Replicas RWX volumes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-rwx-gp2-sc
parameters:
  priority_io: high
  repl: "2"
  secure: "true"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# DV - Single replica
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-dv-shared-gp
parameters:
  block_size: 4096b
  priority_io: high
  repl: "1"
  secure: "true"
  shared: "true"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# DV - three replicas
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-dv-shared-gp3
parameters:
  block_size: 4096b
  priority_io: high
  repl: "3"
  secure: "true"
  shared: "true"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Streams 
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
 name: portworx-shared-gp-allow
parameters:
 priority_io: high
 repl: "3"
 secure: "true"
 io_profile: "cms"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Delete
volumeBindingMode: Immediate
---
#  General Purpose, 1 Replica - RWX volumes for TESTING ONLY.
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-rwx-gp-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "1"
 secure: "true"
 priority_io: "high"
 sharedv4: "true"
 io_profile: db_remote
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
volumeBindingMode: Immediate
reclaimPolicy: Delete
---
# General Purpose, 3 Replicas - RWX volumes - placeholder SC portworx-shared-gp for upgrade purposes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-shared-gp
parameters:
  priority_io: high
  repl: "3"
  secure: "true"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose, 3 Replicas RWO volumes rabbitmq and redis-ha - New Install 
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-gp3-sc
parameters:
  priority_io: high
  repl: "3"
  secure: "true"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose, 3 Replicas RWO volumes rabbitmq and redis-ha - placeholder SC portworx-nonshared-gp2 for upgrade purposes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-nonshared-gp2
parameters:
  priority_io: high
  repl: "3"
  secure: "true"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# gp db
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db-gp
parameters:
  io_profile: "db_remote"
  repl: "1"
  secure: "true"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose for Databases, 2 Replicas - MongoDB - (Implemented application-level redundancy)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db-gp2-sc
parameters:
  priority_io: "high"
  io_profile: "db_remote"
  repl: "2"
  secure: "true"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# General Purpose for Databases, 3 Replicas
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db-gp3-sc
parameters:
  io_profile: "db_remote"
  repl: "3"
  secure: "true"
  priority_io: "high"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# DB2 RWX shared volumes for System Storage, backup storage, future load storage, and future diagnostic logs storage
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-rwx-sc
parameters:
  io_profile: cms
  block_size: 4096b
  repl: "3"
  secure: "true"
  sharedv4: "true"
  priority_io: high
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Db2 RWO volumes SC for user storage, future transaction logs storage, future archive/mirrors logs storage. This is also used for WKC DB2 Metastore
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-rwo-sc
parameters:
  block_size: 4096b
  io_profile: db_remote
  priority_io: high
  repl: "3"
  secure: "true"
  sharedv4: "false"
  disable_io_profile_protection: "1"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# WKC DB2 Metastore - SC portworx-db2-sc for upgrade purposes 
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-sc
parameters:
  io_profile: "db_remote"
  priority_io: high
  repl: "3"
  secure: "true"
  disable_io_profile_protection: "1"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# Watson Assitant - This was previously named portworx-assitant 
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-watson-assistant-sc
parameters:
   repl: "3"
   secure: "true"
   priority_io: "high"
   io_profile: "db_remote"
   block_size: "64k"
   disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# FCI DB2 Metastore
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
  io_profile: db_remote
  priority_io: high
  repl: "3"
  secure: "true"
  disable_io_profile_protection: "1"
EOF
}