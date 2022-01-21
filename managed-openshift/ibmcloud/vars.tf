##########################
# IBM Cloud configuration
##########################
variable "ibmcloud_api_key" {
  description = "IBM Cloud API key"
}

variable "region" {
  description = "IBM Cloud region where all resources will be deployed"
}

variable "resource_group_name" {
  description = "Name of the IBM Cloud resource group in which resources should be created"
  default     = "default"
}

variable "unique_id" {
  description = "Unique string for naming resources"
  default     = "cp4d-roks-tf"
}

###########################################
# Cloud Pak for Data license configuration
###########################################
variable "accept_cpd_license" {
  description = "Read and accept license at https://ibm.biz/Bdq6KP, (accept / reject)"
  default     = "reject"
}

variable "cpd_registry_username" {
  default = "cp"
}
variable "cpd_registry_password" {
  description = "Can be fetched from https://myibm.ibm.com/products-services/containerlibrary"
}
variable "cpd_registry" {
  default = "cp.icr.io/cp/cpd"
}
variable "operator_namespace" {
  default = "ibm-common-services"
}

variable "cloudctl_version" {
  default = "v3.8.0"
}

############################################
# CPD 4.0 service variables
###########################################

variable "cpd-namespace" {
  default = "zen"
}

variable "openshift-username" {
  default = "admin"
}

variable "openshift_api" {
  default = ""
}

variable "openshift_token" {
  default = ""
}

variable "cpd_storageclass" {
  default = "portworx"
}

variable "cpd_platform" {
  type = map(string)
  default = {
    enable  = "yes"
    version = "4.0.4"
    channel = "v2.0"
  }
}

variable "data_virtualization" {
  type = map(string)
  default = {
    enable  = "no"
    version = "1.7.2"
    channel = "v1.7"
  }
}

variable "analytics_engine" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.4"
    channel = "stable-v1"
  }
}

variable "watson_knowledge_catalog" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.4"
    channel = "v1.0"
  }
}

variable "watson_studio" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.4"
    channel = "v2.0"
  }
}

variable "watson_machine_learning" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.4"
    channel = "v1.1"
  }
}

variable "watson_ai_openscale" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.4"
    channel = "v1"
  }
}

variable "spss_modeler" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.4"
    channel = "v1.0"
  }
}

variable "cognos_dashboard_embedded" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.4"
    channel = "v1.0"
  }
}

variable "datastage" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.4"
    channel = "v1.0"
  }
}

variable "db2_warehouse" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.6"
    channel = "v1.0"
  }
}

variable "db2_oltp" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.6"
    channel = "v1.0"
  }
}

variable "cognos_analytics" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.4"
    channel = "v4.0"
  }
}

variable "data_management_console" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.3"
    channel = "v1.0"
  }
}

variable "master_data_management" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.4"
    channel = "v1.1"
  }
}

variable "db2_aaservice" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.6"
    channel = "v1.0"
  }
}

variable "decision_optimization" {
  type = map(string)
  default = {
    enable  = "no"
    version = "4.0.4"
    channel = "v4.0"
  }
}

####################
# VPC configuration
####################
variable "existing_vpc_id" {
  description = "ID of the VPC, if you wish to install CP4D in an existing VPC"
  default = null
}

variable "existing_vpc_subnets" {
  description = "List of subnet IDs in an existing VPC in which the cluster will be installed. Required when `existing_vpc_id` has been provided."
  default = null
}

variable "enable_public_gateway" {
  type = bool
  description = "Attach a public gateway to the worker node subnets? [true/false] Currently unsupported."
  default = true
}

variable "multizone" {
  type = bool
  description = "Create a multizone cluster spanning three zones? [true/false]"
  default = false
}

variable "allowed_cidr_range" {
  description = "List of IPv4 or IPv6 CIDR blocks that you want to allow access to your infrastructure. Currently unsupported."
  type = list
  default = ["0.0.0.0/0"]
}

variable "acl_rules" {
  description = "List of rules for the network ACL attached to every subnet. Refer to https://cloud.ibm.com/docs/terraform?topic=terraform-vpc-gen2-resources#network-acl-input for the format."
  default = [
    {
      name        = "egress"
      action      = "allow"
      source      = "0.0.0.0/0"
      destination = "0.0.0.0/0"
      direction   = "inbound"
    },
    {
      name        = "ingress"
      action      = "allow"
      source      = "0.0.0.0/0"
      destination = "0.0.0.0/0"
      direction   = "outbound"
    }
  ]
}

variable "zone_address_prefix_cidr" {
  description = "List of private IPv4 CIDR blocks for the address prefix of the VPC zones"
  default = [
    "10.240.0.0/18",
    "10.240.64.0/18",
    "10.240.128.0/18"
  ]
}

variable "subnet_ip_range_cidr" {
  description = "List of private IPv4 CIDR blocks for the subnets. Must be a subset of its respective 'zone_address_prefix_cidr' block."
  default = [
    "10.240.0.0/21",
    "10.240.64.0/21",
    "10.240.128.0/21"
  ]
}

#########################
# Portworx configuration
#########################
variable "storage_capacity"{
  description = "Storage capacity of the block volumes"
  default = 1000
}

variable "storage_profile" {
  description = "The storage profile for the block storage"
  default = "10iops-tier"
}

variable "storage_iops" {
  description = "The IOPS for the block storage. Only used for the 'custom' storage profile."
  default = 10000
}

variable "create_external_etcd" {
  description = "Create a 'Databases for etcd' service instance to keep Portworx metadata separate from the operational data of your cluster? [true/false]"
  default = true
}

#############################
# ROKS cluster configuration
#############################
variable "cos_instance_crn" {
  # Retrieve the CRN of an existing bucket using the ibmcloud CLI:
  # `ibmcloud resource service-instance $COS_INSTANCE_NAME --id | awk '{print $1}'`
  description = "OpenShift requires an object store to back up the internal registry of your cluster. You may supply an existing COS, or the module will create a new one."
  default = null
}

variable "existing_roks_cluster" {
  description = "ID or name of an existing OpenShift on IBM Cloud (VPC Gen 2) cluster, should you wish to install in an existing cluster."
  default = null
}

variable "disable_public_service_endpoint" {
  description = "Disable the ROKS public service endpoint? [true/false], Currently not supported"
  type = bool
  default = false
}

variable "entitlement" {
  description = "Set this argument to 'cloud_pak' only if you use the cluster with a Cloud Pak that has an OpenShift entitlement."
  default = "cloud_pak"
}

variable "kube_version" {
  default = "4.8_openshift"
}

variable "worker_node_flavor" {
  default = "bx2.16x64"
}

variable "worker_nodes_per_zone" {
  description = "Number of initial worker nodes per zone for the ROKS cluster. Select at least 3 for single zone and 2 for multizone clusters."
  default = "3"
}

variable "no_of_zones" {
  description = "Number of Zones for the ROKS cluster"
  default = "3"
}
