# Cloud Pak for Data

[IBM Cloud Pak for Data](https://www.ibm.com/ca-en/products/cloud-pak-for-data) is an end-to-end platform that helps organizations in their journey to AI. It enables data engineers, data stewards, data scientists, and business analysts to collaborate using an integrated multiple-cloud platform. Cloud Pak for Data uses IBM's deep analytics portfolio to help organizations meet data and analytics challenges. The required building blocks (collect, organize, analyze, infuse) for information architecture are available using Cloud Pak for Data.

Cloud Pak for Data (any version) can be deployed on OCP provided it meets pre-reqs as defined by the [Knowledge Center](https://www.ibm.com/docs/en/cloud-paks/cp-data).
Through the marketplace offerings on [Amazon Web Services](https://aws.amazon.com/marketplace/search/results?searchTerms=cloud+pak+for+data&CREATOR=5a98c23f-75fb-4910-9b82-f94ce8e3f06d&filters=CREATOR) ,  [Microsoft AZURE](https://azuremarketplace.microsoft.com/en-us/marketplace/apps?search=cloud%20pak%20for%20data&page=1) and [IBM Cloud Catalog](https://cloud.ibm.com/catalog/content/ibm-cp-datacore-6825cc5d-dbf8-4ba2-ad98-690e6f221701-global), the user can do a one click automated deployment of CP4D clusters with a pre-defined configuration.

This repository contains deployment steps to get you started on setting up Cloud Pak for Data on IBM Cloud Satellite locations.

- Cloud Pak for Data on IBM Cloud Satellite locations

	- [AWS](./ibmcloud-satellite/aws)

	- [On-Premises](./ibmcloud-satellite/on-premises)
	
	- [IBM Cloud Satellite locations on Azure Infrastructure](./azure/README.md)


## Upgrade and Post-Installation activities

Please see  [Updating OpenShift Container Platform](https://docs.openshift.com/container-platform/4.10/updating/index.html) for upgrading RedHat Openshift Container Platform and [Upgrading Cloud Pak for Data](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.5.x?topic=upgrading) for upgrading IBM Cloud Pak for Data installation.

For Post-Installation activities on the cluster,please refer to the instructions at  [Administering Cloud Pak for Data](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.5.x?topic=administering)




