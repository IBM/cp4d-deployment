##############################
# Install Bedrock Zen Operator
#############################


resource "null_resource" "bedrock_zen_operator" {
  count = var.accept_cpd_license == "yes" ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      ENTITLEMENT_USER = var.entitlement_user
      ENTITLEMENT_KEY = var.entitlement_key
      CLUSTER_NAME = "${var.unique_id}-cluster"
      IBMCLOUD_APIKEY = var.ibmcloud_api_key
      IBMCLOUD_RG_NAME = var.resource_group_name
      REGION = var.region
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_bedrock_zen_operator.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
  ]
}

resource "null_resource" "install_ccs" {
  count = var.accept_cpd_license == "yes" && var.install_services["ccs"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      ARTIFACTORY_USERNAME = var.artifactory_username
      ARTIFACTORY_APIKEY = var.artifactory_apikey
      CLUSTER_NAME = "${var.unique_id}-cluster"
      GIT_TOKEN = var.git_token
      GITUSER_SHORT = var.gituser_short
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_ccs.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
  ]
}

resource "null_resource" "install_wsl" {
  count = var.accept_cpd_license == "yes" && var.install_services["wsl"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      ARTIFACTORY_USERNAME = var.artifactory_username
      ARTIFACTORY_APIKEY = var.artifactory_apikey
      CLUSTER_NAME = "${var.unique_id}-cluster"
      GITUSER = var.gituser
      GIT_TOKEN = var.git_token
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_wsl.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_ccs,
  ]
}

resource "null_resource" "install_aiopenscale" {
  count = var.accept_cpd_license == "yes" && var.install_services["aiopenscale"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      ARTIFACTORY_USERNAME = var.artifactory_username
      ARTIFACTORY_APIKEY = var.artifactory_apikey
      CLUSTER_NAME = "${var.unique_id}-cluster"
      GITUSER = var.gituser
      GIT_TOKEN = var.git_token
      GITUSER_SHORT = var.gituser_short
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-aiopenscale.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_ccs,
    null_resource.install_wsl,
  ]
}

resource "null_resource" "install_wml" {
  count = var.accept_cpd_license == "yes" && var.install_services["wml"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      ARTIFACTORY_USERNAME = var.artifactory_username
      ARTIFACTORY_APIKEY = var.artifactory_apikey
      CLUSTER_NAME = "${var.unique_id}-cluster"
      GITUSER = var.gituser
      GIT_TOKEN = var.git_token
      GITUSER_SHORT = var.gituser_short
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-wml.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_ccs,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
  ]
}

resource "null_resource" "install_wkc" {
  count = var.accept_cpd_license == "yes" && var.install_services["wkc"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      ARTIFACTORY_USERNAME = var.artifactory_username
      ARTIFACTORY_APIKEY = var.artifactory_apikey
      CLUSTER_NAME = "${var.unique_id}-cluster"
      GITUSER = var.gituser
      GIT_TOKEN = var.git_token
      GITUSER_SHORT = var.gituser_short
      NAMESPACE = var.cpd_project_name
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-wkc.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_ccs,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
  ]
}