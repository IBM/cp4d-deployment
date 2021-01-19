
# Cloud Pak for Data 3.5 on OCP 4.5 on AWS

## Deployment Topology:

Deploying this template builds the following Cloud Pak for Data cluster in single zone or multi zone.

![Alt text](images/aws-multi-zone.jpg)

The deployment sets up the following as shown in the diagram.
 - A highly available architecture that spans one or three Availability Zones.
 - A VPC configured with public and private subnets according to AWS best practices, to provide you with your own virtual network on AWS.
 - In the public subnets:
   - Managed network address translation (NAT) gateways to allow outbound internet access for resources in the private subnets.
   - A bootstrap server Amazon Elastic Compute Cloud (Amazon EC2) instance that also serves as a bastion host to allow inbound Secure Shell (SSH) access to EC2 instances in private subnets.
 - In the private subnets:
   - OCP master instances up to three Availability Zones
   - OpenShift Container Platform (OCP) compute nodes.
   - Elastic Block Storage disks that are mounted on the compute nodes for container persistent data.
 - A Classic Load Balancer spanning the public subnets for accessing Cloud Pak for Data from a web browser. Internet traffic to this load balancer is only permitted from ContainerAccessCIDR.
 - A Network Load Balancer spanning the public subnets for accessing the OCP master instances. Internet traffic to this load balancer is only permitted from RemoteAccessCIDR.
 - A Network Load Balancer spanning the private subnets for routing internal OpenShift application programming interface (API) traffic to the OCP master instances.
 - Amazon Route 53 as your public Domain Name System (DNS) for resolving domain names of the IBM Cloud Pak for Data management console and applications deployed on the cluster.


### Steps to Deploy:
* AWS `Access key ID` and `Secret access key` will be required for the deployment. Also `AdministratorAccess` policy is required for the IAM user which will be used for deploying the cluster.
* Before deploying the infrastructure make sure you have `python3` installed in your local machine.
* Create a Route 53 domain.
* [Download](https://cloud.redhat.com/openshift/install/pull-secret) a pull secret. Create a Red Hat account if you do not have one.
* [Sign up](https://www.ibm.com/account/reg/us-en/signup?formid=urx-42212) for a Cloud Pak for Data Trial Key if you don't have the API key.
* If you choose Portworx as your storage class, see [Portworx documentation](PORTWORX.md) for generating `portworx spec url`.
* Since the infrastructure to be build is described by terraform files which are specific to that infrasturcture, it is recommented to copy the cloned repository to a separate folder.
   Name the new folder differently in case you plan to build multiple infrastructures.
* Change the current directory to aws_infra:
```
cd cp4d-deployment-<your infrastructure name>/selfmanaged-openshift/aws/aws_infra
```
* Edit `variables.tf` and provide values for all the configuration variables. See the [Variables documentation](VARIABLES.md) for more details.
* Read the license at https://ibm.biz/Bdq6KP and accept it by setting variable `accept-cpd-license` to `accept`.
* If you want to hide sensitive data such as access_key_id or secret_access_key, remove the `default     = " " ` from `variables.tf` file against that variable.
```
Example:

variable "access_key_id" {
}
```
* Create file `osaws_var.tfvars` and write all the sensitive variables for which no `default     = " " ` value is provided in `variables.tf` file.
```
Example:

cat osaws_var.tfvars

access_key_id = "xxxxxxxxxxxxxxxxxxxxxxx"
secret_access_key = "xxxxxxxxxxxxxxxxxxxxxxx"
```
* Deploy scripts by executing the following command from the `cp4d-deployment-master/aws/aws_infra` directory:
```bash
terraform init
terraform apply -var-file="Path To osaws_var.tfvars file | tee terraform.log"
```
#### cp4d installation logs:
After openshift cluster installation is finished and cloud pak for data installation has started, you can check the installation logs for cp4d service as described here: [cp4d service installation logs](INSTALLATION-LOG.md)

### Destroying the cluster:
* When cluster created successfully, execute following commands to delete the cluster:
  ```bash
  terraform destroy -target null_resource.destroy_cluster -var-file="Path To osaws_var.tfvars file"
  terraform destroy -var-file="Path To osaws_var.tfvars file"
  ```
* When cluster creation fails for some reason and only bootnode is created, execute following commands to delete the created resources:
  ```bash
  terraform state rm null_resource.destroy_cluster
  terraform destroy -var-file="Path To osaws_var.tfvars file"
  ```
### Note:
Elastic File System is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process.
see [Elastic File System](https://docs.openshift.com/container-platform/4.3/storage/persistent_storage/persistent-storage-efs.html).
[Red Hat Technology Preview Features](https://access.redhat.com/support/offerings/techpreview/)
