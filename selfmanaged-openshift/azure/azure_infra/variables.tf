## Azure Auth
variable "azure-subscription-id" {

}

variable "azure-client-id" {

}

variable "azure-client-secret" {

}

variable "azure-tenant-id" {

}

variable "region" {
  default = "centralus"
}

variable "resource-group" {

}

variable "existing-resource-group" {
  default = "no"
}

variable "cluster-name" {

}

# Resource group the DNS group was created in
variable "dnszone-resource-group" {
}

# DNS Zone created in Step 1 of the Readme
variable "dnszone" {
}

variable "admin-username" {
  default = "core"
}

### Network Config
variable "new-or-existing" {
  default = "new"
}

variable "existing-vnet-resource-group" {
  default = "vnet-rg"
}

variable "virtual-network-name" {
  default = "ocpfourx-vnet"
}

variable "virtual-network-cidr" {
  default = "10.0.0.0/16"
}


variable "master-subnet-name" {
  default = "master-subnet"
}

variable "master-subnet-cidr" {
  default = "10.0.1.0/24"
}

variable "worker-subnet-name" {
  default = "worker-subnet"
}

variable "worker-subnet-cidr" {
  default = "10.0.2.0/24"
}

# Deploy OCP into single or multi-zone
variable "single-or-multi-zone" {
  default = "single"
}

# Applicable only if deploying in a single zone
variable "zone" {
  default = 1
}

variable "master-node-count" {
  default = 3
}

variable "worker-node-count" {
  default = 3
}


variable "master-instance-type" {
  default = "Standard_D8s_v3"
}

variable "worker-instance-type" {
  default = "Standard_D16s_v3"
}

variable "pull-secret-file-path" {
}

variable "fips" {
  default = false
}

variable "clusterAutoscaler" {
  default = "no"
}

variable "openshift-username" {
  default = "ocadmin"
}

variable "openshift-password" {
}

variable "openshift_api" {
  type    = string
  default = ""
}

variable "ssh-public-key" {

}

# Internet facing endpoints
variable "private-or-public-cluster" {
  default = "public"
}

variable "storage" {
  default = "nfs"
}

variable "portworx-spec-url" {
  default = ""
}

variable "portworx-encryption" {
  default = "no"
}

variable "portworx-encryption-key" {
  default = ""
}

variable "storage-disk-size" {
  default = 1024
}

variable "enableNFSBackup" {
  default = "no"
}

# Openshift namespace/project to deploy cloud pak into

variable "cpd-external-registry" {
  description = "URL to external registry for CPD install. Note: CPD images must already exist in the repo"
  default     = "cp.icr.io"
}

variable "cpd-external-username" {
  description = "URL to external username for CPD install. Note: CPD images must already exist in the repo"
  default     = "cp"
}
variable "ocp_version" {
  default = "4.10.15"
}

variable "openshift_installer_url_prefix" {
  type    = string
  default = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp"
}

variable "apikey" {
}

variable "accept-cpd-license" {
  description = "Read and accept license at https://ibm.biz/BdqSw4"
  default     = "reject"
}

variable "cpd_version" {
  type    = string
  default = "4.5.0"
}

##############################
### CPD4.0 variables
##############################

variable "cpd-namespace" {
  default = "zen"
}

variable "operator-namespace" {
  default = "ibm-common-services"
}

variable "cpd_storageclass" {
  type = map(any)

  default = {
    "portworx" = "portworx-shared-gp3"
    "ocs"      = "ocs-storagecluster-cephfs"
    "nfs"      = "nfs"
  }
}

variable "rwo_cpd_storageclass" {
  type = map(any)

  default = {
    "portworx" = "portworx-db2-rwo-sc"
    "ocs"      = "ocs-storagecluster-ceph-rbd"
    "nfs"      = "nfs"
  }
}
############################################
# CPD 4.0 service variables 
###########################################
variable "cpd_platform" {
  type = string
  default = "yes"
}

variable "data_virtualization" {
  type = string
  default = "no"
}

variable "analytics_engine" {
  type = string
  default = "no"
}

variable "watson_knowledge_catalog" {
  type = string
  default = "no"
}

variable "watson_studio" {
  type = string
  default = "no"
}

variable "watson_machine_learning" {
  type = string
  default = "no"
}

variable "watson_ai_openscale" {
  type = string
  default = "no"
}

variable "spss_modeler" {
  type = string
  default = "no"
}

variable "cognos_dashboard_embedded" {
  type = string
  default = "no"
}

variable "datastage" {
  type = string
  default = "no"
}

variable "db2_warehouse" {
  type = string
  default = "no"
}

variable "db2_oltp" {
  type = string
  default = "no"
}

variable "cognos_analytics" {
  type = string
  default = "no"
}

variable "data_management_console" {
  type = string
  default = "no"
}

variable "master_data_management" {
  type = string
  default = "no"
}

variable "db2_aaservice" {
  type = string
  default = "no"
}

variable "decision_optimization" {
  type = string
  default = "no"
}

variable "bigsql" {
  type = string
  default = "no"
}

variable "openpages" {
  type = string
  default = "no"
}

variable "watson_discovery" {
  type = string
  default = "no"
}

variable "planning_analytics" {
  type = string
  default = "no"
}
