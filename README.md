# Cloud Pak for Data

[IBM Cloud Pak for Data](https://www.ibm.com/ca-en/products/cloud-pak-for-data) is an end-to-end platform that helps organizations in their journey to AI. It enables data engineers, data stewards, data scientists, and business analysts to collaborate using an integrated multiple-cloud platform. Cloud Pak for Data uses IBM's deep analytics portfolio to help organizations meet data and analytics challenges. The required building blocks (collect, organize, analyze, infuse) for information architecture are available using Cloud Pak for Data.


This repository contains automated scripts/deployment steps to get you started on Cloud Pak for Data on different cloud providers on managed or self managed OpenShift platforms.

- Cloud Pak for Data on Managed OpenShift

	-  	[IBM Cloud (VPC Gen2)](./managed-openshift/ibmcloud/README.md)

	-  [AWS ROSA](./managed-openshift/aws/terraform/README.md)

	-  [Azure ARO](./managed-openshift/azure/arm/README.md)

- Cloud Pak for Data on Self Managed OpenShift

	-  [AWS](./selfmanaged-openshift/README.md)

	-  [Azure](./selfmanaged-openshift/README.md)

-  [Cloud Pak for Data on Existing OpenShift](./existing-openshift/README.md)

- Cloud Pak for Data on IBM Cloud Satellite locations

	- [AWS](./ibmcloud-satellite/aws)

	- [On-Premises](./ibmcloud-satellite/on-premises)

## Note regarding usage of the scripts

1.  Installation

The automated scripts provided here are intended to get you started quickly in case of a fresh installation of the latest version of Cloud Pak for Data in an Express manner. The scripts perform end-to-end installation, starting from infrastructure provisioning, Openshift installation, Storage Setup and Cloud Pak for Data platform and services installation.

If you need to perform a customized installation please follow the steps at [Installing IBM Cloud Pak for Data](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.5.x?topic=installing).

2.  Upgrade and Post-Installation activities

These scripts do not support upgrade of Cloud Pak for Data installations. Please see  [Updating OpenShift Container Platform](https://docs.openshift.com/container-platform/4.10/updating/index.html) for upgrading RedHat Openshift Container Platform and [Upgrading Cloud Pak for Data](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.5.x?topic=upgrading) for upgrading IBM Cloud Pak for Data installation.

For Post-Installation activities on the cluster, please refer to the instructions at  [Administering Cloud Pak for Data](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.5.x?topic=administering)



