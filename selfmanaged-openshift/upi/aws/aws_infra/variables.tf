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
  default = "4.6.13"
}

variable "cloudctl-version" {
  default = "v3.6.0"
}

variable "datacore-version" {
  default = "1.3.3"
}

variable "cpd-version" {
  default = "latest"
}

variable "cpd-cli-version" {
  default = "3.5.2"
}

variable "images-rcos" {
  type = map

  default = {
    "af-south-1"      = "ami-09921c9c1c36e695c"
    "ap-east-1"       = "ami-01ee8446e9af6b197"
    "ap-northeast-1"  = "ami-04e5b5722a55846ea"
    "ap-northeast-2"  = "ami-0fdc25c8a0273a742"
    "ap-south-1"      = "ami-09e3deb397cc526a8"
    "ap-southeast-1"  = "ami-0630e03f75e02eec4"
    "ap-southeast-2"  = "ami-069450613262ba03c"
    "ca-central-1"    = "ami-012518cdbd3057dfd"
    "eu-central-1"    = "ami-0bd7175ff5b1aef0c"
    "eu-north-1"      = "ami-06c9ec42d0a839ad2"
    "eu-south-1"      = "ami-0614d7440a0363d71"
    "eu-west-1"       = "ami-01b89df58b5d4d5fa"
    "eu-west-2"       = "ami-06f6e31ddd554f89d"
    "eu-west-3"       = "ami-0dc82e2517ded15a1"
    "me-south-1"      = "ami-07d181e3aa0f76067"
    "sa-east-1"       = "ami-0cd44e6dd20e6c7fa"
    "us-east-1"       = "ami-04a16d506e5b0e246"
    "us-east-2"       = "ami-0a1f868ad58ea59a7"
    "us-west-1"       = "ami-0a65d76e3a6f6622f"
    "us-west-2"       = "ami-0dd9008abadc519f1"
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
