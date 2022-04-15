
  

# Cloud Pak for Data on IBM Cloud Satellite locations using On-Prem Infrastructure

  

This guide provides step-by-step instructions to install Cloud Pak for Data at IBM Cloud Satellite location using On-Prem Infrastructure. The Red Hat® OpenShift® cluster deployed here uses Red Hat® OpenShift® Data Foundation—previously Red Hat OpenShift Container Storage—which is a software-defined storage for containers.

  

In order to deliver consistent experience across various form factors including Satellite locations, following capabilities have been certified by Cloud Pak for Data team on Cloud Pak for Data clusters deployed on IBM Cloud Satellite locations using On-Prem Infrastructure and ODF storage.

  

- WKC

- Watson Studio

- Watson Query i.e Data Virtualization

- Datastage

- Db2

- Db2 Warehouse

- Cognos Analytics

- Match 360

- Planning Analytics

- Watson Discovery

- Watson Assistant

## Steps to Deploy

The following are the steps to be followed to deploy:

1. [Create a satellite location](#1create-a-satellite-location)

2. [Provision host machines](#2-provision-host-machines)

3. [Update host machines](#3-update-the-host-machines)

4. [Assign hosts to Control Plane](#4-assign-the-control-plane-hosts-to-the-satellite-location)

5. [Assign hosts to OCP cluster](#5-assign-remaining-hosts-to-the-satellite-location-for-the-openshift-cluster)

6. [Install Red Hat Openshift](#6-create-openshift-cluster)

7. [Setup storage and install ODF](#7-install-openshift-data-foundation-odf-storage)

8. [Configuring OCP cluster pull secret](#8-configuring-your-cluster-pull-secret)

9. [Install Cloud Pak for Data](#9-install-cloud-pak-for-data)

  
  

### 1. Create a satellite location:

- Navigate to https://cloud.ibm.com/satellite/locations and click Create Location. Select On-premises & edge:

![image](images/satellite-locations-templates.png)


- Edit the name, location, and resource group as required:

![image](images/create-satellite-location.png)

  
  

- Generate and download the attach script after creating the location, this is to be run later on the on-premises VMs:


![image](images/generate-script.png)
  

### 2. Provision host machines 

Host System Requirements:

Please refer to [Host system requirements](https://cloud.ibm.com/docs/satellite?topic=satellite-host-reqs) for requirements that relate to the computing and system setup of host machines for IBM Cloud Satellite®.  Hosts can be physical or virtual machines and must run Red Hat Enterprise Linux 7 or the latest Red Hat CoreOS on x86 architecture with the kernel that is distributed with that version

Please refer to [Cloud Pak for data hardware requirements](https://www.ibm.com/docs/en/SSQNUZ_4.0/sys-reqs/hardware-reqs.html) to determine the number of master and worker nodes needed for the cluster. Please ensure that you provision 3 additional hosts than the hardware requirements specified by the Cloud Pak for data requirements, as 3 nodes will be assigned to the IBM Cloud Satellite control plane.


Storage:

You can use OpenShift Data Foundation (ODF) storage, which means that each host that is included in the ODF storage cluster must have at least two raw unformatted unmounted disks attached.  The minimum requirements are 100 GB for disk 1 and 500 GB for disk 2 for each host.

TIP: If you have the available quota, it can be useful to provision an extra host or two to have in case you need to add additional worker nodes to your cluster or if one of the nodes fail.

  

### 3. Update the host machines:

 
In addition, because the machines are provisioned on premises, you need to update them to work with IBM Cloud Satellite:

```

yum -y update

yum -y install ftp

yum -y install bind-utils

```

Register the hosts with Red Hat subscription manager:

```

ftp ftp3.linux.ibm.com

cd redhat

get ibm-rhsm.sh

bye

chmod +x ibm-rhsm.sh

./ibm-rhsm.sh --register

(enter your RedHat subscription user id and password)

```

To enable SELINUX on the VMs: run the following commands on each VM

```

grep -E "^SELINUX=" /etc/selinux/config

grep -E "^SELINUX=" /etc/sysconfig/selinux

sed -i 's/SELINUX=disabled/SELINUX=permissive/g' /etc/selinux/config

sed -i 's/SELINUX=disabled/SELINUX=permissive/g' /etc/sysconfig/selinux

grep -E "^SELINUX=" /etc/selinux/config

grep -E "^SELINUX=" /etc/sysconfig/selinux

reboot

```

Finally, you need to refresh the subscription manager. See the Satellite documentation for the full list of subscription-manager commands that you must run.

Login after the reboot and issue the following commands:

```

subscription-manager refresh

subscription-manager repos --enable rhel-server-rhscl-7-rpms

subscription-manager repos --enable rhel-7-server-optional-rpms

subscription-manager repos --enable rhel-7-server-rh-common-rpms

subscription-manager repos --enable rhel-7-server-supplementary-rpms

subscription-manager repos --enable rhel-7-server-extras-rpms

```

### 4. Assign the control plane hosts to the satellite location:

Copy the attach script that you downloaded in step one from the Satellite location to each VM , make it executable, and run it.

Then in the satellite location "Hosts" tab, use the action menu for three of the Hosts to assign the node to the control plane, each in a separate "zone".

![image](images/assign-host-to-control-plane.png)

### 5. Assign remaining hosts to the satellite location for the OpenShift cluster:

- Repeat steps 3 and 4 with the remaining VMs.

  

### 6. Create OpenShift cluster:

Important: Wait until the Satellite Location state becomes: **Normal**

![image](images/normal-status.png)
  

Before you create the OpenShift cluster.

Click Satellite > Locations > Getting started > Create cluster to create the OpenShift cluster, selecting Satellite as the Infrastructure, and selecting your Location.

![image](images/create-cluster.png)
  

In the **Default work pool**, select the CPU and Memory sizes that are less than or equal to the VMs you provisioned (i.e. don't select sizes that are bigger than the nodes available). Select the number of VMs to include as worker nodes in your cluster and select to **Enable cluster admin access**.

![image](images/default-worker-pool.png)
  

Note: After the nodes are assigned to the Location, either as a control plane or worker node, you can no longer ssh into them from your Terminal window. You can however access them the OpenShift console under Compute > Nodes > <node> > Terminal or log into the IBM Cloud CLI and use the oc debug node/<node-name> command.

  

### 7. Install Openshift Data Foundation (ODF) Storage:

Every Cloud Pak requires storage, and for our OpenShift cluster on Satellite Locations, we use OpenShift Data Foundation with local disks. In step two above, you configured your VMs with two additional raw unformatted disks that will be used by ODF.

Follow instructions in the Satellite documentation .

- The two optional steps titled **Setting up an IBM Cloud Object Storage backing store** and **Getting the device details for your ODF configuration** are not required.

- We performed the steps under **Creating an OpenShift Data Foundation configuration** in the command line and Assigning your ODF storage configuration to a cluster.

  

**Essentially you will create an ODF storage configuration using the following command syntax:**

1. Log in to the IBM Cloud CLI.

```

ibmcloud login

```

2. List your Satellite locations and note the Managed from column.

```

ibmcloud sat location ls

```

3. Target the Managed from region of your Satellite location. For example, for wdc target us-east. For more information, see Satellite regions.

```

ibmcloud target -r us-east

```

4. If you use a resource group other than default, target it.

```

ibmcloud target -g <resource-group>

```

5. List the available templates and versions and review the output. Make a note of the template and version that you want to use. Your storage template version and cluster version must match.

```

ibmcloud sat storage template ls

```

6. Get the template parameters for your cluster version.

```

ibmcloud sat storage template get --name odf-local --version <version>

```

7. Run the following command to create the storage config. You will need your IBM Cloud IAM API Key.

```

ibmcloud sat storage config create --name odf-local-auto --template-name odf-local --template-version 4.8 --location odf-sat-stage-location -p "ocs-cluster-name=ocscluster-auto" -p "auto-discover-devices=true" -p "iam-api-key=<api-key>"

```

**Assigning your ODF storage configuration to a cluster:**

1. List your Satellite storage configurations and make a note of the storage configuration that you want to assign to your clusters.

```

ibmcloud sat storage config ls

```

2. Get the ID of the cluster or cluster group that you want to assign storage to. To make sure that your cluster is registered with Satellite Config or to create groups, see Setting up clusters to use with Satellite Config.

  

- Group

```

ibmcloud sat group ls

```

- Cluster

```

ibmcloud oc cluster ls --provider satellite

```

- Satellite-enabled IBM Cloud service cluster

```

ibmcloud sat service ls --location <location>

```

3. Assign storage to the cluster or group that you retrieved in step 2. Replace <group> with the ID of your cluster group or <cluster> with the ID of your cluster. Replace <config> with the name of your storage config, and <name> with a name for your storage assignment. For more information, see the ibmcloud sat storage assignment create command.

- Group

```

ibmcloud sat storage assignment create --group <group> --config <config> --name <name>

```

- Cluster

```

ibmcloud sat storage assignment create --cluster <cluster> --config <config> --name <name>

```

- Satellite-enabled IBM Cloud service cluster

```

ibmcloud sat storage assignment create --service-cluster-id <cluster> --config <config> --name <name>

```

4. Verify that your assignment is created.

```

ibmcloud sat storage assignment ls (--cluster <cluster_id> | --service-cluster-id <cluster_id>) | grep <storage-assignment-name>

```

5. Verify that the storage configuration resources are deployed. Note that this process might take up to 10 minutes to complete.

- Get the storagecluster that you deployed and verify that the phase is Ready.

```

oc get storagecluster -n openshift-storage

```

Example output

```

NAME AGE PHASE EXTERNAL CREATED AT VERSION

ocs-storagecluster 72m Ready 2021-02-10T06:00:20Z 4.6.0

```

- Get a list of pods in the openshift-storage namespace and verify that the status is Running.

```

oc get pods -n openshift-storage

```

Example output

```

NAME READY STATUS RESTARTS AGE

csi-cephfsplugin-9g2d5 3/3 Running 0 8m11s

csi-cephfsplugin-g42wv 3/3 Running 0 8m11s

csi-cephfsplugin-provisioner-7b89766c86-l68sr 5/5 Running 0 8m10s

csi-cephfsplugin-provisioner-7b89766c86-nkmkf 5/5 Running 0 8m10s

csi-cephfsplugin-rlhzv 3/3 Running 0 8m11s

csi-rbdplugin-8dmxc 3/3 Running 0 8m12s

csi-rbdplugin-f8c4c 3/3 Running 0 8m12s

csi-rbdplugin-nkzcd 3/3 Running 0 8m12s

csi-rbdplugin-provisioner-75596f49bd-7mk5g 5/5 Running 0 8m12s

csi-rbdplugin-provisioner-75596f49bd-r2p6g 5/5 Running 0 8m12s

noobaa-core-0 1/1 Running 0 4m37s

noobaa-db-0 1/1 Running 0 4m37s

noobaa-endpoint-7d959fd6fb-dr5x4 1/1 Running 0 2m27s

noobaa-operator-6cbf8c484c-fpwtt 1/1 Running 0 9m41s

ocs-operator-9d6457dff-c4xhh 1/1 Running 0 9m42s

rook-ceph-crashcollector-169.48.170.83-89f6d7dfb-gsglz 1/1 Running 0 5m38s

rook-ceph-crashcollector-169.48.170.88-6f58d6489-b9j49 1/1 Running 0 5m29s

rook-ceph-crashcollector-169.48.170.90-866b9d444d-zk6ft 1/1 Running 0 5m15s

rook-ceph-drain-canary-169.48.170.83-6b885b94db-wvptz 1/1 Running 0 4m41s

rook-ceph-drain-canary-169.48.170.88-769f8b6b7-mtm47 1/1 Running 0 4m39s

rook-ceph-drain-canary-169.48.170.90-84845c98d4-pxpqs 1/1 Running 0 4m40s

rook-ceph-mds-ocs-storagecluster-cephfilesystem-a-6dfbb4fcnqv9g 1/1 Running 0 4m16s

rook-ceph-mds-ocs-storagecluster-cephfilesystem-b-cbc56b8btjhrt 1/1 Running 0 4m15s

rook-ceph-mgr-a-55cc8d96cc-vm5dr 1/1 Running 0 4m55s

rook-ceph-mon-a-5dcc4d9446-4ff5x 1/1 Running 0 5m38s

rook-ceph-mon-b-64dc44f954-w24gs 1/1 Running 0 5m30s

rook-ceph-mon-c-86d4fb86-s8gdz 1/1 Running 0 5m15s

rook-ceph-operator-69c46db9d4-tqdpt 1/1 Running 0 9m42s

rook-ceph-osd-0-6c6cc87d58-79m5z 1/1 Running 0 4m42s

rook-ceph-osd-1-f4cc9c864-fmwgd 1/1 Running 0 4m41s

rook-ceph-osd-2-dd4968b75-lzc6x 1/1 Running 0 4m40s

rook-ceph-osd-prepare-ocs-deviceset-0-data-0-29jgc-kzpgr 0/1 Completed 0 4m51s

rook-ceph-osd-prepare-ocs-deviceset-1-data-0-ckvv2-4jdx5 0/1 Completed 0 4m50s

rook-ceph-osd-prepare-ocs-deviceset-2-data-0-szmjd-49dd4 0/1 Completed 0 4m50s

rook-ceph-rgw-ocs-storagecluster-cephobjectstore-a-7f7f6df9rv6h 1/1 Running 0 3m44s

rook-ceph-rgw-ocs-storagecluster-cephobjectstore-b-554fd9dz6dm8 1/1 Running 0 3m41s

```

- List the ODF storage classes.

```

oc get sc

```

Example output

```

NAME PROVISIONER RECLAIMPOLICY VOLUMEBINDINGMODE ALLOWVOLUMEEXPANSION AGE

localblock kubernetes.io/no-provisioner Delete WaitForFirstConsumer false 107s

localfile kubernetes.io/no-provisioner Delete WaitForFirstConsumer false 107s

ocs-storagecluster-ceph-rbd openshift-storage.rbd.csi.ceph.com Delete Immediate true 87s

ocs-storagecluster-ceph-rgw openshift-storage.ceph.rook.io/bucket Delete Immediate false 87s

ocs-storagecluster-cephfs openshift-storage.cephfs.csi.ceph.com Delete Immediate true 88s

sat-ocs-cephfs-gold openshift-storage.cephfs.csi.ceph.com Delete Immediate true 2m46s

sat-ocs-cephrbd-gold openshift-storage.rbd.csi.ceph.com Delete Immediate true 2m46s

sat-ocs-cephrgw-gold openshift-storage.ceph.rook.io/bucket Delete Immediate false 2m45s

sat-ocs-noobaa-gold openshift-storage.noobaa.io/obc Delete Immediate false 2m45s

```

- List the persistent volumes and verify that your MON and OSD volumes are created.

```

oc get pv

```

Example output

```

NAME CAPACITY ACCESS MODES RECLAIM POLICY STATUS CLAIM STORAGECLASS REASON AGE

local-pv-180cfc58 139Gi RWO Delete Bound openshift-storage/rook-ceph-mon-b localfile 12m

local-pv-67f21982 139Gi RWO Delete Bound openshift-storage/rook-ceph-mon-a localfile 12m

local-pv-80c5166 100Gi RWO Delete Bound openshift-storage/ocs-deviceset-2-data-0-5p6hd localblock 12m

local-pv-9b049705 139Gi RWO Delete Bound openshift-storage/rook-ceph-mon-c localfile 12m

local-pv-b09e0279 100Gi RWO Delete Bound openshift-storage/ocs-deviceset-1-data-0-gcq88 localblock 12m

local-pv-f798e570 100Gi RWO Delete Bound openshift-storage/ocs-deviceset-0-data-0-6fgp6 localblock 12m

```

### 8. Configuring your cluster pull secret:

  

The Cloud Pak for Data resources such as pods are set up to pull from the IBM Entitled Registry. This registry is secured and can only be accessed with your entitlement key. In order to download the images for the pods, your entitlement key needs to be configured in the config.json file on each worker node. To update the config.json file on each worker node, use a daemonset.

First, you will need to create a secret with the entitlement key in the default namespace. You can get your entitlement key from https://myibm.ibm.com/products-services/containerlibrary.

Here’s the link to configure pull secret:

https://www.ibm.com/docs/en/cloud-paks/cp-data/4.0?topic=tasks-configuring-your-cluster-pull-images

```

oc create secret docker-registry docker-auth-secret \--docker-server=cp.icr.io \--docker-username=cp \--docker-password=<entitlement-key>  \--namespace default

```

Once the secret is created, you can use a daemonset to update your worker nodes. If you choose to use a daemonset make sure it's working on each node prior to starting the installation.

  

NOTE: Below is an example of a daemonset yaml that can accomplish updating the global pull secret on each of your worker nodes.

```

apiVersion: apps/v1

kind: DaemonSet

metadata:

name: update-docker-config

labels:

app: update-docker-config

spec:

selector:

matchLabels:

name: update-docker-config

template:

metadata:

labels:

name: update-docker-config

spec:

initContainers:

- command: ["/bin/sh", "-c"]

args:

- >

echo "Backing up or restoring config.json";

[[ -s /docker-config/config.json ]] && cp /docker-config/config.json /docker-config/config.json.bak || cp /docker-config/config.json.bak /docker-config/config.json;

echo "Merging secret with config.json";

/host/usr/bin/jq -s '.[0] * .[1]' /docker-config/config.json /auth/.dockerconfigjson > /docker-config/config.tmp;

mv /docker-config/config.tmp /docker-config/config.json;

echo "Sending signal to reload crio config";

pidof crio;

kill -1 $(pidof crio)

image: icr.io/ibm/alpine:latest

imagePullPolicy: IfNotPresent

name: updater

resources: {}

securityContext:

privileged: true

volumeMounts:

- name: docker-auth-secret

mountPath: /auth

- name: docker

mountPath: /docker-config

- name: bin

mountPath: /host/usr/bin

- name: lib64

mountPath: /lib64

containers:

- resources:

requests:

cpu: 0.01

image: icr.io/ibm/alpine:latest

name: sleepforever

command: ["/bin/sh", "-c"]

args:

- >

while true; do

sleep 100000;

done

hostPID: true

volumes:

- name: docker-auth-secret

secret:

secretName: docker-auth-secret

- name: docker

hostPath:

path: /.docker

- name: bin

hostPath:

path: /usr/bin

- name: lib64

hostPath:

path: /lib64

hostPathType: Directory

```

### 9. Install Cloud Pak for Data:

To install Cloud Pak for Data starting from Setting Up Projects, follow the steps in the following link

https://www.ibm.com/docs/en/cloud-paks/cp-data/4.0?topic=tasks-setting-up-projects-namespaces

  

NOTE: At the step where you have to install IBM Cloud Pak foundational services, make sure to create an operator group

Here’s an example:

```

apiVersion: operators.coreos.com/v1

kind: OperatorGroup

metadata:

name: operatorgroup

namespace: ibm-common-services

spec:

targetNamespaces:

- ibm-common-services

```