##### AWS Configuration #####
variable "region" {
  description = "The region to deploy the cluster in, e.g: us-west-2."
  default     = "eu-west-2"
}

variable "tenancy" {
  description = "Amazon EC2 instances tenancy type, default/dedicated"
  default     = "default"
}

variable "access_key_id" {
  type        = string
  description = "Access Key ID for the AWS account"

  validation {
    condition     = length(var.access_key_id) > 0
    error_message = "Access Key ID must be provided."
  }
}

variable "secret_access_key" {
  type        = string
  description = "Secret Access Key for the AWS account"

  validation {
    condition     = length(var.secret_access_key) > 0
    error_message = "Secret Access Key must be provided."
  }
}
##############################

variable "new_or_existing_vpc_subnet" {
  description = "For existing VPC and SUBNETS use 'exist' otherwise use 'new' to create new VPC and SUBNETS, default is 'new' "
  default     = "new"
}

##############################
# New Network
##############################
variable "vpc_cidr" {
  description = "The CIDR block for the VPC, e.g: 10.0.0.0/16"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr1" {
  default = "10.0.0.0/20"
}

variable "public_subnet_cidr2" {
  default = "10.0.16.0/20"
}

variable "public_subnet_cidr3" {
  default = "10.0.32.0/20"
}

variable "private_subnet_cidr1" {
  default = "10.0.128.0/20"
}

variable "private_subnet_cidr2" {
  default = "10.0.144.0/20"
}

variable "private_subnet_cidr3" {
  default = "10.0.160.0/20"
}

##############################
# Existing Network       
##############################
variable "vpc_id" {
  default = ""
}
variable "public_subnet1_id" {
  default = ""
}

variable "public_subnet2_id" {
  default = ""
}

variable "public_subnet3_id" {
  default = ""
}

variable "private_subnet1_id" {
  default = ""
}

variable "private_subnet2_id" {
  default = ""
}

variable "private_subnet3_id" {
  default = ""
}
#############################

##########
# ROSA
##########
variable "cluster_name" {
  type = string
  default = "myrosa"
}

variable "rosa_token" {
  type = string
}

variable "worker_machine_type" {
  type = string
  default = "m5.4xlarge"
}

variable "worker_machine_count" {
  type = number
  default = 3
}

variable "private_cluster" {
  type        = bool
  description = "Endpoints should resolve to Private IPs"
  default = false
}

variable "cluster_network_cidr" {
  type    = string
  default = "10.128.0.0/14"
}

variable "cluster_network_host_prefix" {
  type    = number
  default = 23
}

variable "service_network_cidr" {
  type    = string
  default = "172.30.0.0/16"
}

# Enter the number of availability zones the cluster is to be deployed, default is multi zone deployment.
variable "az" {
  description = "single_zone / multi_zone"
  default     = "multi_zone"
}

variable "availability_zone1" {
  description = "example eu-west-2a"
  default     = ""
}

variable "availability_zone2" {
  description = "example eu-west-2b"
  default     = ""
}

variable "availability_zone3" {
  description = "example eu-west-2c"
  default     = ""
}

###################################
# Enable only one Storage option
###################################
variable "ocs" {
  type = map(string)
  default = {
    enable = true
    ocs_instance_type = "m5.4xlarge"
  }
}

variable "portworx_enterprise" {
  type = map(string)
  description = "See PORTWORX.md on how to get the Cluster ID."
  default = {
    enable = false
    cluster_id = ""
    enable_encryption = true
  }
}

variable "portworx_essentials" {
  type = map(string)
  description = "See PORTWORX-ESSENTIALS.md on how to get the Cluster ID, User ID and OSB Endpoint"
  default = {
    enable = false
    cluster_id = ""
    user_id = ""
    osb_endpoint = ""
  }
}

variable "portworx_ibm" {
  type = map(string)
  description = "This is the IBM freemium version of Portworx. It is limited to 5TB and 5Nodes"
  default = {
    enable = false
    ibm_px_package_url = "http://158.85.173.111/repos/zen/cp4d-builds/3.0.1/misc/portworx/cpd-ocp46x-portworx-v2.7.0.0.tgz"
  }
}

################################

#############
# CPD Variables
###############
variable "accept_cpd_license" {
  description = "Read and accept license at https://ibm.biz/Bdq6KP, (accept / reject)"
  default = "reject"
}

variable "cpd_external_registry" {
  description = "URL to external registry for CPD install. Note: CPD images must already exist in the repo"
  default = ""
}

variable "cpd_external_username" {
  description = "URL to external username for CPD install. Note: CPD images must already exist in the repo"
  default = ""
}

variable "api_key" {
  description = "Repository APIKey or Registry password"
  default = ""
}

variable "cpd_namespace" {
  description = "Openshift Namespace to deploy CPD into"
  default = "cpd-tenant"
}

variable "cloudctl_version" {
  default = "v3.6.0"
}

variable "datacore_version" {
  default = "1.3.3"
}

variable "openshift_version" {
  default = "4.6.17"
}

variable "data_virtualization" {
  default = "no"
}

variable "apache_spark" {
  default = "no"
}

variable "watson_knowledge_catalog" {
  default = "no"
}

variable "watson_studio_library" {
  default = "no"
}

variable "watson_machine_learning" {
  default = "no"
}

variable "watson_ai_openscale" {
  default = "no"
}

variable "cognos_dashboard_embedded" {
  default = "no"
}

variable "streams" {
  default = "no"
}

variable "streams_flows" {
  default = "no"
}

variable "datastage" {
  default = "no"
}

variable "db2_warehouse" {
  default = "no"
}

variable "db2_advanced_edition" {
  default = "no"
}

variable "data_management_console" {
  default = "no"
}

variable "datagate" {
  default = "no"
}

variable "decision_optimization" {
  default = "no"
}

variable "cognos_analytics" {
  default = "no"
}

variable "spss_modeler" {
  default = "no"
}

variable "db2_bigsql" {
  default = "no"
}

variable "planning_analytics" {
  default = "no"
}