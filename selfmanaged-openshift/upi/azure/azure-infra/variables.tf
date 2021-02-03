## Azure Auth
variable "azure-subscription-id" {
}

variable "azure-client-id" {
}

variable "azure-client-secret" {
}

variable "azure-tenant-id" {
}

variable "azure-sp-name" {
  default = "ocpsp"
}

variable "region" {
  default = "eastus"
}

variable "resource-group" {
  default = "mycpd-rg"
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
  default = "10.11.0.0/16"
}

variable "bootnode-subnet-name" {
  default = "bootnode-subnet"
}

variable "bootnode-subnet-cidr" {
  default = "10.11.3.0/24"
}

variable "bootnode-source-cidr" {
  default = "0.0.0.0/0"
}

variable "master-subnet-name" {
  default = "master-subnet"
}

variable "cluster-cidr" {
  default = "10.0.0.0/16"
}
variable "master-subnet-cidr" {
  default = "10.0.0.0/24"
}

variable "worker-subnet-name" {
  default = "worker-subnet"
}

variable "worker-subnet-cidr" {
  default = "10.0.1.0/24"
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
  default = "nfs"
}
# variable "portworx-spec-url" {
#   default = ""
# }
variable "storage-disk-size" {
  default = 1024
}
# variable "enableNFSBackup" {
#   default = "no"
# }

# Disconnected install - variable declaration. 

variable "disconnected-cluster" {
  default = "no"
}

variable "certificate-file-path" {
  default = ""
}


variable "local-registry-username" {
  default = ""
}

variable "local-registry-pwd" {
  default = ""
}
variable "local-registry-repository" {
  default = ""
}

variable "local-registry" {
  default = ""
}

variable "local-repository" {
  default = "ocp4/openshift4"
}

variable "architecture" {
  default = "x86_64"
}
variable "mirror-node-resource-group" {
  default = ""
}

variable "mirror-node-vnet-name" {
  default = ""
}

variable "mirror-node-vnet-id" {
  default = ""
}

variable "pull-secret-json-path" {
  default = ""
}

variable "cpdservices-to-install" {
  description = "lite,dv,spark,wkc,wsl,wml,aiopenscale,cde,streams,streams-flows,ds,db2wh,db2oltp,dmc,datagate,dods,ca,spss-modeler,big-sql,pa"
  default     = "lite"
}
# Openshift namespace/project to deploy cloud pak into
variable "cpd-namespace" {
  default = "zen"
}

variable "ocp-version" {
  default = "4.5.18"
}

variable "cpd-version" {
  default = "latest"
}

variable "cloudctl_version" {
  default = "v3.6.0"
}

variable "cpd-cli-version" {
  default = "v3.5.0"
}

variable "apikey" {
}

# Add-Ons
variable "data-virtualization" {
  default = "no"
}

variable "watson-studio-library" {
  default = "no"
}

variable "watson-knowledge-catalog" {
  default = "no"
}

variable "watson-ai-openscale" {
  default = "no"
}

variable "watson-machine-learning" {
  default = "no"
}

variable "cognos-dashboard-embedded" {
  default = "no"
}

variable "apache-spark" {
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

variable "db2_warehouse" {
  default = "no"
}

variable "db2_oltp" {
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

variable "spss" {
  default = "no"
}

variable "bigsql" {
  default = "no"
}

variable "planning-analytics" {
  default = "no"
}

# variable "watson-assistant"{
#   default = "no"
# }

# variable "watson-discovery"{
#   default = "no"
# }

variable "accept-cpd-license" {
  description = "Read and accept license at https://ibm.biz/BdqSw4"
  default     = "reject"
}