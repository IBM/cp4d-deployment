##############################
# Install Bedrock Zen Operator
#############################


resource "null_resource" "bedrock_zen_operator" {
  count = var.accept_cpd_license == "yes" ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      ENTITLEMENT_USER = var.cpd_registry_username
      ENTITLEMENT_KEY = var.cpd_registry_password
      CLUSTER_NAME = "${var.unique_id}-cluster"
      IBMCLOUD_APIKEY = var.ibmcloud_api_key
      IBMCLOUD_RG_NAME = var.resource_group_name
      REGION = var.region
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-bedrock-zen-operator.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
  ]
}

resource "null_resource" "install_wsl" {
  count = var.accept_cpd_license == "yes" && var.install_services["wsl"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-wsl.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
  ]
}

resource "null_resource" "install_aiopenscale" {
  count = var.accept_cpd_license == "yes" && var.install_services["aiopenscale"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-aiopenscale.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
  ]
}

resource "null_resource" "install_wml" {
  count = var.accept_cpd_license == "yes" && var.install_services["wml"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-wml.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
  ]
}

resource "null_resource" "install_wkc" {
  count = var.accept_cpd_license == "yes" && var.install_services["wkc"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-wkc.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
  ]
}

resource "null_resource" "install_dv" {
  count = var.accept_cpd_license == "yes" && var.install_services["dv"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-dv.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wkc,
  ]
}

resource "null_resource" "install_spss" {
  count = var.accept_cpd_license == "yes" && var.install_services["spss-modeler"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-spss.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wkc,
    null_resource.install_dv,
  ]
}

resource "null_resource" "install_cde" {
  count = var.accept_cpd_license == "yes" && var.install_services["cde"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-cde.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_spss,
  ]
}

resource "null_resource" "install_spark" {
  count = var.accept_cpd_license == "yes" && var.install_services["spark"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-spark.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_spss,
    null_resource.install_cde,
  ]
}

resource "null_resource" "install_dods" {
  count = var.accept_cpd_license == "yes" && var.install_services["dods"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-dods.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_spss,
    null_resource.install_cde,
    null_resource.install_spark,
  ]
}

resource "null_resource" "install_ca" {
  count = var.accept_cpd_license == "yes" && var.install_services["ca"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-ca.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_spss,
    null_resource.install_cde,
    null_resource.install_spark,
    null_resource.install_dods,
  ]
}

resource "null_resource" "install_ds" {
  count = var.accept_cpd_license == "yes" && var.install_services["ds"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-ds.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_spss,
    null_resource.install_cde,
    null_resource.install_spark,
    null_resource.install_dods,
    null_resource.install_ca,
  ]
}

resource "null_resource" "install_db2oltp" {
  count = var.accept_cpd_license == "yes" && var.install_services["db2oltp"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-db2oltp.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_spss,
    null_resource.install_cde,
    null_resource.install_spark,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_ds,
  ]
}

resource "null_resource" "install_db2wh" {
  count = var.accept_cpd_license == "yes" && var.install_services["db2wh"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-db2wh.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_spss,
    null_resource.install_cde,
    null_resource.install_spark,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_ds,
    null_resource.install_db2oltp,
  ]
}

resource "null_resource" "install_bigsql" {
  count = var.accept_cpd_license == "yes" && var.install_services["big-sql"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-big-sql.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_spss,
    null_resource.install_cde,
    null_resource.install_spark,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_ds,
    null_resource.install_db2oltp,
    null_resource.install_db2wh,
  ]
}

resource "null_resource" "install_wsruntime" {
  count = var.accept_cpd_license == "yes" && var.install_services["runtime-addon-py37"] ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = "${var.unique_id}-cluster"
      NAMESPACE = var.cpd_project_name
      OP_NAMESPACE = var.operator_namespace
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install-wsruntime.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
    null_resource.bedrock_zen_operator,
    null_resource.install_wsl,
    null_resource.install_aiopenscale,
    null_resource.install_wml,
    null_resource.install_wkc,
    null_resource.install_dv,
    null_resource.install_spss,
    null_resource.install_cde,
    null_resource.install_spark,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_ds,
    null_resource.install_db2oltp,
    null_resource.install_db2wh,
    null_resource.install_bigsql,
  ]
}