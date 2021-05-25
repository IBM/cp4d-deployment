##### AWS Configuration #####
variable "region" {
  description = "The region to deploy the cluster in, e.g: us-west-2."
  default     = "eu-west-2"
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

variable "vpcid" {
  description = "VPC ID of the network ROSA is deployed in. This is needed for setting the timeout for the LB and also for EFS (if chosen)"
  type = string
}

variable "openshift_api" {
  type = string
}

variable "openshift_username" {
  type = string
}

variable "openshift_password" {
  type = string
}

variable "openshift_token" {
  type        = string
  description = "For cases where you don't have the password but a token can be generated (e.g SSO is being used)"
}

variable "storage_option" {
  description = "portworx / ocs / efs"
  default     = "portworx"
}

#####################
# If using portworx
########################
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

#########################
# If using EFS
##########################
variable "efs_name" {
  default = "rosa-efs"
}

variable "vpc_cidr" {
  description = "VPC CIDR of the netwokr ROSA is deployed in"
  type = string
  default = ""
}

variable "subnets" {
  type = list
  description = "List of subnet ids for the compute nodes to set as mount targets"
  default = []
}
#############################

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