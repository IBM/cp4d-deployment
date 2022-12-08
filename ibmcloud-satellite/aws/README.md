  

# Cloud Pak for Data on IBM Cloud Satellite locations using AWS Infrastructure

  This guide provides step-by-step instructions to install Cloud Pak for Data at IBM Cloud Satellite location using Amazon Web Services (AWS) Infrastructure.  The Red Hat® OpenShift® cluster deployed here uses Red Hat® OpenShift® Data Foundation—previously Red Hat OpenShift Container Storage—which is a software-defined storage for containers.

In order to deliver consistent experience across various form factors including Satellite locations, following capabilities have been certified by Cloud Pak for Data team on Cloud Pak for Data clusters deployed on IBM Cloud Satellite locations using AWS Infrastructure and ODF storage.

-   WKC
-   Watson Studio
-   Watson Query i.e Data Virtualization
-   Datastage
-   Db2
-   Db2 Warehouse
-   Cognos Analytics
-   Match 360 
-   Planning Analytics
-   Watson Discovery
-   Watson Assistant
  
  ## Steps to Deploy
  
  The following  are the steps to be followed to deploy 
  
1. [Creating a Satellite location in IBM Cloud using AWS infrastructure](#step-1-creating-a-satellite-location-in-ibm-cloud-using-aws-infrastructure)
2. [Create an OpenShift cluster at the location](#step-2-create-an-openshift-cluster-at-the-satellite-location)
3. [Configure storage](#step-3-configure-storage)
4. [Install Cloud Pak for Data](#step-4-install-cloud-pak-for-data)


## Prerequisites

Before you begin this process, you will need the following information:

- AWS Access key and secret ( AdministratorAccess policy is required for the IAM user who will be used for deploying the cluster.)

- Size of nodes to provision (CPU and RAM) (Minimum 16core\*64GB each node - md5.4xlarge)

- Every time we create satellite cluster by default 3 nodes are assigned to control plane and remaining will be worker nodes (minimum 3 worker nodes). Please refer to [Cloud Pak for data hardware requirements](https://www.ibm.com/docs/en/SSQNUZ_4.0/sys-reqs/hardware-reqs.html) to determine the number of master and worker nodes needed for the cluster.  Please ensure that you provision 3 additional nodes than the hardware requirements specified by the Cloud Pak for data requirements, as 3 nodes will be assigned to the IBM Cloud Satellite control plane.


## Step 1: Creating a Satellite location in IBM Cloud using AWS infrastructure



1. After logging on to [IBM Cloud](https://cloud.ibm.com/), from Menu, Select **Satellite** > **Locations** > **Create location**

When you select the **Amazon Web Services template** you will need to provide your AWS **access key ID** and **secret access key**.

  

![](images/satellite-templates.png)

  

![](images/satellite-aws-options.png)

  

**Size of nodes to provision (CPU and RAM)**

  

The minimum requirement is 16 CPU X 64GB memory for each worker node on a Cloud Pak for Data cluster.  So your EC2 instances should be configured in such a way to offer mentioned configuration. (for example m5d.4xlarge 16 cpu x 64GB)

  

![](images/aws-hardware-configuration.png)

  

**Note**: You do not need to create Object storage as we will configure storage later.

  

After you click Create, the EC2 Instances are provisioned for you on AWS. This can take a while and you’ll know the hosts are ready when the Satellite Location status is Normal. For reference you can always check the logs in workspace. ( Schematics -> Workspaces). 

![](images/satellite-location-status.png)

  
 

## Step 2: Create an OpenShift cluster at the satellite location

In the **Satellite > Cluster** page select **Create Cluster** then select **Satellite** as your infrastructure and then select your **Satellite Location**.

![](images/satellite-cluster-creation.png)

  

Under Worker Pools, you also need to select the size of the nodes for your cluster and which zone they reside in.When the cluster is provisioned, it will use the number of nodes you specified from each selected zone as worker nodes.Finally, click **Enable cluster admin access for Satellite Config** which ensures that all of the Satellite Config components will work, and then give your cluster a name.

  

![](images/cluster-admin-access-on-satellite.png)

  

The cluster is ready when it shows as Active in the **Openshift clusters** page.

![](images/satellite-cluster-status.png)

After the cluster is provisioned, in order to log in to the Openshift web console, you need to update the DNS and cluster subdomain. In AWS, open your EC2 instances and record the public and private IP addresses for each of the control plane and worker nodes.


![](images/cluster-config-public-login.png)

  

Then using those IP addresses run below commands.:

  

1.  Review the location subdomains and check the Records for the private IP addresses of the hosts that are registered in the DNS for the subdomain.
```
	ibmcloud sat location dns ls --location <location\_name\_or\_ID>
```
2.  Retrieve the matching public IP addresses of your hosts.
```
	ibmcloud sat host ls --location <location\_name\_or\_ID>
```

3.  Update the location subdomain DNS record with the public IP addresses of each host in the control plane.

```
	ibmcloud sat location dns register --location <location\_name\_or\_ID> --ip <host\_IP> --ip <host\_IP> --ip <host\_IP>
```

4.  Verify that the public IP addresses are registered with your location DNS record.

```
	ibmcloud sat location dns ls --location <location\_name\_or\_ID>
```

5.  Get the Hostname for your cluster and note the private IP(s) that were automatically registered

```
	ibmcloud oc nlb-dns ls --cluster <cluster\_name\_or\_ID>
```

6.  Add the public IP addresses of the hosts that are assigned as worker nodes to this cluster to your cluster's subdomain. Repeat this command for each host's public IP address.
```
	ibmcloud oc nlb-dns add --ip <public\_IP> --cluster <cluster\_name\_or\_ID> --nlb-host <hostname>
```
 
7.Remove the private IP addresses from your cluster's subdomain. Repeat this command for all private IP addresses that you retrieved earlier.
```
	ibmcloud oc nlb-dns rm classic --ip <private\_IP> --cluster <cluster\_name\_or\_ID> --nlb-host <hostname>
```

8.Verify that the public IP addresses are registered with your cluster subdomain.
```
	ibmcloud oc nlb-dns ls --cluster <cluster\_name\_or\_ID>
```

You have now successfully configured a Satellite Location in IBM Cloud using AWS infrastructure and deployed an OpenShift cluster, browse to your cluster in IBM Cloud, click on it, and then click OpenShift web console.

Please refer [Accessing clusters from the public network](https://cloud.ibm.com/docs/openshift?topic=openshift-access_cluster#sat_public_access) for more detailed information.

##  Step 3: Configure storage

For our OpenShift cluster on Satellite Locations, we use OpenShift Data Foundation with local disks. The installation for ODF is now automated via the IBM Cloud Console.
Please follow below steps to configure ODF storage.

- Under the Satellite select "Storage" then click on "Create storage configuration":
<img width="952" alt="image" src="https://media.github.ibm.com/user/362184/files/39d9539e-6cf4-4f74-b9a7-60350a65b833">

- Edit preferences to Create Storage Configuration and click "Next":
<img width="951" alt="image" src="https://media.github.ibm.com/user/362184/files/18454243-41fe-46a8-9515-7df48fc5ec4d">

- Choose parameters as follows then click "Next":
<img width="817" alt="image" src="https://media.github.ibm.com/user/362184/files/f14afec8-fa5c-48e4-842a-7ee0bed6b091">

- Enter IAM API Key for your IBM Cloud account then click "Next":
<img width="835" alt="image" src="https://media.github.ibm.com/user/362184/files/23f3fc3f-d375-44ef-bfd9-fa8bba600e61">

- Select the openshift storage to assign the ODF configuration to:
<img width="828" alt="image" src="https://media.github.ibm.com/user/362184/files/912f760b-9afa-4e2d-bd6f-2fa56c3d660c">

- Select the service you want this storage configuration assigned to.
<img width="879" alt="image" src="https://media.github.ibm.com/user/362184/files/7a8355a7-d4f3-43ce-b81e-4560d45ae3a6">

- Click on Complete and wait for 10-15 mins for the ODF configuration to be created on the openshift cluster.

```
	oc get csv -n openshift-storage
```
```
	oc get pods -n openshift-storage
```
The OCS cluster is also visible in the OpenShift web console. From the openshift-storage project, navigate to ** Operators > Installed Operators > OpenShift Container Storage **.

 ## Step 4: Install Cloud Pak for Data

  

Now that we have configured storage on our cluster on our satellite location, we can install Cloud Pak for Data on it. When installing Cloud Pak for Data on a Satellite cluster, you can use the same instructions to install the Cloud Pak for Data instance that you would use if your OpenShift cluster was running as a managed service in IBM Cloud. The only difference is how you update pull secrets on the cluster nodes.  For updating the pull secrets on the cluster nodes please follow the below instruction:

  

**Steps to configure global pull secret**

  

The Cloud Pak for Data resources such as pods are set up to pull from the IBM Entitled Registry. This registry is secured and can only be accessed with your entitlement key. In order to download the images for the pods, your entitlement key needs to be configured in the config.json file on each worker node.  To update the config.json file on each worker node, use a daemonset.

  

 First, you will need to create a secret with the entitlement key in the default namespace. You can get your entitlement key from <https://myibm.ibm.com/products-services/containerlibrary>.


```
oc create secret docker-registry docker-auth-secret \--docker-server=cp.icr.io \--docker-username=cp \--docker-password=<entitlement-key> \--namespace default```
```
  

Once the secret is created, you can use a daemonset to update your worker nodes. If you choose to use a daemonset make sure it's working on each node prior to starting the installation.

  

**NOTE**: Below is an example of a daemonset yaml that can accomplish updating the global pull secret on each of your worker nodes.

```
cat <<EOF |oc apply -f -
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
               echo "Sending signal to reload  crio config";
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
EOF

```
The daemonset schedules pod on every worker node and configures every worker node the ability to pull cloud pak for data images.


**Install Cloud Pak for Data:**

For installation of Cloud Pak for Data please refer to  [Installing  IBM Cloud Pak for Data](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.5.x?topic=installing)

-----------------------------------------------------------------------------
