variable "login_string" {
  type = string
  default = "na"
}

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

variable "cluster_type" {
  type = string
}


variable "configure_global_pull_secret" {
  type        = bool
  description = "Configuring global pull secret"
  default     = false
}

variable "configure_openshift_nodes" {
  type        = bool
  description = "Setting machineconfig parameters on worker nodes"
  default     = true
}

variable "installer_workspace" {
  type        = string
  description = "Folder find the installation files"
  default     = ""
}

variable "accept_cpd_license" {
  description = "Read and accept license at https://ibm.biz/Bdq6KP, (accept / reject)"
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
  default = "zen"
}

variable "storage_option" {
  type = string
}

variable "cpd_storageclass" {
  type = map(any)

  default = {
    "portworx" = "portworx-shared-gp3"
    "ocs"      = "ocs-storagecluster-cephfs"
    "nfs"      = "nfs-client"
    "efs"      = "aws-efs-csi"
  }
}

variable "rwo_cpd_storageclass" {
  type = map(any)

  default = {
    "portworx" = "portworx-metastoredb-sc"
    "ocs"      = "ocs-storagecluster-ceph-rbd"
    "nfs"      = "nfs-client"
    "efs"      = "aws-efs-csi"
  }
}

variable "wkc_storageclass" {
  type = map(any)

  default = {
    "portworx" = "portworx-shared-gp3"
    "ocs"      = "ocs-storagecluster-cephfs"
    "nfs"      = "nfs"
    "efs"      = "aws-efs-csi-wkc"
  }
}

variable "wd_storageclass" {
  type = map(any)

  default = {
    "portworx" = "portworx-db-gp2-sc"
    "ocs"      = "ocs-storagecluster-ceph-rbd"
    "nfs"      = "nfs"
    "efs"      = "aws-efs-csi"
  }
}

variable "wa_storageclass" {
  type = map(any)

  default = {
    "portworx" = "portworx-watson-assistant-sc"
    "ocs"      = "ocs-storagecluster-cephfs"
    "nfs"      = "nfs"
    "efs"      = "aws-efs-csi"
  }
}



variable "cpd_version" {
  type    = string
  default = "4.0.4"
}

###########

variable "cloudctl_version" {
  default = "v3.7.1"
}

variable "datacore_version" {
  default = "1.3.3"
}

variable "cpd_platform" {
  type        = map(string)
  default = {
    enable   = "yes"
    version  = "4.0.5"
    channel  = "v2.0"
  }
}

variable "data_virtualization" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "1.7.5"
    channel  = "v1.7"
  }
}

variable "analytics_engine" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "stable-v1"
  }
}

variable "watson_knowledge_catalog" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v1.0"
  }
}

variable "watson_studio" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v2.0"
  }
}

variable "watson_machine_learning" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v1.1"
  }
}

variable "watson_ai_openscale" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v1"
  }
}

variable "spss_modeler" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v1.0"
  }
}

variable "cognos_dashboard_embedded" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v1.0"
  }
}

variable "datastage" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v1.0"
  }
}

variable "db2_warehouse" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.7"
    channel  = "v1.0"
  }
}

variable "db2_oltp" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.7"
    channel  = "v1.0"
  }
}

variable "cognos_analytics" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v4.0"
  }
}

variable "data_management_console" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v1.0"
  }
}

variable "master_data_management" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "1.1.175"
    channel  = "v1.1"
  }
}

variable "db2_aaservice" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v1.0"
  }
}

variable "decision_optimization" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v4.0"
  }
}

variable "db2u_catalog_source" {
  default = "docker.io/ibmcom/ibm-db2uoperator-catalog:latest"
}

variable "planning_analytics" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "4.0.5"
    channel  = "v4.0"
  }
}

variable "bigsql" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "7.2.5"
    channel  = "v7.2"
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

variable "wa_kafka_storage_class" {
  type        = map(any)

  default = {
    "portworx" = ""
    "ocs"      = "ocs-storagecluster-ceph-rbd"
    "nfs"      = "nfs"
    "efs"      = "aws-efs-csi"
  }
}

variable "wa_storage_size" {
  type        = map(any)

  default = {
    "portworx" = ""
    "ocs"      = "55Gi"
    "nfs"      = ""
    "efs"      = ""
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

variable "openpages" {
  type        = map(string)
  default = {
    enable   = "no"
    version  = "8.204.2"
    channel  = "v1.0"
  }
}


#Only required for dev
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
