##### Network Configuration #####
variable "region" {
  description = "The region to deploy the cluster in, e.g: us-west-2."
  default     = "eu-west-3"
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

variable "disconnected-cluster" {
  description = "For creating an disconnected cluster, select 'yes' otherwise 'no', default is 'no' "
  default     = "no"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC, e.g: 10.0.0.0/16"
  default     = "10.0.0.0/16"
}

variable "cluster_network_cidr" {
  default = "10.128.0.0/14"
}

variable "subnet-bits" {
  description = "The size of each subnet in each availability zone. Specify an integer between 5 and 13, where 5 is /27 and 13 is /19"
  default     = "12"
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

################################################################################################
# 1. For Existing VPC and SUBNETS, provide the values here, otherwise leave it as it is        #
# 2. All Private Subnets should be Tagged with same Name and Value.                            #
# 3. For single_zone installation, provide only subnetid-public1 and subnetid-private1 values. #
################################################################################################

# Make sure to enable DNS hostnames in existing VPC
variable "vpcid-existing" {
  description = "For existing VPC provide the existing VPC id otherwise leave it blank for new vpc."
  default     = ""
}

variable "subnetid-public1" {
  description = "Public Subnet in ZONE 1"
  default     = ""
}

variable "subnetid-public2" {
  description = "Public Subnet in ZONE 2"
  default     = ""
}

variable "subnetid-public3" {
  description = "Public Subnet in ZONE 3"
  default     = ""
}

variable "subnetid-private1" {
  description = "Private Subnet in ZONE 1"
  default     = ""
}

variable "subnetid-private2" {
  description = "Private Subnet in ZONE 2"
  default     = ""
}

variable "subnetid-private3" {
  description = "Private Subnet in ZONE 3"
  default     = ""
}

variable "private-subnet-tag-name" {
  default = "aws:cloudformation:logical-id"
}

variable "private-subnet-tag-value" {
  default = "PrivateSubnet*"
}
######################################################################################
######################################################################################


##### AWS Configuration #####
variable "key_name" {
  description = "The name of the key to user for ssh access, e.g: consul-cluster"
  default     = "upi-key"
}

variable "tenancy" {
  description = "Amazon EC2 instances tenancy type, default/dedicated"
  default     = "default"
}

variable "access_key_id" {
  default = ""
}

variable "secret_access_key" {
  default = ""
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

variable "bootnode-instance-type" {
  default = "m5.xlarge"
}

variable "cluster-name" {
  default = "upi-cluster"
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
  default = "kubeadmin"
}

variable "openshift-password" {
  default = "password"
}

variable "pull-secret-file-path" {
  default = ""
}

variable "public_key_path" {
  description = "The local public key path, e.g. ~/.ssh/id_rsa.pub"
}

variable "ssh-public-key" {
  default = ""
}

variable "ssh-private-key-file-path" {
  default = ""
}

variable "classic-lb-timeout" {
  description = "Classic loadbalancer timeout value in seconds."
  default = "1800"
}

##### DNS configuration #####
variable "dnszone" {
  default = ""
}

variable "hosted-zoneid" {
  description = "Pass the Hosted Zone ID for the Route53 zone"
  default     = ""
}

##### Portworx / OCS / EFS Configuration #####
# To use EBS storage for Watson AI Services, select "efs" as "storage-type"
variable "storage-type" {
  description = "portworx / ocs / efs"
  default     = "portworx"
}

variable "portworx-spec-url" {
  description = "URL for generated portworx spec"
  default     = ""
}

# If storage-type is selected as efs, select one of the performance mode, default is generalPurpose
variable "efs-performance-mode" {
  description = "generalPurpose / maxIO"
  default     = "generalPurpose"
}

#############################################################################
# For disconnected cluster, provide these values, otherwise leave it blanck #
#############################################################################
variable "redhat-username" {
  default = ""
}

variable "redhat-password" {
  default = ""
}

variable "certificate-file-path" {
  default = ""
}

variable "local-registry-repository" {
  default = ""
}

variable "local-registry" {
  default = ""
}

variable "local-registry-username" {
  default = ""
}

variable "local-registry-pwd" {
  default = ""
}

variable "mirror-region" {
  default = ""
}

variable "mirror-vpcid" {
  default = ""
}

variable "mirror-vpccidr" {
  default = ""
}

variable "mirror-sgid" {
  default = ""
}

variable "mirror-routetable-id" {
  default = ""
}

# Input all the comma separated list of CP4D Service that you want to install. 
# For example, to install the Cloud Pak for Data control plane, Watson Studio and Data Virtualization, specify lite,wsl,dv.
# At a minimum, you must specify lite.
variable "cpdservices-to-install" {
  description = "lite,dv,spark,wkc,wsl,wml,aiopenscale,cde,streams,streams-flows,ds,db2wh,db2oltp,dmc,datagate,dods,ca,spss-modeler,big-sql,pa"
  default     = "lite"
}

# Required when selected OCS as stoarge type in an disconnected env.
variable "imageContentSourcePolicy-path" {
  description = "Required when selected OCS as stoarge type in an disconnected env"
  default     = ""
}
########################################################################
########################################################################


##### IBM Cloud Pak for Data Configuration #####
variable "accept-cpd-license" {
  description = "Read and accept license at https://ibm.biz/Bdq6KP, (accept / reject)"
  default     = "reject"
}

variable "cpd-namespace" {
  default = "cpd-tenant"
}

variable "api-key" {
  default = ""
}

##################################
#    CP4D Services to install    #
##################################
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

variable "data-management-console" {
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

variable "db2-bigsql" {
  default = "no"
}

variable "planning-analytics" {
  default = "no"
}

####################################################
# Other Parameters , Don't modify any values here #
####################################################
variable "ocp-version" {
  default = "4.5.18"
}

variable "cloudctl-version" {
  default = "v3.6.0"
}

variable "datacore-version" {
  default = "1.3.1"
}

variable "cpd-version" {
  default = "latest"
}

variable "cpd-cli-version" {
  default = "v3.5.0"
}

variable "images-rcos" {
  type = map

  default = {
    "ap-northeast-1" = "ami-0530d04240177f118"
    "ap-northeast-2" = "ami-09e4cd700276785d2"
    "ap-south-1"     = "ami-0754b15d212830477"
    "ap-southeast-1" = "ami-03b46cc4b1518c5a8"
    "ap-southeast-2" = "ami-0a5b99ab2234a4e6a"
    "ca-central-1"   = "ami-012bc4ee3b6c673bc"
    "eu-central-1"   = "ami-02e08df1201f1c2f8"
    "eu-north-1"     = "ami-0309c9d2fadcb2d5a"
    "eu-west-1"      = "ami-0bdd69d8e7cd18188"
    "eu-west-2"      = "ami-0e610e967a62dbdfa"
    "eu-west-3"      = "ami-0e817e26f638a71ac"
    "me-south-1"     = "ami-024117d7c87b7ff08"
    "sa-east-1"      = "ami-08e62f746b94950c1"
    "us-east-1"      = "ami-077ede5bed2e431ea"
    "us-east-2"      = "ami-0f4ecf819275850dd"
    "us-west-1"      = "ami-0c4990e435bc6c5fe"
    "us-west-2"      = "ami-000d6e92357ac605c"
  }
}

variable "image-replica" {
  description = "Replica count for imageregistry"
  type        = map

  default = {
    "single_zone" = 1
    "multi_zone"  = 3
  }
}

# StorageClass Lite, DV, Spark, wkc, wsl, wml, AI-Openscale, cde, Streams Flows,
#              Datastage, Db2Wh, Db2oltp, dods, ca, SPSS
variable "cpd-storageclass" {
  type = map

  default = {
    "portworx" = "portworx-shared-gp3"
    "ocs"      = "ocs-storagecluster-cephfs"
    "efs"      = "aws-efs"
  }
}

# StorageClass Streams
variable "streams-storageclass" {
  type = map

  default = {
    "portworx" = "portworx-shared-gp-allow"
    "ocs"      = "ocs-storagecluster-cephfs"
    "efs"      = "aws-efs"
  }
}

# StorageClass Db2 Bigsql
variable "bigsql-storageclass" {
  type = map

  default = {
    "portworx" = "portworx-dv-shared-gp3"
    "ocs"      = "ocs-storagecluster-cephfs"
    "efs"      = "aws-efs"
  }
}

data "aws_availability_zones" "azs" {}
