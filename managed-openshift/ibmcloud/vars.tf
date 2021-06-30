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
  description = "I have read and agree to the license terms for IBM Cloud Pak for Data at https://ibm.biz/BdfEkc [yes/no]"
  
  # validation {
  #   condition = var.accept_cpd_license == "yes"
  #   error_message = "You must read and agree to the license terms for IBM Cloud Pak for Data to proceed."
  # }
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
variable "artifactory_username" {
  description = "artifactory username"
}
variable "artifactory_apikey" {
  description = "artifactory apikey"
}
variable "entitlement_user" {
  description = "entitlement username"
}
variable "entitlement_key" {
  description = "entitlement key"
}
variable "gituser" {
  description = "git user"
}
variable "git_token" {
  description = "git token"
}
variable "gituser_short" {
  description = "git user short name"
}
###############################################
# Cloud Pak for Data application configuration
###############################################
variable "cpd_project_name" {
  description = "Name of the project (namespace) in which CP4D will be installed"
  default = "zen"
}

variable "install_services" {
  type = map
  description = "Choose the Cloud Pak for Data services to be installed"
  default = {
    ccs                = false,
    data-refinery      = false, # Data refinery
    db2uoperator       = false,
    dmc                = false,
    db2aaservice       = false,
    spark              = false, # Analytics Engine powered by Apache Spark
    dv                 = false, # Data Virtualization
    wkc                = false, # Watson Knowledge Catalog
    wsl                = false, # Watson Studio
    wml                = false, # Watson Machine Learning
    aiopenscale        = false, # Watson OpenScale
    cde                = false, # Cognos Dashboard Engine
    streams            = false, # Streams
    ds                 = false, # DataStage
    dmc                = false, # Db2 Data Management Console
    db2wh              = false, # Db2 Warehouse
    db2oltp            = false, # Db2
    datagate           = false, # Db2 Data Gate
    dods               = false, # Decision Optimization
    ca                 = false, # Cognos Analytics
    spss-modeler       = false, # SPSS Modeler
    big-sql            = false, # Db2 Big SQL
    rstudio            = false, # Watson Studio Local RStudio
    hadoop-addon       = false, # Hadoop Execution Addon
    # mongodb            = false, # MongoDB Enterprise
    runtime-addon-py37 = false, # Jupyter Python 3.7 Runtime Addon
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
  default = "4.6_openshift"
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
