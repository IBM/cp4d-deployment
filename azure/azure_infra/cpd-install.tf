locals {
    #General
    installerhome = "/home/${var.admin-username}/ibm"
    
    # Operator
    operator = "/home/${var.admin-username}/operator"

    # Override
    override-file = var.storage == "nfs" ? "\"\"" : base64encode(file("../cpd_module/portworx-override.yaml"))
    
    #Storage Classes
    storageclass = var.storage == "portworx" ? "portworx-shared-gp" : "nfs"
    dv-storageclass = var.storage == "portworx" ? "portworx-dv-shared-gp" : "nfs"
    cp-storageclass = var.storage == "portworx" ? "portworx-shared-gp3" : "nfs"
    streams-storageclass = var.storage == "portworx" ? "portworx-shared-gp-allow" : "nfs"
    watson-asst-storageclass = var.storage == "portworx" ? "portworx-assistant" : "managed-premium"
    watson-discovery-storageclass = var.storage == "portworx" ? "portworx-db-gp3" : "managed-premium"
}

resource "null_resource" "cpd_files" {
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
    }
    connection {
        type = "ssh"
        host = self.triggers.bootnode_ip_address
        user = self.triggers.username
        private_key = file(self.triggers.private_key_file_path)
    }
    provisioner "file" {
    source      = "../cpd_module/cpd-req-files.zip"
    destination = "/home/${var.admin-username}/cpd-req-files.zip"
  }
  depends_on = [
        null_resource.openshift_post_install,
    ]
}

resource "null_resource" "cpd_config" {
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
    }
    connection {
        type = "ssh"
        host = self.triggers.bootnode_ip_address
        user = self.triggers.username
        private_key = file(self.triggers.private_key_file_path)
    }
    provisioner "remote-exec" {
        inline = [
            #CPD Config
            "mkdir -p ${local.installerhome}",
            "mkdir -p ${local.operator}",
            "unzip /home/${var.admin-username}/cpd-req-files.zip",
            "sleep 5",
            "sudo mv cloudctl-linux-amd64.tar ${local.operator}",
            "sudo mv cloudctl-linux-amd64.tar.gz.sig ${local.operator}",
            "sudo mv ibm-cp-datacore-3.5.0.tar /home/${var.admin-username}/",
            
            "sudo tar -xvf ${local.operator}/cloudctl-linux-amd64.tar -C /usr/local/bin",
            "tar -xf /home/${var.admin-username}/ibm-cp-datacore-3.5.0.tar",
            "oc new-project cpd-meta-ops",
            "cat > install-cpd-operator.sh <<EOL\n${file("../cpd_module/install-cpd-operator.sh")}\nEOL",
            "sudo chmod +x install-cpd-operator.sh",
            "./install-cpd-operator.sh ${var.apikey} cpd-meta-ops",
            "sleep 5m",
            "oc new-project ${var.cpd-namespace}",
            "cat > wait-for-service-install.sh <<EOL\n${file("../cpd_module/wait-for-service-install.sh")}\nEOL",
            "sudo chmod +x wait-for-service-install.sh",
        ]
    }
    depends_on = [
        null_resource.openshift_post_install,
        null_resource.cpd_files,
        null_resource.install_portworx,
        null_resource.install_nfs_client,
    ]
}

resource "null_resource" "install_lite" {
    count = var.accept-cpd-license == "accept" ? 1 : 0
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
    }
    connection {
        type = "ssh"
        host = azurerm_public_ip.bootnode.ip_address
        user = var.admin-username
        private_key = file(self.triggers.private_key_file_path)
    }
    provisioner "remote-exec" {
        inline = [
            "cat > ${local.installerhome}/cpd-lite.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
            "sed -i -e s#SERVICE#lite#g ${local.installerhome}/cpd-lite.yaml",
            "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-lite.yaml",
            "oc create -f ${local.installerhome}/cpd-lite.yaml -n ${var.cpd-namespace}",
            "./wait-for-service-install.sh lite ${var.cpd-namespace}"
        ]
    }
    depends_on = [
        null_resource.cpd_config,
    ]
}

resource "null_resource" "install_dv" {
  count = var.data-virtualization == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
      bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
      username = var.admin-username
      private_key_file_path = var.ssh-private-key-file-path
      namespace = var.cpd-namespace
  }
  connection {
      type = "ssh"
      host = azurerm_public_ip.bootnode.ip_address
      user = var.admin-username
      private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
      inline = [
        "cat > ${local.installerhome}/cpd-dv.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
        "sed -i -e s#SERVICE#dv#g ${local.installerhome}/cpd-dv.yaml",
        "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-dv.yaml",
        "oc create -f ${local.installerhome}/cpd-dv.yaml -n ${var.cpd-namespace}",
        "./wait-for-service-install.sh dv ${var.cpd-namespace}",
      ]
    }
    depends_on = [
        null_resource.install_lite,
    ]
}

resource "null_resource" "install_spark" {
  count = var.apache-spark == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
      bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
      username = var.admin-username
      private_key_file_path = var.ssh-private-key-file-path
      namespace = var.cpd-namespace
  }
  connection {
      type = "ssh"
      host = azurerm_public_ip.bootnode.ip_address
      user = var.admin-username
      private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
      inline = [
        "cat > ${local.installerhome}/cpd-spark.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
        "sed -i -e s#SERVICE#spark#g ${local.installerhome}/cpd-spark.yaml",
        "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-spark.yaml",
        "oc create -f ${local.installerhome}/cpd-spark.yaml -n ${var.cpd-namespace}",
        "./wait-for-service-install.sh spark ${var.cpd-namespace}",
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
    ]
}

resource "null_resource" "install_wkc" {
  count = var.watson-knowledge-catalog == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
      bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
      username = var.admin-username
      private_key_file_path = var.ssh-private-key-file-path
      namespace = var.cpd-namespace
  }
  connection {
      type = "ssh"
      host = azurerm_public_ip.bootnode.ip_address
      user = var.admin-username
      private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
      inline = [
        "cat > ${local.installerhome}/cpd-wkc.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
        "sed -i -e s#SERVICE#wkc#g ${local.installerhome}/cpd-wkc.yaml",
        "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-wkc.yaml",
        "oc create -f ${local.installerhome}/cpd-wkc.yaml -n ${var.cpd-namespace}",
        "./wait-for-service-install.sh wkc ${var.cpd-namespace}",          
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
    ]
}

resource "null_resource" "install_wsl" {
  count = var.watson-studio-library == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
      bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
      username = var.admin-username
      private_key_file_path = var.ssh-private-key-file-path
      namespace = var.cpd-namespace
  }
  connection {
      type = "ssh"
      host = azurerm_public_ip.bootnode.ip_address
      user = var.admin-username
      private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
      inline = [
        "cat > ${local.installerhome}/cpd-wsl.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
        "sed -i -e s#SERVICE#wsl#g ${local.installerhome}/cpd-wsl.yaml",
        "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-wsl.yaml",
        "oc create -f ${local.installerhome}/cpd-wsl.yaml -n ${var.cpd-namespace}",
        "./wait-for-service-install.sh wsl ${var.cpd-namespace}",          
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
    ]
}

resource "null_resource" "install_wml" {
  count = var.watson-machine-learning == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
      bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
      username = var.admin-username
      private_key_file_path = var.ssh-private-key-file-path
      namespace = var.cpd-namespace
  }
  connection {
      type = "ssh"
      host = azurerm_public_ip.bootnode.ip_address
      user = var.admin-username
      private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
      inline = [
        "cat > ${local.installerhome}/cpd-wml.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
        "sed -i -e s#SERVICE#wml#g ${local.installerhome}/cpd-wml.yaml",
        "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-wml.yaml",
        "oc create -f ${local.installerhome}/cpd-wml.yaml -n ${var.cpd-namespace}",
        "./wait-for-service-install.sh wml ${var.cpd-namespace}",         
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
        null_resource.install_wsl,
    ]
}

resource "null_resource" "install_aiopenscale" {
  count = var.watson-ai-openscale == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
      bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
      username = var.admin-username
      private_key_file_path = var.ssh-private-key-file-path
      namespace = var.cpd-namespace
  }
  connection {
      type = "ssh"
      host = azurerm_public_ip.bootnode.ip_address
      user = var.admin-username
      private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
      inline = [
        "cat > ${local.installerhome}/cpd-aiopenscale.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
        "sed -i -e s#SERVICE#aiopenscale#g ${local.installerhome}/cpd-aiopenscale.yaml",
        "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-aiopenscale.yaml",
        "oc create -f ${local.installerhome}/cpd-aiopenscale.yaml -n ${var.cpd-namespace}",
        "./wait-for-service-install.sh aiopenscale ${var.cpd-namespace}",          
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
        null_resource.install_wsl,
        null_resource.install_wml,
    ]
}

resource "null_resource" "install_cde" {
  count = var.cognos-dashboard-embedded == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
      bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
      username = var.admin-username
      private_key_file_path = var.ssh-private-key-file-path
      namespace = var.cpd-namespace
  }
  connection {
      type = "ssh"
      host = azurerm_public_ip.bootnode.ip_address
      user = var.admin-username
      private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
      inline = [
        "cat > ${local.installerhome}/cpd-cde.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
        "sed -i -e s#SERVICE#cde#g ${local.installerhome}/cpd-cde.yaml",
        "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-cde.yaml",
        "oc create -f ${local.installerhome}/cpd-cde.yaml -n ${var.cpd-namespace}",
        "./wait-for-service-install.sh cde ${var.cpd-namespace}",           ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
        null_resource.install_wsl,
        null_resource.install_wml,
        null_resource.install_aiopenscale,
    ]
}

resource "null_resource" "install_streams" {
    count = var.streams == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
    triggers = {
      bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
      username = var.admin-username
      private_key_file_path = var.ssh-private-key-file-path
      namespace = var.cpd-namespace
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
            "cat > ${local.installerhome}/cpd-streams.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
            "sed -i -e s#SERVICE#streams#g ${local.installerhome}/cpd-streams.yaml",
            "sed -i -e s#STORAGECLASS#${local.streams-storageclass}#g ${local.installerhome}/cpd-streams.yaml",
            "oc create -f ${local.installerhome}/cpd-streams.yaml -n ${var.cpd-namespace}",
            "./wait-for-service-install.sh streams ${var.cpd-namespace}",
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
        null_resource.install_wsl,
        null_resource.install_wml,
        null_resource.install_aiopenscale,
        null_resource.install_cde,
    ]
}

resource "null_resource" "install_streams_flows" {
    count = var.streams-flows == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
            "cat > ${local.installerhome}/cpd-streams-flows.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
            "sed -i -e s#SERVICE#streams-flows#g ${local.installerhome}/cpd-streams-flows.yaml",
            "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-streams-flows.yaml",
            "oc create -f ${local.installerhome}/cpd-streams-flows.yaml -n ${var.cpd-namespace}",
            "./wait-for-service-install.sh streams-flows ${var.cpd-namespace}",           
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
        null_resource.install_wsl,
        null_resource.install_wml,
        null_resource.install_aiopenscale,
        null_resource.install_cde,
        null_resource.install_streams,
    ]
}

resource "null_resource" "install_ds" {
    count = var.datastage == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
            "cat > ${local.installerhome}/cpd-ds.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
            "sed -i -e s#SERVICE#ds#g ${local.installerhome}/cpd-ds.yaml",
            "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-ds.yaml",
            "oc create -f ${local.installerhome}/cpd-ds.yaml -n ${var.cpd-namespace}",
            "./wait-for-service-install.sh ds ${var.cpd-namespace}",           
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
        null_resource.install_wsl,
        null_resource.install_wml,
        null_resource.install_aiopenscale,
        null_resource.install_cde,
        null_resource.install_streams,
        null_resource.install_streams_flows,
    ]
}

resource "null_resource" "install_db2wh" {
    count = var.db2-warehouse == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
            "cat > ${local.installerhome}/cpd-db2wh.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
            "sed -i -e s#SERVICE#db2wh#g ${local.installerhome}/cpd-db2wh.yaml",
            "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-db2wh.yaml",
            "oc create -f ${local.installerhome}/cpd-db2wh.yaml -n ${var.cpd-namespace}",
            "./wait-for-service-install.sh db2wh ${var.cpd-namespace}",           
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
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

resource "null_resource" "install_db2oltp" {
    count = var.db2-advanced-edition == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
            "cat > ${local.installerhome}/cpd-db2oltp.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
            "sed -i -e s#SERVICE#db2oltp#g ${local.installerhome}/cpd-db2oltp.yaml",
            "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-db2oltp.yaml",
            "oc create -f ${local.installerhome}/cpd-db2oltp.yaml -n ${var.cpd-namespace}",
            "./wait-for-service-install.sh db2oltp ${var.cpd-namespace}",           
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
        null_resource.install_wsl,
        null_resource.install_wml,
        null_resource.install_aiopenscale,
        null_resource.install_cde,
        null_resource.install_streams,
        null_resource.install_streams_flows,
        null_resource.install_ds,
        null_resource.install_db2wh,
    ]
}

resource "null_resource" "install_datagate" {
    count = var.datagate == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
            "cat > ${local.installerhome}/cpd-datagate.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
            "sed -i -e s#SERVICE#datagate#g ${local.installerhome}/cpd-datagate.yaml",
            "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-datagate.yaml",
            "oc create -f ${local.installerhome}/cpd-datagate.yaml -n ${var.cpd-namespace}",
            "./wait-for-service-install.sh datagate ${var.cpd-namespace}",           
      ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
        null_resource.install_wsl,
        null_resource.install_wml,
        null_resource.install_aiopenscale,
        null_resource.install_cde,
        null_resource.install_streams,
        null_resource.install_streams_flows,
        null_resource.install_ds,
        null_resource.install_db2wh,
        null_resource.install_db2oltp,
    ]
}

resource "null_resource" "install_dods" {
    count = var.decision-optimization == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
            "cat > ${local.installerhome}/cpd-dods.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
            "sed -i -e s#SERVICE#dods#g ${local.installerhome}/cpd-dods.yaml",
            "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-dods.yaml",
            "oc create -f ${local.installerhome}/cpd-dods.yaml -n ${var.cpd-namespace}",
            "./wait-for-service-install.sh dods ${var.cpd-namespace}",           
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
        null_resource.install_wsl,
        null_resource.install_wml,
        null_resource.install_aiopenscale,
        null_resource.install_cde,
        null_resource.install_streams,
        null_resource.install_streams_flows,
        null_resource.install_ds,
        null_resource.install_db2wh,
        null_resource.install_db2oltp,
	null_resource.install_datagate,
    ]
}

resource "null_resource" "install_ca" {
    count = var.cognos-analytics == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
            "cat > ${local.installerhome}/cpd-ca.yaml <<EOL\n${data.template_file.cpd-service-ca.rendered}\nEOL",
            "sed -i -e s#SERVICE#ca#g ${local.installerhome}/cpd-ca.yaml",
            "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-ca.yaml",
            "oc create -f ${local.installerhome}/cpd-ca.yaml -n ${var.cpd-namespace}",
            "./wait-for-service-install.sh ca ${var.cpd-namespace}",           
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
        null_resource.install_wsl,
        null_resource.install_wml,
        null_resource.install_aiopenscale,
        null_resource.install_cde,
        null_resource.install_streams,
        null_resource.install_streams_flows,
        null_resource.install_ds,
        null_resource.install_db2wh,
        null_resource.install_db2oltp,
    	null_resource.install_datagate,
        null_resource.install_dods,
    ]
}

resource "null_resource" "install_spss" {
    count = var.spss-modeler == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
            "cat > ${local.installerhome}/cpd-spss-modeler.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
            "sed -i -e s#SERVICE#spss-modeler#g ${local.installerhome}/cpd-spss-modeler.yaml",
            "sed -i -e s#STORAGECLASS#${local.cp-storageclass}#g ${local.installerhome}/cpd-spss-modeler.yaml",
            "oc create -f ${local.installerhome}/cpd-spss-modeler.yaml -n ${var.cpd-namespace}",
            "./wait-for-service-install.sh spss-modeler ${var.cpd-namespace}",
        ]
    }
    depends_on = [
        null_resource.install_lite,
        null_resource.install_dv,
        null_resource.install_spark,
        null_resource.install_wkc,
        null_resource.install_wsl,
        null_resource.install_wml,
        null_resource.install_aiopenscale,
        null_resource.install_cde,
        null_resource.install_streams,
        null_resource.install_streams_flows,
        null_resource.install_ds,
        null_resource.install_db2wh,
        null_resource.install_db2oltp,
    	null_resource.install_datagate,
        null_resource.install_dods,
        null_resource.install_ca,
    ]
}