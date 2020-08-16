##### Network Configuration #####
variable "region" {
  description = "The region to deploy the cluster in, e.g: us-west-2."
  default     = "eu-west-2"
}

# Enter the number of availability zones the cluster is to be deployed, default is multi zone deployment.
variable "azlist" {
  description = "single_zone / multi_zone"
  default     = "multi_zone"
}

variable "new-or-existing-vpc-subnet" {
  description = "For existing VPC and SUBNETS use 'exist' otherwise use 'new' to create new VPC and SUBNETS, default is 'new' "
  default     = "new"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC, e.g: 10.0.0.0/16"
  default     = "10.0.0.0/16"
}

variable "public-subnet-cidr1" {
  default = "10.0.0.0/20"
}

variable "public-subnet-cidr2" {
  default = "10.0.16.0/20"
}

variable "public-subnet-cidr3" {
  default = "10.0.32.0/20"
}

variable "private-subnet-cidr1" {
  default = "10.0.128.0/20"
}

variable "private-subnet-cidr2" {
  default = "10.0.144.0/20"
}

variable "private-subnet-cidr3" {
  default = "10.0.160.0/20"
}

######################################################################################
# For Existing VPC and SUBNETS, provide the values here, otherwise leave it as it is #
######################################################################################

# Make sure to enable DNS hostnames in existing VPC
variable "vpcid-existing" {
  description = "For existing VPC provide the existing VPC id otherwise leave it blank for new vpc."
  default     = ""
}

variable "subnetid-public1" {
  description = "Public Subnet in ZONE a"
  default = ""
}

variable "subnetid-public2" {
  description = "Public Subnet in ZONE b"
  default = ""
}

variable "subnetid-public3" {
  description = "Public Subnet in ZONE c"
  default = ""
}

variable "subnetid-private1" {
  description = "Private Subnet in ZONE a"
  default = ""
}

variable "subnetid-private2" {
  description = "Private Subnet in ZONE b"
  default = ""
}

variable "subnetid-private3" {
  description = "Private Subnet in ZONE c"
  default = ""
}
######################################################################################


##### AWS Configuration #####
variable "key_name" {
  description = "The name of the key to user for ssh access, e.g: consul-cluster"
  default     = "openshift-key"
}

variable "tenancy" {
  description = "Amazon EC2 instances tenancy type, default/dedicated"
  default     = "default"
}

variable "access_key_id" {
}

variable "secret_access_key" {
}

##### OpenShift Hosts Configuration #####
variable "master_replica_count" {
  description = "Replica count of master machines in the cluster"
  default     = 3
}

variable "worker_replica_count" {
  description = "Replica count of worker machines in the cluster"
  default     = 3
}

variable "master-instance-type" {
  default = "m5.2xlarge"
}

variable "worker-instance-type" {
  default = "m5.4xlarge"
}

variable "worker-ocs-instance-type" {
  default = "m4.4xlarge"
}

variable "bootnode-instance-type" {
  default = "m5.xlarge"
}

variable "cluster-name" {
  default = "openshift-cluster"
}

variable "private-or-public-cluster" {
  description = "public / private"
  default     = "public"
}

variable "fips-enable" {
  description = "true / false"
  default     = true
}

variable "admin-username" {
  default = "ec2-user"
}

variable "openshift-username" {
}

variable "openshift-password" {
}

variable "pull-secret-file-path" {
}

variable "public_key_path" {
  description = "The local public key path, e.g. ~/.ssh/id_rsa.pub"
}

variable "ssh-public-key" {
}

variable "ssh-private-key-file-path" {
}

##### DNS configuration #####
variable "dnszone" {
}

##### Portworx / OCS / EFS Configuration #####
# To use EBS storage for Watson AI Services, select "efs" as "storage-type"
variable "storage-type" {
  description = "portworx / ocs / efs"
  default     = "portworx"
}

variable "portworx-spec-url" {
  description = "URL for generated portworx spec"
  default = ""
}

##### IBM Cloud Pak for Data Configuration #####
variable "accept-cpd-license" {
  description = "Read and accept license at https://ibm.biz/BdqSw4, (accept / reject)"
  default = "reject"
}

variable "cpd-namespace" {
  default = "zen"
}

variable "entitlementkey" {
}

variable "data-virtualization" {
  default = "no"
}

variable "apache-spark" {
  default = "no"
}

variable "watson-knowledge-catalog" {
  default = "no"
}

variable "watson-studio-library" {
  default = "no"
}

variable "watson-machine-learning" {
  default = "no"
}

variable "watson-ai-openscale" {
  default = "no"
}

variable "cognos-dashboard-embedded" {
  default = "no"
}

variable "streams" {
  default = "no"
}

variable "streams-flows" {
  default = "no"
}

variable "datastage" {
  default = "no"
}

variable "db2-warehouse" {
  default = "no"
}

variable "db2-advanced-edition" {
  default = "no"
}

variable "decision-optimization" {
  default = "no"
}

variable "cognos-analytics" {
  default = "no"
}

variable "spss-modeler" {
  default = "no"
}

##############################
#     Watson AI Services     #
##############################
variable "watson-assistant" {
  default = "no"
}

variable "watson-discovery" {
  default = "no"
}

variable "watson-knowledge-studio" {
  default = "no"
}

variable "watson-language-translator" {
  default = "no"
}

variable "watson-speech" {
  default = "no"
}
##############################

##### Other Parameters , Don't modfify any values here#####
variable "s3-bucket" {
  default = "ibm-cloud-private-data"
}

variable "inst_version" {
  default = "3.0"
}

variable "images-rcos" {
  type = map

  default = {
    "ap-northeast-1"  = "ami-023d0452866845125"
    "ap-northeast-2"  = "ami-0ba4f9a0358bcb44a"
    "ap-south-1"      = "ami-0bf62e963a473068e"
    "ap-southeast-1"  = "ami-086b93722336bd1d9"
    "ap-southeast-2"  = "ami-08929f33bfab49b83"
    "ca-central-1"    = "ami-0f6d943a1fa9172fd"
    "eu-central-1"    = "ami-0ceea534b63224411"
    "eu-north-1"      = "ami-06b7087b2768f644a"
    "eu-west-1"       = "ami-0e95125b57fa63b0d"
    "eu-west-2"       = "ami-0eef98c447b85ffcd"
    "eu-west-3"       = "ami-0049e16104f360df6"
    "me-south-1"      = "ami-0b03ea038629fd02e"
    "sa-east-1"       = "ami-0c80d785b30eef121"
    "us-east-1"       = "ami-06f85a7940faa3217"
    "us-east-2"       = "ami-04a79d8d7cfa540cc"
    "us-west-1"       = "ami-0633b392e8eff25e7"
    "us-west-2"       = "ami-0d231993dddc5cd2e"
  }
}

variable "image-replica" {
  description = "Replica count for imageregistry"
  type        = map

  default     = {
    "single_zone"     = 1
    "multi_zone"      = 3
  }
}

variable "cpd-override" {
  type        = map

  default     = {
    "portworx"   = "--override $HOME/ibm/portworx-override.yaml"
    "ocs"        = "--override $HOME/ibm/ocs-override.yaml"
    "efs"        = ""
  }
}

# StorageClass Lite, DV, Spark, wkc, wsl, wml, AI-Openscale, cde, Streams Flows,
#              Datastage, Db2Wh, Db2oltp, dods, ca, SPSS
variable "cpd-storageclass" {
  type        = map

  default     = {
    "portworx"   = "portworx-shared-gp3"
    "ocs"        = "ocs-storagecluster-cephfs"
    "efs"        = "aws-efs"
  }
}

# StorageClass Streams
variable "streams-storageclass" {
  type        = map

  default     = {
    "portworx"   = "portworx-shared-gp-allow"
    "ocs"        = "ocs-storagecluster-cephfs"
    "efs"        = "aws-efs"
  }
}

data "aws_availability_zones" "azs" {}
