#######################
# Install CPD Operator
#######################
resource "null_resource" "install_cpd_operator" {
  count = var.accept_cpd_license == "yes" ? 1 : 0
  
  provisioner "local-exec" {
    environment = {
      CPD_REGISTRY = var.cpd_registry,
      CPD_REGISTRY_USER = var.cpd_registry_username,
      CPD_REGISTRY_PASSWORD = var.cpd_registry_password,
      CPD_CASE_DIR = "../../" # point to templates root
      NAMESPACE = "cpd-meta-ops"
    }
    
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpd_operator.sh"
  }
  
  depends_on = [
    var.portworx_is_ready,
    null_resource.prereqs_checkpoint,
  ]
}

#############################
# Install Cloud Pak for Data
#############################
locals {
  storageclass = {
    "lite"           = "portworx-shared-gp3",
    "dv"             = "portworx-shared-gp3",
    "spark"          = "portworx-shared-gp3",
    "wkc"            = "portworx-shared-gp3",
    "wsl"            = "portworx-shared-gp3",
    "wml"            = "portworx-shared-gp3",
    "aiopenscale"    = "portworx-shared-gp3",
    "cde"            = "portworx-shared-gp3",
    "streams"        = "portworx-shared-gp-allow",
    "streams-flows"  = "portworx-shared-gp3",
    "ds"             = "portworx-shared-gp3",
    "dmc"            = "portworx-shared-gp3",
    "db2wh"          = "portworx-shared-gp3",
    "db2oltp"        = "portworx-shared-gp3",
    "datagate"       = "portworx-db2-rwx-sc",
    "dods"           = "portworx-shared-gp3",
    "ca"             = "portworx-shared-gp3",
    "spss"           = "portworx-shared-gp3",
  }
}

# Install base
resource "null_resource" "install_lite" {
  count = var.accept_cpd_license == "yes" ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "oc new-project ${var.cpd_project_name}; ./install_cpdservice_generic.sh ${var.cpd_project_name} lite ${local.storageclass["lite"]}"
  }

  depends_on = [null_resource.install_cpd_operator]
}

# Reencrypt route
resource "null_resource" "reencrypt_route" {
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./reencrypt_route.sh ${var.cpd_project_name}"
  }

  depends_on = [null_resource.install_lite]
}


# Install services

resource "null_resource" "install_spark" {
  count = var.accept_cpd_license == "yes" && var.install_services["spark"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} spark ${local.storageclass["spark"]}"
  }

  depends_on = [
    null_resource.install_lite
  ]
}

resource "null_resource" "install_dv" {
  count = var.accept_cpd_license == "yes" && var.install_services["dv"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} dv ${local.storageclass["dv"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
  ]
}

resource "null_resource" "install_wkc" {
  count = var.accept_cpd_license == "yes" && var.install_services["wkc"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} wkc ${local.storageclass["wkc"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
  ]
}

resource "null_resource" "install_wsl" {
  count = var.accept_cpd_license == "yes" && var.install_services["wsl"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} wsl ${local.storageclass["wsl"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
  ]
}

resource "null_resource" "install_wml" {
  count = var.accept_cpd_license == "yes" && var.install_services["wml"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} wml ${local.storageclass["wml"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
  ]
}

resource "null_resource" "install_aiopenscale" {
  count = var.accept_cpd_license == "yes" && var.install_services["aiopenscale"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} aiopenscale ${local.storageclass["aiopenscale"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
  ]
}

resource "null_resource" "install_cde" {
  count = var.accept_cpd_license == "yes" && var.install_services["cde"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} cde ${local.storageclass["cde"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
  ]
}

resource "null_resource" "install_streams" {
  count = var.accept_cpd_license == "yes" && var.install_services["streams"] ? 1 : 0

  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} streams ${local.storageclass["streams"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
  ]
}

resource "null_resource" "install_streams_flows" {
  count = var.accept_cpd_license == "yes" && var.install_services["streams-flows"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} streams-flows ${local.storageclass["streams-flows"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
  ]
}

resource "null_resource" "install_ds" {
  count = var.accept_cpd_license == "yes" && var.install_services["ds"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} ds ${local.storageclass["ds"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
  ]
}

resource "null_resource" "install_dmc" {
  count = var.accept_cpd_license == "yes" && var.install_services["dmc"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} dmc ${local.storageclass["dmc"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
  ]
}

resource "null_resource" "install_db2wh" {
  count = var.accept_cpd_license == "yes" && var.install_services["db2wh"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} db2wh ${local.storageclass["db2wh"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_dmc,
  ]
}

resource "null_resource" "install_db2oltp" {
  count = var.accept_cpd_license == "yes" && var.install_services["db2oltp"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} db2oltp ${local.storageclass["db2oltp"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
  ]
}

resource "null_resource" "install_datagate" {
  count = var.accept_cpd_license == "yes" && var.install_services["datagate"] ? 1 : 0

  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} datagate ${local.storageclass["datagate"]}"
  }
  
  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
  ]
}

resource "null_resource" "install_dods" {
  count = var.accept_cpd_license == "yes" && var.install_services["dods"] ? 1 : 0

  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} dods ${local.storageclass["dods"]}"
  }
  
  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_datagate,
  ]
}

resource "null_resource" "install_ca" {
  count = var.accept_cpd_license == "yes" && var.install_services["ca"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} ca ${local.storageclass["ca"]}"
  }

  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_datagate,
    null_resource.install_dods,
  ]
}

resource "null_resource" "install_spss" {
  count = var.accept_cpd_license == "yes" && var.install_services["spss"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} spss ${local.storageclass["spss"]}"
  }
  
  depends_on = [
    null_resource.install_lite,
    null_resource.install_spark,
    null_resource.install_dv,
    null_resource.install_wkc,
    null_resource.install_wsl,
    null_resource.install_wml,
    null_resource.install_aiopenscale,
    null_resource.install_cde,
    null_resource.install_streams,
    null_resource.install_streams_flows,
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
  ]
}
