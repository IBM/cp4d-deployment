##### AWS Configuration #####
variable "region" {
  description = "The region to deploy the cluster in, e.g: us-west-2."
  default     = "eu-west-2"
}

variable "key_name" {
  description = "The name of the key to user for ssh access, e.g: consul-cluster"
  default     = "openshift-key"
}

variable "tenancy" {
  description = "Amazon EC2 instances tenancy type, default/dedicated"
  default     = "default"

  validation {
    condition     = var.tenancy == "default" || var.tenancy == "dedicated"
    error_message = "Amazon EC2 instances tenancy type can only default/dedicated."
  }
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

variable "new_or_existing_vpc_subnet" {
  description = "For existing VPC and SUBNETS use 'exist' otherwise use 'new' to create new VPC and SUBNETS, default is 'new' "
  default     = "new"

  validation {
    condition     = var.new_or_existing_vpc_subnet == "new" || var.new_or_existing_vpc_subnet == "exist"
    error_message = "For existing VPC and SUBNETS use 'exist' otherwise use 'new' to create new VPC and SUBNETS, default is 'new'."
  }
}

##############################
# New Network
##############################
variable "vpc_cidr" {
  description = "The CIDR block for the VPC, e.g: 10.0.0.0/16"
  default     = "10.0.0.0/16"
}

variable "master_subnet_cidr1" {
  default = "10.0.0.0/20"
}

variable "master_subnet_cidr2" {
  default = "10.0.16.0/20"
}

variable "master_subnet_cidr3" {
  default = "10.0.32.0/20"
}

variable "worker_subnet_cidr1" {
  default = "10.0.128.0/20"
}

variable "worker_subnet_cidr2" {
  default = "10.0.144.0/20"
}

variable "worker_subnet_cidr3" {
  default = "10.0.160.0/20"
}

##############################
# Existing Network       
##############################
variable "master_subnet1_id" {
  default = ""
}

variable "master_subnet2_id" {
  default = ""
}

variable "master_subnet3_id" {
  default = ""
}

variable "worker_subnet1_id" {
  default = ""
}

variable "worker_subnet2_id" {
  default = ""
}

variable "worker_subnet3_id" {
  default = ""
}
#############################

variable "cluster_name" {
  default = "my-ocp"
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

# Openshift Module Variables
variable "worker_instance_type" {
  type = string
  default = "m5.4xlarge"
}

variable "worker_instance_volume_iops" {
  type    = number
  default = 2000
}

variable "worker_instance_volume_size" {
  type    = number
  default = 300
}

variable "worker_instance_volume_type" {
  type    = string
  default = "io1"
}

variable "worker_replica_count" {
  type    = number
  default = 3
}

variable "master_instance_type" {
  type = string
  default = "m5.2xlarge"
}

variable "master_instance_volume_iops" {
  type    = number
  default = 4000
}

variable "master_instance_volume_size" {
  type    = number
  default = 300
}

variable "master_instance_volume_type" {
  type    = string
  default = "io1"
}

variable "master_replica_count" {
  type    = number
  default = 3
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

variable "private_cluster" {
  type        = bool
  description = "Endpoints should resolve to Private IPs"
}

variable "openshift_pull_secret_file_path" {
  type = string
}

variable "public_ssh_key" {
  type = string
}

variable "enable_fips" {
  type    = bool
  default = true
}

variable "base_domain" {
  type = string
}

variable "openshift_username" {
  type = string
}

variable "openshift_password" {
  type = string
}

/* variable "portworx_spec_url" {
  type = string
} */

variable "px_generated_cluster_id" {
  type = string
}

variable "storage_option" {
  description = "portworx / ocs / efs"
  default     = "portworx"
}

variable "enable_autoscaler" {
  type = bool
  default = false
}

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