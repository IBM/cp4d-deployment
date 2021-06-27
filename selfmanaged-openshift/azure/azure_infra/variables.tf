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
  default = "eastus"
}

variable "resource-group" {
  default = "mycpd-rg"
}

variable "existing-resource-group" {
  default = "no"
}

variable "cluster-name" {
  default = "myocp-cluster"
}

# Resource group the DNS group was created in
variable "dnszone-resource-group" {
}

# DNS Zone created in Step 1 of the Readme
variable "dnszone" {
}

variable "privateBootnode" {
  default = "no"
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

variable "bootnode-subnet-name" {
  default = "bootnode-subnet"
}

variable "bootnode-subnet-cidr" {
  default = "10.0.3.0/24"
}

variable "bootnode-source-cidr" {
  default = "0.0.0.0/0"
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
  default = "multi"
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

variable "bootnode-instance-type" {
  default = "Standard_D8s_v3"
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
  default = true
}

variable "clusterAutoscaler" {
  default = "no"
}

# Username for the bootnode VM
variable "admin-username" {
  default = "core"
}

variable "openshift-username" {
}

variable "openshift-password" {
}

variable "ssh-public-key" {
}

variable "ssh-private-key-file-path" {
}

# Internet facing endpoints
variable "private-or-public-cluster" {
  default = "public"
}

variable "storage" {
  default = "portworx"
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

variable "cp-storageclass" {
  type = map

  default = {
    "portworx" = "portworx-shared-gp3"
    "ocs"      = "ocs-storagecluster-cephfs"
    "nfs"      = "nfs"
  }
}

# StorageClass Streams
variable "streams-storageclass" {
  type = map

  default = {
    "portworx" = "portworx-shared-gp-allow"
    "ocs"      = "ocs-storagecluster-cephfs"
    "nfs"      = "nfs"
  }
}

# StorageClass BigSQL
variable "bigsql-storageclass" {
  type = map

  default = {
    "portworx" = "portworx-dv-shared-gp3"
    "ocs"      = "ocs-storagecluster-cephfs"
    "nfs"      = "nfs"
  }
}

variable "enableNFSBackup" {
  default = "no"
}

# Openshift namespace/project to deploy cloud pak into

variable "cpd-external-registry" {
  description = "URL to external registry for CPD install. Note: CPD images must already exist in the repo"
  default     = ""
}

variable "cpd-external-username" {
  description = "URL to external username for CPD install. Note: CPD images must already exist in the repo"
  default     = ""
}
variable "ocp_version" {
  default = "4.6.30"
}

variable "cpd-version" {
  default = "latest"
}

variable "cloudctl_version" {
  default = "latest"
}

variable "apikey" {
}

variable "accept-cpd-license" {
  description = "Read and accept license at https://ibm.biz/BdqSw4"
  default     = "reject"
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

variable "cpd-storageclass" {
  type = map

  default = {
    "portworx" = "portworx-shared-gp3"
    "nfs"      = "nfs"
  }
}

variable "ccs-storageclass-value" {
  type = map

  default = {
    "portworx" = "storageVendor: portworx"
    "nfs"      = "storageClass: nfs"
  }
}

############################################
# CPD 4.0 service variables 
###########################################

variable "cpd-platform-operator" {
  default = "no"
}

variable "ccs" {
  default = "no"
}

variable "data-refinery" {
  default = "no"
}

variable "db2uoperator" {
  default = "no"
}


variable "dmc" {
  default = "no"
}

variable "db2aaservice" {
  default = "no"
}

variable "wsl" {
  default = "no"
}

variable "aiopenscale" {
  default = "no"
}

variable "spss" {
  default = "no"
}

variable "wml" {
  default = "no"
}

variable "cde" {
  default = "no"
}

variable "dods" {
  default = "no"
}

variable "spark" {
  default = "no"
}

variable "dv" {
  default = "no"
}

variable "bigsql" {
  default = "no"
}

variable "wkc" {
  default = "no"
}

variable "ca" {
  default = "no"
}

variable "ds" {
  default = "no"
}

variable "db2oltp" {
  default = "no"
}

variable "db2wh" {
  default = "no"
} 