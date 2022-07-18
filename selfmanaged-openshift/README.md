# Cloud Pak for Data 4.5 on AWS and Azure

Cloud Pak for Data is an end to end platform that helps organizations in their journey to AI. It enables data engineers, data stewards, data scientists, and business analysts to collaborate using an integrated multiple-cloud platform.
Cloud Pak for Data uses IBM’s deep analytics portfolio to help organizations meet data and analytics challenges. The required building blocks (collect, organize, analyze, infuse) for information architecture are available using Cloud Pak for Data on Azure.

Cloud Pak for Data uses cloud native services and features including VNets, VPCs, Availability Zones, security groups, Managed Disks, and Load Balancers to build a highly available, reliable, and scalable cloud platform.

This deployment guide provides step-by-step instructions for deploying IBM Cloud Pak for Data on a Red Hat OpenShift Container Platform 4.10 cluster on Amazon Web Services(AWS) and Azure.

This reference deployment provides Terraform scripts to deploy Cloud Pak for Data on a new Red Hat OpenShift Container Platform 4.10 cluster on AWS and Azure. This cluster includes:

 - A Red Hat OpenShift Container Platform cluster created in a new or existing VPC on Red Hat CoreOS (RHCOS) instances, using the [Red Hat OpenShift Installer Provisioned Infrastructure](https://docs.openshift.com/container-platform/4.10/architecture/architecture-installation.html).
 - A highly available storage infrastructure with Portworx or OpenShift Data Foundation (ODF). You also have the option to select Network File System(NFS) for Azure,  or Elastic File System(EFS) and Elastic Block Store(EBS) on AWS.
 - Scalable OpenShift compute nodes running Cloud Pak for Data services. See [Services](#cloud-pak-for-data-services) for the services that are enabled in this deployment.


## Cost and licenses

The deployment module includes configuration parameters that you can customize. See AWS and Azure deployment topology for more details. Some of these parameters, such as instance type and count, will affect the cost of deployment. For cost estimates, see the pricing page for each AWS and Azure service you will be using. Prices are subject to change.
This deployment requires a Red Hat OpenShift subscription and a Cloud Pak for Data subscription. You can obtain a 60-day trial license. See the [prerequisites](#prerequisites) section.

## Prerequisites

### Step 1. Sign up for a Red Hat Subscription

This deployment requires a Red Hat subscription.  You’ll need to provide your [OpenShift Installer Provisioned Infrastructure pull secret](https://cloud.redhat.com/openshift/install).

If you don’t have a Red Hat account, you can register on the Red Hat website. (Note that registration may require a non-personal email address). To procure a 60-day evaluation license for OpenShift, follow the instructions at [Evaluate Red Hat OpenShift Container Platform](https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it).
The OpenShift pull secret should be downloaded and the file location be made available to Terraform script parameters.

### Step 2. Cloud Pak for Data Subscription

You will need to have a Cloud Pak for Data entitlement API key to download images from the IBM entitled Cloud Pak registry. If you don't have a paid entitlement, you can create a [60 day trial subscription key](https://www.ibm.com/account/reg/us-en/signup?formid=urx-42212).  Note: After 60 days contact [IBM Cloud Pak for Data sales](https://www.ibm.com/account/reg/us-en/signup?formid=MAIL-cloud).

### Step 3. Storage Subscription

You can select one of the two container storages while installing this Quickstart. 

Note: You also have the option to select NFS for Azure or EFS and EBS for AWS in which case there is no additional storage subscription required. 

####	Portworx

When you select [Portworx](https://portworx.com/products/features/) as the persistent storage layer, you will need to specify the install spec from your [Portworx account](https://central.portworx.com/specGen/list). You can generate a new spec using the [Spec Generator](https://central.portworx.com/specGen/wizard). Note that the Portworx trial edition expires in 30 days after which you need to upgrade to an Enterprise Edition. 

Cloud Pak for Data supports an [entitled Portworx instance](https://www.ibm.com/support/knowledgecenter/SSQNUZ_current/cpd/install/portworx-install.html) which you can install manually once your cluster is provisioned.

####	OpenShift Data Foundation (ODF) Subscription

The [Red Hat OpenShift Data Foundation](https://www.redhat.com/en/technologies/cloud-computing/openshift-data-foundation) license is linked as a separate entitlement to your RedHat subscription. If you do not have a separate subscription for ODF, a 60-day trial version is installed.
Note: OpenShift Container Storage(OCS) is now OpenShift Data Foundation starting from version 4.9. 

## Deployment topology

See [AWS topology](aws/README.md#deployment-topology) for more details for AWS.

See [Azure topology](azure/README.md#deployment-topology) for more details for Azure.

## Resource Requirements for Cloud Pak for Data.

Please refer to [Cloud Pak for Data System Requirements](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.5.x?topic=planning-system-requirements) for detailed information on the System requirements for installing Cloud Pak for Data platform and services.


## How to Deploy

You need to have [Terraform installed](https://learn.hashicorp.com/terraform/getting-started/install.html) on your client.

See [AWS deployment documentation](aws/README.md#steps-to-deploy) for AWS deployment.

See [Azure deployment documentation](azure/README.md#requirements) for Azure deployment.


## Scaling

The number of compute nodes in the cluster is controlled by [MachineSets](https://docs.openshift.com/container-platform/4.6/scalability_and_performance/recommended-cluster-scaling-practices.html).

To scale up or scale down the cluster:
* Find the MachineSet for the node in the region that you want to scale.

```bash
oc get machineset -n openshift-machine-api
```
* To manually increase or decrease the nodes in a zone, set the replicas to the desired count:
```bash
oc scale --replicas=<number of nodes for the machineset> machineset <machineset> -n openshift-machine-api
```

## Cloud Pak for Data Services

You can browse the various services that are available for use by navigating to the services catalog page in Cloud Pak for Data.

As part of the deployment, the following services can be enabled.

  - Watson Studio
  - Watson Knowledge Catalog
  - Watson Machine Learning
  - Data Virtualization
  - Watson OpenScale
  - Apache Spark
  - Cognos Dashboards
  - Db2 Warehouse
  - DataStage Enterprise Plus
  - Cognos Analytics
  - Db2 Advanced Edition
  - SPSS Modeler
 

To get information on various other services that are available, you can visit [Cloud Pak for Data Service Catalog](https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_current/cpd/svc/services.html).

## Activating Portworx using a key

* After the installation is complete, activate the license:
```bash
PX_POD=$(oc get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
oc exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl license activate <activation id>
```
* For more information see [Portworx Licensing](https://docs.portworx.com/reference/knowledge-base/px-licensing/).


## Approving CSRs if nodes are rebooted for the first time

When nodes are rebooted for the first time after the cluster is created, the Certificate Signing Requests for the nodes need to
be approved by cluster administrator. Until this is done the oc client will not function. The CSRs can be approved by using the kube config
file created at the time of install.

 - change directory to directory where you executed terraform.
 - `cd installer-files`
 - Run this to get the list of CSRs needing approval
 
    ```
    $ oc --kubeconfig=auth/config get csr
    ```
 - Run this to approve all CSRs in a single step

    ```
    oc --kubeconfig=auth/config get csr -o name | xargs oc --kubeconfig=auth/config adm certificate approve
    ```
