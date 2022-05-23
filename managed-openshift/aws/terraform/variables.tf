##### AWS Configuration #####
variable "region" {
  description = "The region to deploy the cluster in, e.g: us-west-2."
  default     = "ap-southeast-1"
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
variable "openshift_version" {
  default = "4.10.15"
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

# Enter the number of availability zones the cluster is to be deployed, default is single zone deployment.
variable "az" {
  description = "single_zone / multi_zone"
  default     = "single_zone"
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

variable "storage_option" {
  type = string
}

variable "ocs" {
  type = map(string)
  default = {
    enable            = false
    ocs_instance_type = "m5.4xlarge"
  }
}

# EFS - See known issues
variable "efs" {
  type = map(string)
  default = {
    enable            = false
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

variable "cpd_version" {
  type    = string
  default = "4.5.0"
}

variable "cpd_platform" {
  type    = string
  default = "yes"
 
}

variable "data_virtualization" {
  type    = string
  default = "no"
}

variable "analytics_engine" {
  type    = string
  default = "no"
}

variable "watson_knowledge_catalog" {
  type    = string
  default = "no"
}

variable "watson_studio" {
  type    = string
  default = "no"
}

variable "watson_machine_learning" {
  type    = string
  default = "no"
}

variable "watson_ai_openscale" {
   type    = string
   default = "no"
}

variable "spss_modeler" {
  type    = string
  default = "no"
}

variable "cognos_dashboard_embedded" {
  type    = string
  default = "no"
}

variable "datastage" {
  type    = string
  default = "no"
}

variable "db2_warehouse" {
  type    = string
  default = "no"
}

variable "db2_oltp" {
  type    = string
  default = "no"
}

variable "cognos_analytics" {
  type    = string
  default = "no"
}

variable "data_management_console" {
  type    = string
  default = "no"
}

variable "master_data_management" {
  type    = string
  default = "no"
}

variable "db2_aaservice" {
  type   = string
  default = "no"
}

variable "decision_optimization" {
   type    = string
  default = "no"
}

variable "planning_analytics" {
  type    = string
  default = "no"
}

variable "bigsql" {
  type    = string
  default = "no"
}

variable "watson_discovery" {
  type    = string
  default = "no"
}

variable "openpages" {
  type    = string
  default = "no"
}

variable "watson_assistant" {
  type    = string
  default = "no"
}

#Only required for dev

variable "configure_global_pull_secret" {
  type        = bool
  description = "Configuring global pull secret"
  default     = true
}

variable "cpd_staging_registry" {
  description = "URL to staging  registry for CPD install"
  default     = "cp.stg.icr.io"
}

variable "cpd_staging_username" {
  description = "staging registry  username for CPD install"
  default     = "cp"
}

variable "cpd_staging_api_key" {
  description = "Staging repository APIKey or registry password"
}


variable "hyc_cloud_private_registry" {
  description = "URL to hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com registry for CPD install"
  default     = "hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com"
}

variable "hyc_cloud_private_username" {
  description = "hyc_cloud_private username for CPD install"
  default     = "shankar.pentyala@ibm.com"
}

variable "hyc_cloud_private_api_key" {
  description = "hyc_cloud_private Repository APIKey or Registry password"
}

variable "github_ibm_username" {
  description = "username for github.ibm.com"
  default     = "shankar.pentyala@ibm.com"
}

variable "github_ibm_pat" {
  description = "Github IBM Repository personal Access Token"
}

variable "openpages" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "8.204.2"
    channel  = "v1.0"
  }
}

variable "watson_assistant" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v4.0"
  }
}

variable "watson_discovery" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v4.0"
  }
}
