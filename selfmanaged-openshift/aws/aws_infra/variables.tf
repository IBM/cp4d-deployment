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

###############################################################################
# 1. Leave it as it is if you don't want to provide Availability zone values, #
#    in that case it will be automatically selected based on the region.      #
# 2. For single_zone installation, provide only availability-zone1 value.     #
###############################################################################
variable "availability-zone1" {
  description = "example eu-west-2a"
  default     = ""
}

variable "availability-zone2" {
  description = "example eu-west-2b"
  default     = ""
}

variable "availability-zone3" {
  description = "example eu-west-2c"
  default     = ""
}
################################################################################

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

################################################################################################
# 1. For Existing VPC and SUBNETS, provide the values here, otherwise leave it as it is.       #
# 2. All Private Subnets should be Tagged with same Name and Value.                            #
# 3. For single_zone installation, provide only subnetid-public1 and subnetid-private1 values. #
# 4. For only-private-subnets installation, provide all three Private Subnet values or         # 
#    subnetid-private1 for single_zone installation.                                           #
################################################################################################

# Make sure to enable DNS hostnames in existing VPC
variable "vpcid-existing" {
  description = "For existing VPC provide the existing VPC id otherwise leave it blank for new vpc."
  default     = ""
}

variable "only-private-subnets" {
  description = "Select 'yes' if only private subnets present in the existing VPC, default is 'no'."
  default     = "no"
}

variable "subnetid-public1" {
  description = "Public Subnet in ZONE 1"
  default = ""
}

variable "subnetid-public2" {
  description = "Public Subnet in ZONE 2"
  default = ""
}

variable "subnetid-public3" {
  description = "Public Subnet in ZONE 3"
  default = ""
}

variable "subnetid-private1" {
  description = "Private Subnet in ZONE 1"
  default = ""
}

variable "subnetid-private2" {
  description = "Private Subnet in ZONE 2"
  default = ""
}

variable "subnetid-private3" {
  description = "Private Subnet in ZONE 3"
  default = ""
}

variable "private-subnet-tag-name" {
  default = "Name"
}

variable "private-subnet-tag-value" {
  default = "*cpd-private-subnet*"
}
######################################################################################
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
  default = ""
}

variable "ssh-public-key" {
  default = ""
}

variable "ssh-private-key-file-path" {
  default = ""
}

variable "classic-lb-timeout" {
  description = "Classic loadbalancer timeout value in seconds."
  default = "600"
}

##### DNS configuration #####
variable "dnszone" {
  default = ""
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
  description = "Read and accept license at https://ibm.biz/Bdq6KP, (accept / reject)"
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

##############################
#     Watson AI Services     #
##############################
# variable "watson-assistant" {
#   default = "no"
# }

# variable "watson-discovery" {
#   default = "no"
# }

# variable "watson-knowledge-studio" {
#   default = "no"
# }

# variable "watson-language-translator" {
#   default = "no"
# }

# variable "watson-speech" {
#   default = "no"
# }
##############################
##############################

####################################################
# Other Parameters , don't modfify any values here #
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

# StorageClass Db2 Bigsql
variable "bigsql-storageclass" {
  type        = map

  default     = {
    "portworx"   = "portworx-dv-shared-gp3"
    "ocs"        = "ocs-storagecluster-cephfs"
    "efs"        = "aws-efs"
  }
}

data "aws_availability_zones" "azs" {}
