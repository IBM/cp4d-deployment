#!/bin/bash

set -x

export SUDOUSER=$1
export OPENSHIFTUSER=$2
export OPENSHIFTPASSWORD=$3
export CLUSTERNAME=$4
export DOMAINNAME=$5
export REGION=$6
export CUSTOMDOMAIN=$7
export RESOURCEGROUPNAME=$9
export VNETNAME=${10}
export WORKERSUBNETNAME=${11}

export MULTIZONE1=1
export MULTIZONE2=2
export MULTIZONE3=3

export OCSTEMPLATES=/home/$SUDOUSER/.openshift/ocs/templates
runuser -l $SUDOUSER -c "mkdir -p $OCSTEMPLATES"

runuser -l $SUDOUSER -c "cat > $OCSTEMPLATES/toolbox.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rook-ceph-tools
  namespace: openshift-storage
  labels:
    app: rook-ceph-tools
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rook-ceph-tools
  template:
    metadata:
      labels:
        app: rook-ceph-tools
    spec:
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: rook-ceph-tools
        image: rook/ceph:v1.1.9
        command: [\"/tini\"]
        args: [\"-g\", \"--\", \"/usr/local/bin/toolbox.sh\"]
        imagePullPolicy: IfNotPresent
        env:
          - name: ROOK_ADMIN_SECRET
            valueFrom:
              secretKeyRef:
                name: rook-ceph-mon
                key: admin-secret
        securityContext:
          privileged: true
        volumeMounts:
          - mountPath: /dev
            name: dev
          - mountPath: /sys/bus
            name: sysbus
          - mountPath: /lib/modules
            name: libmodules
          - name: mon-endpoint-volume
            mountPath: /etc/rook
      hostNetwork: true
      volumes:
        - name: dev
          hostPath:
            path: /dev
        - name: sysbus
          hostPath:
            path: /sys/bus
        - name: libmodules
          hostPath:
            path: /lib/modules
        - name: mon-endpoint-volume
          configMap:
            name: rook-ceph-mon-endpoints
            items:
            - key: data
              path: mon-endpoints
EOF"

runuser -l $SUDOUSER -c "cat > $OCSTEMPLATES/ocs-olm.yaml <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    openshift.io/cluster-monitoring: \"true\"
  name: openshift-storage
spec: {}
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-storage-operatorgroup
  namespace: openshift-storage
spec:
  targetNamespaces:
  - openshift-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ocs-operator
  namespace: openshift-storage
  labels:
    operators.coreos.com/ocs-operator.openshift-storage: ''
spec:
  channel: stable-4.10
  installPlanApproval: Automatic
  name: ocs-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF"

runuser -l $SUDOUSER -c "cat > $OCSTEMPLATES/ocs-storagecluster.yaml <<EOF
apiVersion: ocs.openshift.io/v1
kind: StorageCluster
metadata:
  name: ocs-storagecluster
  namespace: openshift-storage
  finalizers:
    - storagecluster.ocs.openshift.io
spec:
  encryption:
    enable: true
  externalStorage: {}
  managedResources:
    cephBlockPools: {}
    cephFilesystems: {}
    cephObjectStoreUsers: {}
    cephObjectStores: {}
  storageDeviceSets:
    - config: {}
      count: 1
      dataPVCTemplate:
        metadata:
          creationTimestamp: null
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Ti
          storageClassName: managed-premium
          volumeMode: Block
        status: {}
      name: ocs-deviceset
      placement: {}
      portable: true
      replica: 3
      resources: {}
  version: 4.10.0
EOF"

runuser -l $SUDOUSER -c "cat > $OCSTEMPLATES/ocs-machineset-multizone.yaml <<EOF
---
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  labels:
    machine.openshift.io/cluster-api-cluster: CLUSTERID
  name: CLUSTERID-workerocs-$REGION$MULTIZONE1
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: CLUSTERID
      machine.openshift.io/cluster-api-machineset: CLUSTERID-workerocs-$REGION$MULTIZONE1
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: CLUSTERID
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: CLUSTERID-workerocs-$REGION$MULTIZONE1
    spec:
      taints:
      - effect: NoSchedule
        key: node.ocs.openshift.io/storage
        value: \"true\"
      metadata:
        labels:
          cluster.ocs.openshift.io/openshift-storage: \"\"
          node-role.kubernetes.io/infra: \"\"
          node-role.kubernetes.io/worker: \"\"
          role: storage-node
      providerSpec:
        value:
          apiVersion: azureproviderconfig.openshift.io/v1beta1
          credentialsSecret:
            name: azure-cloud-credentials
            namespace: openshift-machine-api
          image:
            offer: aro4
            publisher: azureopenshift
            resourceID: ""
            sku: aro_48
            version: 48.84.20210630
          kind: AzureMachineProviderSpec
          location: $REGION
          metadata:
            creationTimestamp: null
          networkResourceGroup: $RESOURCEGROUPNAME
          osDisk:
            diskSizeGB: 512
            managedDisk:
              storageAccountType: Premium_LRS
            osType: Linux
          publicIP: false
          publicLoadBalancer: CLUSTERID
          resourceGroup: aro-$CLUSTERNAME
          subnet: $WORKERSUBNETNAME
          userDataSecret:
            name: worker-user-data
          vmSize: Standard_D16s_v3
          vnet: $VNETNAME
          zone: \"1\"
---
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  labels:
    machine.openshift.io/cluster-api-cluster: CLUSTERID
  name: CLUSTERID-workerocs-$REGION$MULTIZONE2
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: CLUSTERID
      machine.openshift.io/cluster-api-machineset: CLUSTERID-workerocs-$REGION$MULTIZONE2
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: CLUSTERID
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: CLUSTERID-workerocs-$REGION$MULTIZONE2
    spec:
      taints:
      - effect: NoSchedule
        key: node.ocs.openshift.io/storage
        value: \"true\"
      metadata:
        labels:
          cluster.ocs.openshift.io/openshift-storage: \"\"
          node-role.kubernetes.io/infra: \"\"
          node-role.kubernetes.io/worker: \"\"
          role: storage-node
      providerSpec:
        value:
          apiVersion: azureproviderconfig.openshift.io/v1beta1
          credentialsSecret:
            name: azure-cloud-credentials
            namespace: openshift-machine-api
          image:
            offer: aro4
            publisher: azureopenshift
            resourceID: ""
            sku: aro_48
            version: 48.84.20210630
          kind: AzureMachineProviderSpec
          location: $REGION
          metadata:
            creationTimestamp: null
          networkResourceGroup: $RESOURCEGROUPNAME
          osDisk:
            diskSizeGB: 512
            managedDisk:
              storageAccountType: Premium_LRS
            osType: Linux
          publicIP: false
          publicLoadBalancer: CLUSTERID
          resourceGroup: aro-$CLUSTERNAME
          subnet: $WORKERSUBNETNAME
          userDataSecret:
            name: worker-user-data
          vmSize: Standard_D16s_v3
          vnet: $VNETNAME
          zone: \"2\"
---
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  labels:
    machine.openshift.io/cluster-api-cluster: CLUSTERID
  name: CLUSTERID-workerocs-$REGION$MULTIZONE3
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: CLUSTERID
      machine.openshift.io/cluster-api-machineset: CLUSTERID-workerocs-$REGION$MULTIZONE3
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: CLUSTERID
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: CLUSTERID-workerocs-$REGION$MULTIZONE3
    spec:
      taints:
      - effect: NoSchedule
        key: node.ocs.openshift.io/storage
        value: \"true\"
      metadata:
        labels:
          cluster.ocs.openshift.io/openshift-storage: \"\"
          node-role.kubernetes.io/infra: \"\"
          node-role.kubernetes.io/worker: \"\"
          role: storage-node
      providerSpec:
        value:
          apiVersion: azureproviderconfig.openshift.io/v1beta1
          credentialsSecret:
            name: azure-cloud-credentials
            namespace: openshift-machine-api
          image:
            offer: aro4
            publisher: azureopenshift
            resourceID: ""
            sku: aro_48
            version: 48.84.20210630
          kind: AzureMachineProviderSpec
          location: $REGION
          metadata:
            creationTimestamp: null
          networkResourceGroup: $RESOURCEGROUPNAME
          osDisk:
            diskSizeGB: 512
            managedDisk:
              storageAccountType: Premium_LRS
            osType: Linux
          publicIP: false
          publicLoadBalancer: CLUSTERID
          resourceGroup: aro-$CLUSTERNAME
          subnet: $WORKERSUBNETNAME
          userDataSecret:
            name: worker-user-data
          vmSize: Standard_D16s_v3
          vnet: $VNETNAME
          zone: \"3\"
EOF"

# Set url
if [[ $CUSTOMDOMAIN == "true" || $CUSTOMDOMAIN == "True" ]];then
export SUBURL="${CLUSTERNAME}.${DOMAINNAME}"
else
export SUBURL="${DOMAINNAME}.${REGION}.aroapp.io"
fi

#Login
var=1
while [ $var -ne 0 ]; do
echo "Attempting to login $OPENSHIFTUSER to https://api.${SUBURL}:6443"
oc login "https://api.${SUBURL}:6443" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true
var=$?
echo "exit code: $var"
done

#OCS Operator will install its components only on nodes labelled for OCS with the key
OCS_NODE_1=$(oc get nodes --show-labels | grep node-role.kubernetes.io/worker= | grep topology.kubernetes.io/zone=${REGION}-1 | head -n 1 | cut -d' ' -f1)
oc label node $OCS_NODE_1 cluster.ocs.openshift.io/openshift-storage=''
oc adm taint node $OCS_NODE_1 node.ocs.openshift.io/storage=true:NoSchedule
OCS_NODE_2=$(oc get nodes --show-labels | grep node-role.kubernetes.io/worker= | grep topology.kubernetes.io/zone=${REGION}-2 | head -n 1 | cut -d' ' -f1)
oc label node $OCS_NODE_2 cluster.ocs.openshift.io/openshift-storage=''
oc adm taint node $OCS_NODE_2 node.ocs.openshift.io/storage=true:NoSchedule
OCS_NODE_3=$(oc get nodes --show-labels | grep node-role.kubernetes.io/worker= | grep topology.kubernetes.io/zone=${REGION}-3 | head -n 1 | cut -d' ' -f1)
oc label node $OCS_NODE_3 cluster.ocs.openshift.io/openshift-storage=''
oc adm taint node $OCS_NODE_3 node.ocs.openshift.io/storage=true:NoSchedule
#done

runuser -l $SUDOUSER -c "oc login https://api.${SUBURL}:6443 -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true"

CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')
#runuser -l $SUDOUSER -c "sed -i -e s/CLUSTERID/$CLUSTERID/g $OCSTEMPLATES/ocs-machineset-multizone.yaml"
#runuser -l $SUDOUSER -c "oc create -f $OCSTEMPLATES/ocs-machineset-multizone.yaml"
#runuser -l $SUDOUSER -c "echo sleeping for 10mins until the node comes up"
#runuser -l $SUDOUSER -c "sleep 600"

runuser -l $SUDOUSER -c "oc create -f $OCSTEMPLATES/ocs-olm.yaml"
runuser -l $SUDOUSER -c "echo sleeping for 5mins"
runuser -l $SUDOUSER -c "sleep 300"
runuser -l $SUDOUSER -c "oc apply -f $OCSTEMPLATES/ocs-storagecluster.yaml"
runuser -l $SUDOUSER -c "echo sleeping for 10mins"
runuser -l $SUDOUSER -c "sleep 600"
runuser -l $SUDOUSER -c "oc apply -f $OCSTEMPLATES/toolbox.yaml"
runuser -l $SUDOUSER -c "echo sleeping for 1min"
runuser -l $SUDOUSER -c "sleep 60"

echo $(date) " - ############## Script Complete ####################"