# Cloud Pak for Data

Use this terraform module to install Cloud Pak for Data on an existing openshift cluster. 

The script does the cluster node configuration required for Cloud Pak for Data. For IBM Cloud, the cluster is expected to be pre-configured before running this script.

Note: The script does not setup storage. It should be pre-configured. For IBM Cloud Managed OpenShift deployments refer [IBM Cloud Existing Openshift](../managed-openshift/ibmcloud#deploying-in-an-existing-openshift-cluster) steps 

## Pre-requisites

- `Terraform`
- `jq`
- `oc`
- `podman`


## Setup

Fill in the `cpd.tfvars` with the existing openshift cluster details set up with storage.



## Run Terraform

```
terraform init
terraform apply -var-file=cpd.tfvars
```


