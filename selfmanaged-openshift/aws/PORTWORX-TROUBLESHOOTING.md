## Troubleshooting issues with Cloud Pak for Data installation on Portworx storage on AWS

Some of the services may encounter issues when installing Cloud Pak for Data on Portworx storage on AWS.  Please use the following troubleshooting help in case of any issues encountered with the following services.

## Db2 Data Management Console

Db2 Data Management Console service does not start in Liberty on AWS cluster with Portworx storage. The Db2 Data Management Console service pod fails to run successfully. As a workaround, use the following Db2 Data Management Console CR to create the service instance instead of provisioning the service instance from UI.  Ensure that  `disable_storage` is set to  `true`  in the CR specification.

```plaintext
cat << EOF | oc apply -f -
apiVersion: dmc.databases.ibm.com/v1
kind: Dmc
metadata:
  name: data-management-console
  annotations:
    ansible.operator-sdk/reconcile-period: "30s"
    ansible.sdk.operatorframework.io/verbosity: "4"  
spec:
  arch: x86_64
  version: 4.0.1
  description: "Data Management Console"
  scaleConfig: small
  storageClass: "YOUR_STORAGECLASS"
  storageSize: 10Gi   
  disable_storage: true
  license:
    accept: true 
    license: Standard   
EOF
```
More details at  [Limitations and known issues in Db2 Data Management Console](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.0?topic=issues-db2-data-management-console)


## Match 360 with Watson

The following steps should be considered when deploying on single zone AWS cluster with Portworx storage if the Elastic Search pods are not in running state.

Set the same values for requests and limits for ElasticSearch.
```
 master:
   resources:
     requests:
       cpu: "1"
       memory: "1Gi"
     limits:
       cpu: "1"
       memory: "1Gi"
 data:
   resources:
     requests:
       cpu: "1"
       memory: "3Gi"
     limits:
       cpu: "1"
       memory: "3Gi"
```
Don't specify storage class field in mdm-cr and should have only storage vendor field defined.
```
    persistence:
      storage_vendor: portworx 
```
Example CR:

```
cat <<EOF |oc apply -f -
apiVersion: mdm.cpd.ibm.com/v1
kind: MasterDataManagement
metadata:
  name: mdm-cr     # This is the recommended name, but you can change it
  namespace: zen    # Replace with the project where you will install IBM Match 360 with Watson
spec:
  license:
    accept: true
    license: Enterprise      # Specify the license you purchased
  version: 1.1.167
  persistence:
    storage_vendor: portworx    # Specify the storage vendor (ocs | portworx)
  common_core_services:
    enabled: true
  elasticsearch:
    master:
      resources:
        requests:
          cpu: "1"
          memory: "1Gi"
        limits:
          cpu: "1"
          memory: "1Gi"
    data:
      resources:
        requests:
          cpu: "1"
          memory: "3Gi"
        limits:
          cpu: "1"
          memory: "3Gi"
EOF
```

When ElasticSearchCluster got created during installation, edit the ES cr and enable sidecar by adding the following specs.
```
    spec:
      storageCheckSidecar:
        enabled: true
```
Edit it and enable sidecar.
```
	oc get elasticsearchcluster
```
This should resolve the issue and get the elastic search pods to running state.


## Watson Machine Learning

After the fresh installation of Watson Machine Learning of CP4D 4.0.X version (before CP4D 4.0.6) on AWS, if you observe that one of the ETCD pods is getting restarted continuously as shown below.

```
wml-deployments-etcd-0     1/1     Running            143        16h
wml-deployments-etcd-1     1/1     Running            0          16h
wml-deployments-etcd-2     1/1     Running            0          16h
```

Only then you need to follow the below workaround steps to bring up the ETCD pods:

1.  Extract the statefulset `wml-deployments-etcd` in a yaml file

```
	oc get statefulset wml-deployments-etcd -o yaml > wml-deployments-etcd.yaml
```

2.  Execute the following commands to update the yaml file

```
	sed 's/etcdctl endpoint health/etcdctl endpoint health --user=root:$ROOT_PASSWORD/g' wml-deployments-etcd.yaml > wml-deployments-etcd-temp1.yaml
	sed 's/etcdctl member update/etcdctl member update --user=root:$ROOT_PASSWORD/g' wml-deployments-etcd-temp1.yaml > wml-deployments-etcd-temp2.yaml
	sed 's/etcdctl member add/etcdctl member add --user=root:$ROOT_PASSWORD/g' wml-deployments-etcd-temp2.yaml > wml-deployments-etcd-temp3.yaml

```

3.  Delete the existing wml etcd statefulset

```
	oc delete -f wml-deployments-etcd.yaml
```

4.  Wait for existing ETCD pods to get terminated

```
	oc get pods | grep -i "wml-deployments-etcd"
```

5.  Remove the wml deployment ETCD PVC and PV:

```
	oc delete pvc data-wml-deployments-etcd-0 data-wml-deployments-etcd-1 data-wml-deployments-etcd-2	
	oc get pv| grep -i "data-wml-deployments-etcd" | awk '{print $1}' | xargs oc delete pv
```

6.  Making the following changes in the file "wml-deployments-etcd-temp4.yaml":

	6(a). Remove the "metadata.creationTimestamp", "metadata.resourceVersion" and "metadata.uid" from the yaml file -  `wml-deployments-etcd-temp3.yaml`

```
metadata:
  ....
  creationTimestamp: "2022-01-31T11:24:32Z"    -------> Remove this line
  resourceVersion: "8864069"                   -------> Remove this line 
  uid: 0227fa19-1d07-45f7-82cb-734864376482	   -------> Remove this line 
```

6(b). Remove the complete "status" section from the yaml file -  wml-deployments-etcd-temp3.yaml

```
    status:
      phase: Pending
status:
  collisionCount: 0
  currentReplicas: 3
  currentRevision: wml-deployments-etcd-545567cbbb
  observedGeneration: 1
  readyReplicas: 3
  replicas: 3
  updateRevision: wml-deployments-etcd-545567cbbb
  updatedReplicas: 3
```

7.  Recreate the etcd statefulset
```
	oc create -f wml-deployments-etcd-temp3.yaml
```

## Watson OpenScale


Sometimes when installing Watson OpenScale using Portworx storage on AWS, some of the pods fails to start.  This is caused sometimes due to slow I/O operations on Portworx storage on AWS.  This is observed when the  `portworx-shared-gp3` storage class is used for persistent volumes requiring both RWO and RWX access modes.  Starting Cloud Pak for Data version 4.0.4, OpenScale has introduced a custom storage class to be specified for volumes needing RWO access mode with a CR parameter by name `rwoStorageClass`.   Use the following CR specification to install OpenScale service to fix the issue.

```
cat <<EOF |oc apply -f -
apiVersion: wos.cpd.ibm.com/v1
kind: WOService
metadata:
  name: aiopenscale
  namespace: zen
spec:
  scaleConfig: small
  license:
    accept: true
    license: Enterprise
  version: 4.0.4
  type: service
  storageClass: portworx-shared-gp3
  rwoStorageClass: portworx-metastoredb-sc
EOF
```









