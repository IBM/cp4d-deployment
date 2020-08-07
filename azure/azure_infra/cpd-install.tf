locals {
    #General
    installerhome = "/home/${var.admin-username}/ibm"

    # Override
    override-file = var.storage == "portworx" ? "--override ${local.installerhome}/cpd-px-override.yaml" : ""
    
    #Storage Classes
    storageclass = var.storage == "portworx" ? "portworx-shared-gp" : "nfs"
    dv-storageclass = var.storage == "portworx" ? "portworx-dv-shared-gp" : "nfs"
    cp-storageclass = var.storage == "portworx" ? "portworx-shared-gp3" : "nfs"
    watson-asst-storageclass = var.storage == "portworx" ? "portworx-assistant" : "managed-premium"
    watson-discovery-storageclass = var.storage == "portworx" ? "portworx-db-gp3" : "managed-premium"
    watson-ks-storageclass = var.storage == "portworx" ? "portworx-wks" : "managed-premium"
    watson-lt-storageclass = var.storage == "portworx" ? "portworx-sc" : "managed-premium"
    watson-speech-storageclass = var.storage == "portworx" ? "portworx-sc" : "managed-premium"
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
            "sudo wget https://raw.githubusercontent.com/IBM/cp4d-deployment/master/azure/cpd_module/cpd-linux -O /usr/local/bin/cpd-linux",
            "sudo chmod +x /usr/local/bin/cpd-linux",
            "mkdir -p ${local.installerhome}",
            "cat > ${local.installerhome}/repo.yaml <<EOL\n${data.template_file.repo.rendered}\nEOL",
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "sudo podman login $REGISTRY -u kubeadmin -p $(oc whoami -t)",
            "oc new-project ${self.triggers.namespace}",
            "oc create serviceaccount cpdtoken",
            "oc policy add-role-to-user admin system:serviceaccount:${self.triggers.namespace}:cpdtoken",
            "cat > ${local.installerhome}/cpd-px-override.yaml <<EOL\n${data.template_file.cpd-override.rendered}\nEOL"
        ]
    }
    depends_on = [
        null_resource.openshift_post_install,
    ]
}

resource "null_resource" "install_cpd_lite" {
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a lite -n ${self.triggers.namespace} --accept-all-licenses --silent-install --apply",
            "cpd-linux -c ${local.cp-storageclass} -r ${local.installerhome}/repo.yaml -a lite -n ${self.triggers.namespace}  --silent-install --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.cpd_config,
    ]
}

resource "null_resource" "install_cpd_dv" {
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a dv -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.dv-storageclass} -r ${local.installerhome}/repo.yaml -a dv -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
    ]
}

resource "null_resource" "install_cpd_openscale" {
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a aiopenscale -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a aiopenscale -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
    ]
}

resource "null_resource" "install_cpd_spark" {
    count = var.apache-spark == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a spark -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a spark -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
    ]
}

resource "null_resource" "install_cpd_wkc" {
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a wkc -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a wkc -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_spark
    ]
}

resource "null_resource" "install_cpd_wsl" {
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a wsl -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a wsl -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_spark
    ]
}

resource "null_resource" "install_cpd_wml" {
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a wml -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a wml -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_spark
    ]
}

resource "null_resource" "install_cpd_cde" {
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a cde -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a cde -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark
    ]
}

resource "null_resource" "install_cpd_streams" {
    count = var.streams == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a streams -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a streams -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde
    ]
}

resource "null_resource" "install_cpd_streams_flows" {
    count = var.streams-flows == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a streams-flows -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a streams-flows -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows,
    ]
}

resource "null_resource" "install_cpd_ds" {
    count = var.datastage == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a ds -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a ds -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows
    ]
}

resource "null_resource" "install_cpd_db2wh" {
    count = var.db2_warehouse == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a db2wh -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a db2wh -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows,
        null_resource.install_cpd_ds,
    ]
}

resource "null_resource" "install_cpd_db2oltp" {
    count = var.db2_oltp == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a db2oltp -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a db2oltp -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows,
        null_resource.install_cpd_ds,
        null_resource.install_cpd_db2wh
    ]
}

resource "null_resource" "install_cpd_dods" {
    count = var.decision-optimization == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a dods -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a dods -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows,
        null_resource.install_cpd_ds,
        null_resource.install_cpd_db2wh,
        null_resource.install_cpd_db2oltp
    ]
}

resource "null_resource" "install_cpd_ca" {
    count = var.cognos-analytics == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cat > ${local.installerhome}/ca-override.yaml <<EOL\n${file("../cpd_module/cognos-override.yaml")}\nEOL",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a ca -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a ca -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses --override ${local.installerhome}/ca-override.yaml --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows,
        null_resource.install_cpd_ds,
        null_resource.install_cpd_db2wh,
        null_resource.install_cpd_db2oltp,
        null_resource.install_cpd_dods
    ]
}

resource "null_resource" "install_cpd_spss" {
    count = var.spss == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a spss-modeler -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -c ${local.storageclass} -r ${local.installerhome}/repo.yaml -a spss-modeler -n ${self.triggers.namespace}  --transfer-image-to=$REGISTRY/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --accept-all-licenses ${local.override-file} --insecure-skip-tls-verify"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows,
        null_resource.install_cpd_ds,
        null_resource.install_cpd_db2wh,
        null_resource.install_cpd_db2oltp,
        null_resource.install_cpd_dods,
        null_resource.install_cpd_ca
    ]
}

resource "null_resource" "install_cpd_watson_assistant" {
    count = var.watson-assistant == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "cat > ${local.installerhome}/watson-asst-override.yaml <<EOL\n${data.template_file.watson-asst-override.rendered}\nEOL",
            "oc project ${self.triggers.namespace}",
            "oc adm policy add-scc-to-group restricted system:serviceaccounts:${self.triggers.namespace}",
            "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
            "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-asst-override.yaml",
            "oc label --overwrite namespace ${self.triggers.namespace} ns=${self.triggers.namespace}",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "image_registry_route=$(oc get route -n  openshift-image-registry | grep image-registry | awk '{print $2}')",
            "cpd-linux -r ${local.installerhome}/repo.yaml -a ibm-watson-assistant --version 1.4.2 -n ${self.triggers.namespace} -c ${local.watson-asst-storageclass} --transfer-image-to $image_registry_route/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${self.triggers.namespace} --accept-all-licenses --override ${local.installerhome}/watson-asst-override.yaml --insecure-skip-tls-verify --verbose"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows,
        null_resource.install_cpd_ds,
        null_resource.install_cpd_db2wh,
        null_resource.install_cpd_db2oltp,
        null_resource.install_cpd_dods,
        null_resource.install_cpd_ca,
        null_resource.install_cpd_spss
    ]
}

resource "null_resource" "install_cpd_watson_discovery" {
    count = var.watson-discovery == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "cat > ${local.installerhome}/watson-discovery-override.yaml <<EOL\n${data.template_file.watson-discovery-override.rendered}\nEOL",
            "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
            "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-discovery-override.yaml",
            "host_ip=$(oc get svc -A | grep LoadBalancer | awk '{print $5}')",
            "sed -i s/k8_host_ip/$host_ip/g ${local.installerhome}/watson-discovery-override.yaml",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "image_registry_route=$(oc get route -n  openshift-image-registry | grep image-registry | awk '{print $2}')",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a watson-discovery -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -r ${local.installerhome}/repo.yaml -a watson-discovery -n ${self.triggers.namespace} -c ${local.watson-discovery-storageclass} --transfer-image-to $image_registry_route/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${self.triggers.namespace} --accept-all-licenses --override ${local.installerhome}/watson-discovery-override.yaml --insecure-skip-tls-verify --verbose"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows,
        null_resource.install_cpd_ds,
        null_resource.install_cpd_db2wh,
        null_resource.install_cpd_db2oltp,
        null_resource.install_cpd_dods,
        null_resource.install_cpd_ca,
        null_resource.install_cpd_spss,
        null_resource.install_cpd_watson_assistant
    ]
}

resource "null_resource" "install_cpd_watson_knowledge_studio" {
    count = var.watson-knowledge-studio == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "cat > ${local.installerhome}/watson-ks-override.yaml <<EOL\n${file("../cpd_module/watson-knowledge-studio-override.yaml")}\nEOL",
            "oc project ${self.triggers.namespace}",
            "oc label --overwrite namespace ${self.triggers.namespace} ns=${self.triggers.namespace}",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "image_registry_route=$(oc get route -n  openshift-image-registry | grep image-registry | awk '{print $2}')",
            "cpd-linux adm -r ${local.installerhome}/repo.yaml -a watson-ks -n ${self.triggers.namespace} --accept-all-licenses --apply",
            "cpd-linux -r ${local.installerhome}/repo.yaml -a watson-ks -n ${self.triggers.namespace} -c ${local.watson-ks-storageclass} --transfer-image-to $image_registry_route/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${self.triggers.namespace} --accept-all-licenses --override ${local.installerhome}/watson-ks-override.yaml --insecure-skip-tls-verify --verbose"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows,
        null_resource.install_cpd_ds,
        null_resource.install_cpd_db2wh,
        null_resource.install_cpd_db2oltp,
        null_resource.install_cpd_dods,
        null_resource.install_cpd_ca,
        null_resource.install_cpd_spss,
        null_resource.install_cpd_watson_assistant,
        null_resource.install_cpd_watson_discovery
    ]
}

resource "null_resource" "install_cpd_watson_language_translator" {
    count = var.watson-language-translator == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
            "cat > ${local.installerhome}/watson-lt-override.yaml <<EOL\n${data.template_file.watson-language-translator-override.rendered}\nEOL",
            "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
            "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-lt-override.yaml",
            "oc project ${self.triggers.namespace}",
            "oc adm policy add-scc-to-group restricted system:serviceaccounts:${self.triggers.namespace}",
            "oc label --overwrite namespace ${self.triggers.namespace} ns=${self.triggers.namespace}",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "image_registry_route=$(oc get route -n  openshift-image-registry | grep image-registry | awk '{print $2}')",
            "cpd-linux -r ${local.installerhome}/repo.yaml --assembly watson-language-translator --version 1.1.2 --optional-modules watson-language-pak-1 -n ${self.triggers.namespace} -c ${local.watson-lt-storageclass} --transfer-image-to $image_registry_route/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${self.triggers.namespace} --accept-all-licenses --override ${local.installerhome}/watson-lt-override.yaml --insecure-skip-tls-verify --verbose"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows,
        null_resource.install_cpd_ds,
        null_resource.install_cpd_db2wh,
        null_resource.install_cpd_db2oltp,
        null_resource.install_cpd_dods,
        null_resource.install_cpd_ca,
        null_resource.install_cpd_spss,
        null_resource.install_cpd_watson_assistant,
        null_resource.install_cpd_watson_discovery,
        null_resource.install_cpd_watson_knowledge_studio
    ]
}

resource "null_resource" "install_cpd_watson_speech" {
    count = var.watson-speech == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
    triggers = {
        bootnode_ip_address = azurerm_public_ip.bootnode.ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        namespace = var.cpd-namespace
        msecobj1 = base64encode(var.openshift-username)
        msecobj2 = base64encode(var.openshift-password)
        pgsecobj1 = base64encode(var.openshift-username)
        pgsecobj2 = base64encode(var.openshift-password)
    }
    connection {
        type = "ssh"
        host = azurerm_public_ip.bootnode.ip_address
        user = var.admin-username
        private_key = file(self.triggers.private_key_file_path)
    }
    provisioner "remote-exec" {
        inline = [
            "cat > ${local.installerhome}/watson-speech-override.yaml <<EOL\n${data.template_file.watson-speech-override.rendered}\nEOL",
            "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
            "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-speech-override.yaml",
            "oc project ${self.triggers.namespace}",
            "oc adm policy add-scc-to-group restricted system:serviceaccounts:${self.triggers.namespace}",
            "oc label --overwrite namespace ${self.triggers.namespace} ns=${self.triggers.namespace}",
            "cat > ${local.installerhome}/minio-secret.yaml <<EOL\n${file("../cpd_module/minio-secret.yaml")}\nEOL",
            "cat > ${local.installerhome}/postgre-secret.yaml <<EOL\n${file("../cpd_module/postgre-secret.yaml")}\nEOL",
            "sed -i s/minio-sec-obj1/${self.triggers.msecobj1}/g ${local.installerhome}/minio-secret.yaml",
            "sed -i s/minio-sec-obj2/${self.triggers.msecobj2}/g ${local.installerhome}/minio-secret.yaml",
            "sed -i s/pg-sec-obj1/${self.triggers.pgsecobj1}/g ${local.installerhome}/postgre-secret.yaml",
            "sed -i s/pg-sec-obj2/${self.triggers.pgsecobj2}/g ${local.installerhome}/postgre-secret.yaml",
            "oc apply -f ${local.installerhome}/minio-secret.yaml",
            "oc apply -f ${local.installerhome}/postgre-secret.yaml",
            "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${self.triggers.namespace})",
            "image_registry_route=$(oc get route -n  openshift-image-registry | grep image-registry | awk '{print $2}')",
            "cpd-linux -r ${local.installerhome}/repo.yaml -a watson-speech --version 1.1.4 -n ${self.triggers.namespace} -c ${local.watson-speech-storageclass} --transfer-image-to $image_registry_route/${self.triggers.namespace} --target-registry-username=kubeadmin --target-registry-password=$TOKEN --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${self.triggers.namespace} --accept-all-licenses --override ${local.installerhome}/watson-speech-override.yaml --insecure-skip-tls-verify --verbose"
        ]
    }
    depends_on = [
        null_resource.install_cpd_lite,
        null_resource.install_cpd_dv,
        null_resource.install_cpd_openscale,
        null_resource.install_cpd_wsl,
        null_resource.install_cpd_wkc,
        null_resource.install_cpd_wml,
        null_resource.install_cpd_spark,
        null_resource.install_cpd_cde,
        null_resource.install_cpd_streams,
        null_resource.install_cpd_streams_flows,
        null_resource.install_cpd_ds,
        null_resource.install_cpd_db2wh,
        null_resource.install_cpd_db2oltp,
        null_resource.install_cpd_dods,
        null_resource.install_cpd_ca,
        null_resource.install_cpd_spss,
        null_resource.install_cpd_watson_assistant,
        null_resource.install_cpd_watson_discovery,
        null_resource.install_cpd_watson_knowledge_studio,
        null_resource.install_cpd_watson_language_translator
    ]
}