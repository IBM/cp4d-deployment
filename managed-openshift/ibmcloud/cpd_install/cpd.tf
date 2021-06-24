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
    "lite"               = "portworx-shared-gp3",
    "dv"                 = "portworx-shared-gp3",
    "spark"              = "portworx-shared-gp3",
    "wkc"                = "portworx-shared-gp3",
    "wsl"                = "portworx-shared-gp3",
    "wml"                = "portworx-shared-gp3",
    "aiopenscale"        = "portworx-shared-gp3",
    "cde"                = "portworx-shared-gp3",
    "streams"            = "portworx-shared-gp-allow",
    "ds"                 = "portworx-shared-gp3",
    "dmc"                = "portworx-shared-gp3",
    "db2wh"              = "portworx-shared-gp3",
    "db2oltp"            = "portworx-shared-gp3",
    "datagate"           = "portworx-db2-rwx-sc",
    "dods"               = "portworx-shared-gp3",
    "ca"                 = "portworx-shared-gp3",
    "spss-modeler"       = "portworx-shared-gp3",
    "big-sql"            = "portworx-shared-gp3",
    "rstudio"            = "portworx-shared-gp3",
    "hadoop-addon"       = "portworx-shared-gp3",
    "mongodb"            = "portworx-shared-gp3",
    "runtime-addon-py37" = "portworx-shared-gp3",

  }
  override = {
    "lite"               = "portworx",
    "dv"                 = "portworx",
    "spark"              = "portworx",
    "wkc"                = "portworx",
    "wsl"                = "portworx",
    "wml"                = "portworx",
    "aiopenscale"        = "portworx",
    "cde"                = "portworx",
    "streams"            = "portworx",
    "ds"                 = "portworx",
    "dmc"                = "portworx",
    "db2wh"              = "",
    "db2oltp"            = "",
    "datagate"           = "portworx",
    "dods"               = "portworx",
    "ca"                 = "portworx",
    "spss-modeler"       = "portworx",
    "big-sql"            = "portworx",
    "rstudio"            = "portworx",
    "hadoop-addon"       = "portworx",
    "mongodb"            = "portworx",
    "runtime-addon-py37" = "portworx",
    # "runtime-addon-r36"  = "portworx",
  }
}

# Install base
resource "null_resource" "install_lite" {
  count = var.accept_cpd_license == "yes" ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "oc new-project ${var.cpd_project_name}; ./install_cpdservice_generic.sh ${var.cpd_project_name} lite ${local.storageclass["lite"]} ${local.override["lite"]}"
  }

  depends_on = [
    null_resource.install_cpd_operator
  ]
}

# Reencrypt route
resource "null_resource" "reencrypt_route" {
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./reencrypt_route.sh ${var.cpd_project_name}"
  }

  depends_on = [
    null_resource.install_lite
  ]
}


# Install services

resource "null_resource" "install_spark" {
  count = var.accept_cpd_license == "yes" && var.install_services["spark"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} spark ${local.storageclass["spark"]} ${local.override["spark"]}"
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
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} dv ${local.storageclass["dv"]} ${local.override["dv"]}"
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
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} wkc ${local.storageclass["wkc"]} ${local.override["wkc"]}"
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
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} wsl ${local.storageclass["wsl"]} ${local.override["wsl"]}"
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
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} wml ${local.storageclass["wml"]} ${local.override["wml"]}"
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
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} aiopenscale ${local.storageclass["aiopenscale"]} ${local.override["aiopenscale"]}"
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
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} cde ${local.storageclass["cde"]} ${local.override["cde"]}"
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
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} streams ${local.storageclass["streams"]} ${local.override["streams"]}"
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

resource "null_resource" "install_ds" {
  count = var.accept_cpd_license == "yes" && var.install_services["ds"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} ds ${local.storageclass["ds"]} ${local.override["ds"]}"
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

resource "null_resource" "install_dmc" {
  count = var.accept_cpd_license == "yes" && var.install_services["dmc"] ? 1 : 0
  
  provisioner "local-exec" {
<<<<<<< HEAD
=======
    environment = {
      ARTIFACTORY_USERNAME = var.artifactory_username
      ARTIFACTORY_APIKEY = var.artifactory_apikey
      CLUSTER_NAME = "${var.unique_id}-cluster"
      GITUSER = var.gituser
      GIT_TOKEN = var.git_token
      GITUSER_SHORT = var.gituser_short
    }
    
>>>>>>> parent of 0c41a87... wkc changes
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} dmc ${local.storageclass["dmc"]} ${local.override["dmc"]}"
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
    null_resource.install_ds,
  ]
}

resource "null_resource" "install_db2wh" {
  count = var.accept_cpd_license == "yes" && var.install_services["db2wh"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} db2wh ${local.storageclass["db2wh"]} ${local.override["db2wh"]}"
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
    null_resource.install_ds,
    null_resource.install_dmc,
  ]
}

resource "null_resource" "install_db2oltp" {
  count = var.accept_cpd_license == "yes" && var.install_services["db2oltp"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} db2oltp ${local.storageclass["db2oltp"]} ${local.override["db2oltp"]}"
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
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} datagate ${local.storageclass["datagate"]} ${local.override["datagate"]}"
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
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} dods ${local.storageclass["dods"]} ${local.override["dods"]}"
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
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} ca ${local.storageclass["ca"]} ${local.override["ca"]}"
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
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_datagate,
    null_resource.install_dods,
  ]
}

resource "null_resource" "install_spss" {
  count = var.accept_cpd_license == "yes" && var.install_services["spss-modeler"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} spss-modeler ${local.storageclass["spss-modeler"]} ${local.override["spss-modeler"]}"
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
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
  ]
}

resource "null_resource" "install_big_sql" {
  count = var.accept_cpd_license == "yes" && var.install_services["big-sql"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} big-sql ${local.storageclass["big-sql"]} ${local.override["big-sql"]}"
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
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_spss,
  ]
}

resource "null_resource" "install_rstudio" {
  count = var.accept_cpd_license == "yes" && var.install_services["rstudio"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} rstudio ${local.storageclass["rstudio"]} ${local.override["rstudio"]}"
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
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_spss,
    null_resource.install_big_sql,
  ]
}

resource "null_resource" "install_hadoop_addon" {
  count = var.accept_cpd_license == "yes" && var.install_services["hadoop-addon"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} hadoop-addon ${local.storageclass["hadoop-addon"]} ${local.override["hadoop-addon"]}"
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
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_spss,
    null_resource.install_big_sql,
    null_resource.install_rstudio,
  ]
}

# resource "null_resource" "install_mongodb" {
#   count = var.accept_cpd_license == "yes" && var.install_services["mongodb"] ? 1 : 0
#
#   provisioner "local-exec" {
#     working_dir = "${path.module}/scripts/"
#     interpreter = ["/bin/bash", "-c"]
#     command = "./install_cpdservice_generic.sh ${var.cpd_project_name} mongodb ${local.storageclass["mongodb"]} ${local.override["mongodb"]}"
#   }
#
#   depends_on = [
#     null_resource.install_lite,
#     null_resource.install_spark,
#     null_resource.install_dv,
#     null_resource.install_wkc,
#     null_resource.install_wsl,
#     null_resource.install_wml,
#     null_resource.install_aiopenscale,
#     null_resource.install_cde,
#     null_resource.install_streams,
#     null_resource.install_ds,
#     null_resource.install_dmc,
#     null_resource.install_db2wh,
#     null_resource.install_db2oltp,
#     null_resource.install_datagate,
#     null_resource.install_dods,
#     null_resource.install_ca,
#     null_resource.install_spss,
#     null_resource.install_big_sql,
#     null_resource.install_rstudio,
#     null_resource.install_hadoop_addon,
#   ]
# }

resource "null_resource" "install_runtime_addon_py37" {
  count = var.accept_cpd_license == "yes" && var.install_services["runtime-addon-py37"] ? 1 : 0
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_cpdservice_generic.sh ${var.cpd_project_name} runtime-addon-py37 ${local.storageclass["runtime-addon-py37"]} ${local.override["runtime-addon-py37"]}"
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
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_spss,
    null_resource.install_big_sql,
    null_resource.install_rstudio,
    null_resource.install_hadoop_addon,
    # null_resource.install_mongodb,
  ]
}


resource "null_resource" "setup_cpd_cli" {
  count = var.accept_cpd_license == "yes" && (var.install_services["watson-assistant"]) ? 1 : 0

  provisioner "local-exec" {
    environment = {
      # CPD_REGISTRY = var.cpd_registry,
      # CPD_REGISTRY_USER = var.cpd_registry_username,
      CPD_REGISTRY_PASSWORD = var.cpd_registry_password,
      # CPD_CASE_DIR = "../../" # point to templates root
      TEMPLATES_DIR = abspath(path.root)
    }

    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./setup_cpd_cli.sh"
  }
  provisioner "local-exec" {
    when = destroy
    interpreter = ["/bin/bash", "-c"]
    command = "rm -rf cpd-cli*"
  }
}

resource "null_resource" "install_watson_assistant" {
  count = var.accept_cpd_license == "yes" && var.install_services["watson-assistant"] ? 1 : 0

  provisioner "local-exec" {
    environment = {
      TEMPLATES_DIR = abspath(path.root)
    }

    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "./install_watson_assistant.sh ${var.cpd_project_name}"
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
    null_resource.install_ds,
    null_resource.install_dmc,
    null_resource.install_db2wh,
    null_resource.install_db2oltp,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_spss,
    null_resource.install_big_sql,
    null_resource.install_rstudio,
    null_resource.install_hadoop_addon,
    # null_resource.install_mongodb,
    null_resource.install_runtime_addon_py37,
    null_resource.setup_cpd_cli,
  ]
}
