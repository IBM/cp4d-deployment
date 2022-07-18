variable "openshift_api" {
  type    = string
  default = ""
}

variable "openshift_username" {
  type    = string
  default = ""
}

variable "openshift_password" {
  type    = string
  default = ""
}

variable "openshift_token" {
  type        = string
  description = "For cases where you don't have the password but a token can be generated (e.g SSO is being used)"
  default     = ""
}

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

variable "installer_workspace" {
  type        = string
  description = "Folder find the installation files"
  default     = "install"
}

variable "accept_cpd_license" {
  description = "Read and accept license at https://ibm.biz/Bdq6KP, (accept / reject)"
  default     = "accept"
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
  default = "zen"
}

variable "storage_option" {
  type = string
}

variable "cluster_type" {
  default = ""
}

variable "cpd_storageclass" {
  type = map(any)

  default = {
    "portworx" = "portworx-shared-gp3"
    "ocs"      = "ocs-storagecluster-cephfs"
    "nfs"      = "nfs"
    "efs"      = "nfs-client"
  }
}

variable "rwo_cpd_storageclass" {
  type = map(any)

  default = {
    "portworx" = "portworx-metastoredb-sc"
    "ocs"      = "ocs-storagecluster-ceph-rbd"
    "nfs"      = "nfs"
    "efs"      = "gp3-csi"
  }
}

variable "cpd_version" {
  type    = string
  default = "4.5.0"
}

###########

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

variable "watson_assistant" {
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

variable "accept-cpd-license" {
  default = "reject"
}
