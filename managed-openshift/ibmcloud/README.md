# Cloud Pak for Data 3.5 on Red Hat OpenShift on IBM Cloud

[IBM Cloud Pak for Data](https://www.ibm.com/ca-en/products/cloud-pak-for-data) is an end-to-end platform that helps organizations in their journey to AI. It enables data engineers, data stewards, data scientists, and business analysts to collaborate using an integrated multiple-cloud platform. Cloud Pak for Data uses IBM’s deep analytics portfolio to help organizations meet data and analytics challenges. The required building blocks (collect, organize, analyze, infuse) for information architecture are available using Cloud Pak for Data on IBM Cloud.

This deployment guide provides instructions for deploying Cloud Pak for Data on managed Red Hat OpenShift on IBM Cloud (formerly known as ROKS) using Terraform.

## Costs and licenses

These scripts create resources on IBM Cloud. For cost estimates, see the pricing pages for each IBM Cloud service that will be enabled. This deployment lets you use the OpenShift license bundled with your Cloud Pak entitlement. Portworx Enterprise is installed from the IBM Cloud catalog and a separate subscription from Portworx is not required.

You must have a Cloud Pak for Data entitlement API key to download images from the IBM entitled Cloud Pak registry. If you don't have a paid entitlement, you can create a [60 day trial subscription key](https://www.ibm.com/account/reg/us-en/signup?formid=urx-42212). You can retrieve your entitlement key from the [container software library](https://myibm.ibm.com/products-services/containerlibrary).

**Note**: After 60 days, contact [IBM Cloud Pak for Data sales](https://www.ibm.com/account/reg/us-en/signup?formid=MAIL-cloud).

## Deployment topology

The deployment creates the following resources:

* A [Virtual Private Cloud (Gen 2)](https://cloud.ibm.com/docs/vpc/vpc-getting-started-with-ibm-cloud-virtual-private-cloud-infrastructure) spanning one or three zones with a public gateway and private subnet in each zone.

* A [Red Hat OpenShift on IBM Cloud](https://www.ibm.com/ca-en/cloud/openshift) cluster.

* One [block storage](https://cloud.ibm.com/docs/vpc?topic=vpc-block-storage-about) volume attached to each worker node.

* [Portworx Enterprise](https://cloud.ibm.com/catalog/services/portworx-enterprise) running highly-available software-defined persistent storage.

* A managed database service ([Databases for Etcd](https://cloud.ibm.com/docs/databases-for-etcd?topic=databases-for-etcd-getting-started)) for Portworx cluster metadata to keep the metadata separate from application data (optional).

* IBM Cloud Object Storage instance to back up the internal registry of your cluster.

## Cloud Pak for Data services

As part of the deployment, the following services can be enabled. For more information about available services, visit the [Cloud Pak for Data services catalog](https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_current/cpd/svc/services.html).

* Lite (base)
* Analytics Engine powered by Apache Spark
* Data Virtualization
* Watson Knowledge Catalog
* Watson Studio
* Watson Machine Learning
* Watson OpenScale
* Cognos Dashboard Engine
* Streams
* Streams Flows
* DataStage
* Db2 Data Management Console
* Db2 Warehouse
* Db2
* Db2 Data Gate
* Decision Optimization
* Cognos Analytics
* SPSS Modeler

## Instructions

### Building the Terraform environment container

It is recommended that these scripts be executed from a Docker container to ensure that the required tools and packages are available. Docker can be installed for your system using instructions found [here](https://docs.docker.com/get-docker/). This deployment has been tested using Docker version 19.03.13.

1. Clone this repo.

2. Navigate to the directory containing this README.

2. Run `docker build . -t cpd-roks-terraform`.

3. Run `docker run -d --name my-container --mount type=bind,source="$(pwd)",target=/root/templates cpd-roks-terraform`.

This directory on the host will be bind-mounted to `~/templates` in the container. This allows file changes made in the host to be reflected in the container and vice versa. To create another cluster, clone the repo again in a new directory and create a new container (with a `--name` other than `my-container`). Do not bind multiple containers to the same host template directory.

### Installing Cloud Pak for Data

1. Copy `terraform.tfvars.template` to `terraform.tfvars` and enter the values. This file can also be used to override the defaults in `vars.tf`.

2. Log in to your container with `docker exec -it my-container bash`.

3. Run `terraform init`.

4. Run `terraform apply`.


### Securing your VPC and cluster

Currently, this deployment installs an OpenShift cluster in a VPC with permissive network access policies. To control traffic to your cluster, see [Securing the cluster network](https://cloud.ibm.com/docs/openshift?topic=openshift-vpc-network-policy).

## Troubleshooting

Open an Issue in this repo that describes the error.

### Common issues

Many failures can be resolved by retrying `terraform apply`. This is because tokens or script loops can time out prematurely when a resource takes unusually long to provision and stabilize.

* #### Errors with `docker` commands

  Ensure that your system has the latest version of Docker installed.

* #### `module.cpd_install.null_resource.extract_ibm_cp_datacore (local-exec): gzip: stdin: not in gzip format`

  The file `ibm-cp-datacore-*.tgz` has not been downloaded correctly from GitHub. Download the file from the browser using GitHub's **Download** button and move it to this directory.

* #### `exit status 1. Output: error: Missing or incomplete configuration info.  Please point to an existing, complete config file`

  This can occur when the `oc` token has expired or has been invalidated for some reason.
  1. Run `terraform state rm module.cpd_install.null_resource.oc_login module.cpd_install.null_resource.oc_login`.
  2. Retry `terraform apply`.

* #### `Error: timeout while waiting for state to become 'Ready'` seen for the resource `module.roks.ibm_container_vpc_cluster.this`

  This error happens when it takes longer than usual for the cluster ingress domain to be created.
  1. Open the IBM Cloud [OpenShift clusters](https://cloud.ibm.com/kubernetes/clusters?platformType=openshift) console and verify that the state of your cluster is "Normal". If there is an error, contact support or run `terraform destroy` and try again.
  2. Run `terraform untaint module.roks.ibm_container_vpc_cluster.this` to mark the resource as successful.
  3. Run `terraform apply` again. The deployment will continue onwards.

### Coming soon

* Support for deploying in an existing VPC
* Support for application access restrictions based on `allowed_cidr_range`
* Support for additional Cloud Pak for Data services
* Support for IBM Key Protect volume encryption at deploy time.
