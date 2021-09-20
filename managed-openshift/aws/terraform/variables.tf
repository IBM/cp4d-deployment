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

##################################
# Cluster configuration variables
##################################
variable "configure_global_pull_secret" {
  type        = bool
  description = "Configuring global pull secret"
  default     = true
}

variable "configure_openshift_nodes" {
  type        = bool
  description = "Setting machineconfig parameters on worker nodes"
  default     = true
}

##########
# ROSA
##########
variable "openshift_version" {
  default = "4.8.11"
}

variable "cluster_name" {
  type    = string
  default = "ibmrosa"
}

variable "rosa_token" {
  type = string
}

variable "worker_machine_type" {
  type    = string
  default = "m5.4xlarge"
}

variable "worker_machine_count" {
  type    = number
  default = 3
}

variable "private_cluster" {
  type        = bool
  description = "Endpoints should resolve to Private IPs"
  default     = false
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
    enable            = true
    ocs_instance_type = "m5.4xlarge"
  }
}

variable "portworx_enterprise" {
  type        = map(string)
  description = "See PORTWORX.md on how to get the Cluster ID."
  default = {
    enable            = false
    cluster_id        = ""
    enable_encryption = true
  }
}

variable "portworx_essentials" {
  type        = map(string)
  description = "See PORTWORX-ESSENTIALS.md on how to get the Cluster ID, User ID and OSB Endpoint"
  default = {
    enable       = false
    cluster_id   = ""
    user_id      = ""
    osb_endpoint = ""
  }
}

variable "portworx_ibm" {
  type        = map(string)
  description = "This is the IBM freemium version of Portworx. It is limited to 5TB and 5Nodes"
  default = {
    enable              = false
    ibm_px_package_path = "" # absolute file path to the folder containing the cpd*-portworx*.tgz package
  }
}

################################

#############
# CPD Variables
###############
variable "accept_cpd_license" {
  description = "Read and accept license at https://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-DNAA-BZTPEW, (accept / reject)"
  default     = "reject"
}

variable "cpd_external_registry" {
  description = "URL to external registry for CPD install. Note: CPD images must already exist in the repo"
  default     = "cp.icr.io"
}

variable "cpd_external_username" {
  description = "URL to external username for CPD install. Note: CPD images must already exist in the repo"
  default     = "cp"
}

variable "cpd_api_key" {
  description = "Repository APIKey or Registry password"
}

variable "cpd_namespace" {
  description = "Openshift Namespace to deploy CPD into"
  default     = "zen"
}

variable "cloudctl_version" {
  default = "v3.7.1"
}

variable "cpd_platform" {
  type        = map(string)
  default = {
    enable   = "yes"
    version  = "4.0.1"
    channel  = "v2.0"
  }
}

variable "data_virtualization" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "1.7.1"
    channel  = "v1.7"
  }
}

variable "analytics_engine" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "stable-v1"
  }
}

variable "watson_knowledge_catalog" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v1.0"
  }
}

variable "watson_studio" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v2.0"
  }
}

variable "watson_machine_learning" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v1.1"
  }
}

variable "watson_ai_openscale" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v1"
  }
}

variable "spss_modeler" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v1.0"
  }
}

variable "cognos_dashboard_embedded" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v1.0"
  }
}

variable "datastage" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v1.0"
  }
}

variable "db2_warehouse" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v1.0"
  }
}

variable "db2_oltp" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v1.0"
  }
}

variable "cognos_analytics" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v4.0"
  }
}

variable "data_management_console" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v1.0"
  }
}

variable "master_data_management" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v1.1"
  }
}

variable "db2_aaservice" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v1.0"
  }
}

variable "decision_optimization" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.1"
    channel  = "v4.0"
  }
}