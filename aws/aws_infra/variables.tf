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

variable "cluster_network_cidr" {
  default     = "10.128.0.0/14"
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

# If storage-type is selected as efs, select one of the performance mode, default is generalPurpose
variable "efs-performance-mode" {
  description = "generalPurpose / maxIO"
  default = "generalPurpose"
}

##### IBM Cloud Pak for Data Configuration #####
variable "accept-cpd-license" {
  description = "Read and accept license at https://ibm.biz/BdqSw4, (accept / reject)"
  default = "reject"
}

variable "cpd-namespace" {
  default = "cpd-tenant"
}

variable "api-key" {
  default = ""
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

variable "datagate" {
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
# variable "ocp-version" {
#   description = "Red Hat OpenShift Container Platform version to be installed"
#   default     = "4.5.13"
# }

variable "cpd-version" {
  default = "latest"
}

variable "images-rcos" {
  type = map

  default = {
    "ap-northeast-1"  = "ami-0530d04240177f118"
    "ap-northeast-2"  = "ami-09e4cd700276785d2"
    "ap-south-1"      = "ami-0754b15d212830477"
    "ap-southeast-1"  = "ami-03b46cc4b1518c5a8"
    "ap-southeast-2"  = "ami-0a5b99ab2234a4e6a"
    "ca-central-1"    = "ami-012bc4ee3b6c673bc"
    "eu-central-1"    = "ami-02e08df1201f1c2f8"
    "eu-north-1"      = "ami-0309c9d2fadcb2d5a"
    "eu-west-1"       = "ami-0bdd69d8e7cd18188"
    "eu-west-2"       = "ami-0e610e967a62dbdfa"
    "eu-west-3"       = "ami-0e817e26f638a71ac"
    "me-south-1"      = "ami-024117d7c87b7ff08"
    "sa-east-1"       = "ami-08e62f746b94950c1"
    "us-east-1"       = "ami-077ede5bed2e431ea"
    "us-east-2"       = "ami-0f4ecf819275850dd"
    "us-west-1"       = "ami-0c4990e435bc6c5fe"
    "us-west-2"       = "ami-000d6e92357ac605c"
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
    "portworx"   = "portworx-override.yaml"
    "ocs"        = "ocs-override.yaml"
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
