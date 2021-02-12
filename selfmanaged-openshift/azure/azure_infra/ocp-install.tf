locals {
    ocpdir = "ocpfourx"
    ocptemplates = "ocpfourxtemplates"
    install-config-file = "install-config-${var.single-or-multi-zone}.tpl.yaml"
    machine-autoscaler-file = "machine-autoscaler-${var.single-or-multi-zone}.tpl.yaml"
    machine-health-check-file = "machine-health-check-${var.single-or-multi-zone}.tpl.yaml"
}

resource "null_resource" "install_openshift" {
    triggers = {
        bootnode_ip_address = local.bootnode_ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        directory = local.ocpdir
    }
    connection {
        type = "ssh"
        host = self.triggers.bootnode_ip_address
        user = self.triggers.username
        private_key = file(self.triggers.private_key_file_path)
    }
    provisioner "remote-exec" {
        inline = [
            "wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.ocp_version}/openshift-install-linux.tar.gz",
            "wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.ocp_version}/openshift-client-linux.tar.gz",
            "tar -xvf openshift-install-linux.tar.gz",
            "sudo tar -xvf openshift-client-linux.tar.gz -C /usr/bin",
            "mkdir -p ${local.ocpdir}",
            "mkdir -p ${local.ocptemplates}",
            "cat > ${local.ocpdir}/install-config.yaml <<EOL\n${data.template_file.installconfig.rendered}\nEOL",
            "mkdir -p /home/${var.admin-username}/.azure",
            "cat > /home/${var.admin-username}/.azure/osServicePrincipal.json <<EOL\n${data.template_file.azurecreds.rendered}\nEOL",
            "chmod +x openshift-install",
            "sudo chmod +x /usr/bin/oc",
            "sudo chmod +x /usr/bin/kubectl",
            "sudo yum install -y podman",
            "sudo yum install -y httpd-tools",
            "./openshift-install create cluster --dir=${local.ocpdir} --log-level=debug",
            "mkdir -p /home/${var.admin-username}/.kube",
            "cp /home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig /home/${var.admin-username}/.kube/config",
            "cat > ${local.ocptemplates}/machine-health-check-${var.single-or-multi-zone}.yaml <<EOL\n${data.template_file.machine-health-check.rendered}\nEOL",
            "cat > /home/${var.admin-username}/.ssh/id_rsa <<EOL\n${file(var.ssh-private-key-file-path)}\nEOL",
            "sudo chmod 0600 /home/${var.admin-username}/.ssh/id_rsa",
            "CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\\.openshift\\.io/cluster-api-cluster}')",
            "sed -i s/${random_id.randomId.hex}/$CLUSTERID/g /home/${var.admin-username}/${local.ocptemplates}/machine-health-check-${var.single-or-multi-zone}.yaml",
            "oc login -u kubeadmin -p $(cat ${local.ocpdir}/auth/kubeadmin-password) -n openshift-machine-api",
            "oc create -f ${local.ocptemplates}/machine-health-check-${var.single-or-multi-zone}.yaml"
        ]
    }

    # Destroy OCP Cluster before destroying the bootnode
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            host = self.triggers.bootnode_ip_address
            user = self.triggers.username
            private_key = file(self.triggers.private_key_file_path)
        }
        when = destroy
        inline =[
            "/home/${self.triggers.username}/openshift-install destroy cluster --dir=${self.triggers.directory} --log-level=debug",
            "sleep 300"
        ]
    }
    depends_on = [
        azurerm_virtual_machine.bootnode,
        azurerm_subnet.masternode,
        azurerm_subnet.workernode
    ]
}

resource "null_resource" "openshift_post_install" {
    triggers = {
        bootnode_ip_address = local.bootnode_ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
    }
    connection {
        type = "ssh"
        host = self.triggers.bootnode_ip_address
        user = var.admin-username
        private_key = file(self.triggers.private_key_file_path)
    }
    provisioner "remote-exec" {
        inline = [
            "htpasswd -c -B -b /tmp/.htpasswd '${var.openshift-username}' '${var.openshift-password}'",
            "sleep 3",
            "oc create secret generic htpass-secret --from-file=htpasswd=/tmp/.htpasswd -n openshift-config",
            "cat > ${local.ocptemplates}/auth.yaml <<EOL\n${data.template_file.htpasswd.rendered}\nEOL",
            "oc apply -f ${local.ocptemplates}/auth.yaml",
            "oc adm policy add-cluster-role-to-user cluster-admin '${var.openshift-username}'",

            #Delete kubeadmin
            # "oc delete secrets kubeadmin -n kube-system",
            # "rm /tmp/.htpasswd"

            # Machine Configs
            "oc project kube-system",
            "cat > ${local.ocptemplates}/insecure-registry-mc.yaml <<EOL\n${data.template_file.registry-mc.rendered}\nEOL",
            "cat > ${local.ocptemplates}/sysctl-mc.yaml <<EOL\n${data.template_file.sysctl-mc.rendered}\nEOL",
            "cat > ${local.ocptemplates}/limits-mc.yaml <<EOL\n${data.template_file.limits-mc.rendered}\nEOL",
            "cat > ${local.ocptemplates}/crio-mc.yaml <<EOL\n${data.template_file.crio-mc.rendered}\nEOL",
            "cat > ${local.ocptemplates}/chrony-mc.yaml <<EOL\n${data.template_file.chrony-mc.rendered}\nEOL",
            "cat > ${local.ocptemplates}/registries.conf <<EOL\n${data.template_file.registry-conf.rendered}\nEOL",
            "sudo mv ${local.ocptemplates}/registries.conf /etc/containers/registries.conf",
            "oc create -f ${local.ocptemplates}/insecure-registry-mc.yaml",
            "oc create -f ${local.ocptemplates}/sysctl-mc.yaml",
            "oc create -f ${local.ocptemplates}/limits-mc.yaml",
            "oc create -f ${local.ocptemplates}/crio-mc.yaml",
            "oc create -f ${local.ocptemplates}/chrony-mc.yaml",

            # multipath-machineconfig
            "cat > ${local.ocptemplates}/multipath-machineconfig.yaml <<EOL\n${data.template_file.multipath-mc.rendered}\nEOL",
            "oc create -f ${local.ocptemplates}/multipath-machineconfig.yaml",

            # Create Registry Route
            "oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{\"spec\":{\"defaultRoute\":true, \"replicas\":${var.worker-node-count}}}'",
            "echo 'Sleeping for 15 mins while MCs apply and the cluster restarts' ",
            "sleep 15m",
            "result=$(oc wait machineconfigpool/worker --for condition=updated --timeout=15m)",
            "echo $result",
            "sudo oc login https://api.${var.cluster-name}.${var.dnszone}:6443 -u '${var.openshift-username}' -p '${var.openshift-password}' --insecure-skip-tls-verify=true"
        ]
    }
    depends_on = [
        null_resource.install_openshift
    ]
}

resource "null_resource" "cluster_autoscaler" {
    count = var.clusterAutoscaler == "yes" ? 1 : 0
    triggers = {
        bootnode_ip_address = local.bootnode_ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
    }
    connection {
        type = "ssh"
        host = self.triggers.bootnode_ip_address
        user = var.admin-username
        private_key = file(self.triggers.private_key_file_path)
    }
    provisioner "remote-exec" {
        inline = [
            "CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\\.openshift\\.io/cluster-api-cluster}')",
            "sed -i s/${random_id.randomId.hex}/$CLUSTERID/g /home/${var.admin-username}/${local.ocptemplates}/machine-autoscaler-${var.single-or-multi-zone}.yaml",
            "cat > ${local.ocptemplates}/cluster-autoscaler.yaml <<EOL\n${data.template_file.clusterautoscaler.rendered}\nEOL",
            "cat > ${local.ocptemplates}/machine-autoscaler-${var.single-or-multi-zone}.yaml <<EOL\n${data.template_file.machineautoscaler.rendered}\nEOL",
            "oc create -f ${local.ocptemplates}/cluster-autoscaler.yaml",
            "oc create -f ${local.ocptemplates}/machine-autoscaler-${var.single-or-multi-zone}.yaml",
        ]
    }
    depends_on = [
        null_resource.install_openshift
    ]
}

resource "null_resource" "install_portworx" {
    count = var.storage == "portworx" ? 1 : 0
    triggers = {
        bootnode_ip_address = local.bootnode_ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
    }
    connection {
        type = "ssh"
        host = self.triggers.bootnode_ip_address
        user = var.admin-username
        private_key = file(self.triggers.private_key_file_path)
    }
    provisioner "remote-exec" {
        inline = [
            "cat > ${local.ocptemplates}/px-install.yaml <<EOL\n${data.template_file.px-install.rendered}\nEOL",
            "cat > ${local.ocptemplates}/px-storageclasses.yaml <<EOL\n${data.template_file.px-storageclasses.rendered}\nEOL",
            "result=$(oc create -f ${local.ocptemplates}/px-install.yaml)",
            "sleep 60",
            "echo $result",
            "result=$(oc apply -f \"${var.portworx-spec-url}\")",
            "echo $result",
            "echo 'Sleeping for 5 mins to get portworx storage cluster up' ",
            "sleep 5m",
            "result=$(oc create -f ${local.ocptemplates}/px-storageclasses.yaml)",
            "echo $result"
        ]
    }
    depends_on = [
        null_resource.install_openshift,
        null_resource.openshift_post_install
    ]
}

resource "null_resource" "install_ocs" {
    count    = var.storage == "ocs" ? 1 : 0
    triggers = {
        bootnode_ip_address = local.bootnode_ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
    }
    connection {
        type = "ssh"
        host = self.triggers.bootnode_ip_address
        user = var.admin-username
        private_key = file(self.triggers.private_key_file_path)
    }
    provisioner "remote-exec" {
        inline = [
            "cat > ${local.ocptemplates}/toolbox.yaml <<EOL\n${file("../ocs_module/toolbox.yaml")}\nEOL",
            "cat > ${local.ocptemplates}/deploy-with-olm.yaml <<EOL\n${file("../ocs_module/deploy-with-olm.yaml")}\nEOL",
            "cat > ${local.ocptemplates}/ocs-storagecluster.yaml <<EOL\n${file("../ocs_module/ocs-storagecluster.yaml")}\nEOL",
            "cat > ocs-prereq.sh <<EOL\n${file("../ocs_module/ocs-prereq.sh")}\nEOL",
            "sudo chmod +x ocs-prereq.sh",
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",

            "./ocs-prereq.sh",
            "oc create -f ${local.ocptemplates}/deploy-with-olm.yaml",
            "sleep 300",
            "oc apply -f ${local.ocptemplates}/ocs-storagecluster.yaml",
            "sleep 600",
            "oc apply -f ${local.ocptemplates}/toolbox.yaml",
            "sleep 60",
        ]
    }
    depends_on = [
        null_resource.install_openshift,
        null_resource.openshift_post_install
    ]
}

resource "null_resource" "install-nfs-server" {
    count = var.storage == "nfs" ? 1 : 0
    triggers = {
        bootnode_ip_address = local.bootnode_ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
        nfsnode_ip_address = azurerm_network_interface.nfs[count.index].private_ip_address
    }
    connection {
        type = "ssh"
        host = self.triggers.bootnode_ip_address
        user = self.triggers.username
        private_key = file(self.triggers.private_key_file_path)
    }
    provisioner "remote-exec" {
        inline = [
            "cat > ${local.ocptemplates}/setup-nfs.sh <<EOL\n${file("../nfs_module/setup-nfs.sh")}\nEOL",
            "scp -o \"StrictHostKeyChecking=no\" ${local.ocptemplates}/setup-nfs.sh ${var.admin-username}@${self.triggers.nfsnode_ip_address}:/home/${var.admin-username}/setup-nfs.sh",
            "ssh -o \"StrictHostKeyChecking=no\" ${var.admin-username}@${self.triggers.nfsnode_ip_address} sudo sh /home/${var.admin-username}/setup-nfs.sh"
        ]
    }
    depends_on = [
        null_resource.install_openshift,
        null_resource.openshift_post_install
    ]
}

resource "null_resource" "install_nfs_client" {
    count = var.storage == "nfs" ? 1 : 0
    triggers = {
        bootnode_ip_address = local.bootnode_ip_address
        username = var.admin-username
        private_key_file_path = var.ssh-private-key-file-path
    }
    connection {
        type = "ssh"
        host =  self.triggers.bootnode_ip_address
        user = self.triggers.username
        private_key = file(self.triggers.private_key_file_path)
    }
    provisioner "remote-exec" {
        inline = [
            "oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:kube-system:nfs-client-provisioner",
            "cat > ${local.ocptemplates}/nfs-template.yaml <<EOL\n${data.template_file.nfs-template[count.index].rendered}\nEOL",
            "oc process -f ${local.ocptemplates}/nfs-template.yaml | oc create -n kube-system -f -",
        ]
    }
    depends_on = [
        null_resource.install_openshift,
        null_resource.openshift_post_install,
        null_resource.install-nfs-server
    ]
}
