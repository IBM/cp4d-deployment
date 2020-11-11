locals {
    ocpdir = "ocpfourx"
    ocptemplates = "ocpfourxtemplates"
    install-config = var.azlist == "multi_zone" ? "${data.template_file.installconfig[0].rendered}" : "${data.template_file.installconfig-1AZ[0].rendered}"
}

resource "null_resource" "install_openshift" {
    triggers = {
        bootnode_public_ip      = aws_instance.bootnode.public_ip
        username                = var.admin-username
        private-key-file-path   = var.ssh-private-key-file-path
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }

    provisioner "remote-exec" {
        inline = [
            #install awscli on bootnode.
            "sed -i -e s/\r$// *.sh *.py",
            "sudo yum -y install python3",
            "sudo yum -y install wget",
            "sudo yum -y install bind-utils",
            "curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null",
            "python get-pip.py --user > /dev/null",
            "export PATH=\"~/.local/bin:$PATH\"",
            "source ~/.bash_profile > /dev/null",
            "pip install awscli --upgrade --user > /dev/null",

            #Perform aws account Permission and Resource quota validaton.
            "chmod +x /home/${self.triggers.username}/*.sh *.py",
            "mkdir -p /home/${var.admin-username}/.aws",
            "cat > /home/${var.admin-username}/.aws/credentials <<EOL\n${data.template_file.awscreds.rendered}\nEOL",
            "cat > /home/${var.admin-username}/.aws/config <<EOL\n${data.template_file.awsregion.rendered}\nEOL",
            "./aws_permission_validation.sh ; if [ $? -ne 0 ] ; then echo \"Permission Verification Failed\" ; exit 1 ; fi",
            "echo file | ./aws_resource_quota_validation.sh ; if [ $? -ne 0 ] ; then echo \"Resource Quota Validation Failed\" ; exit 1 ; fi",

            #Create OpenShift Cluster.
            "wget https://${var.s3-bucket}-${var.region}.s3.${var.region}.amazonaws.com/${var.inst_version}/openshift-install",
            "sudo wget https://${var.s3-bucket}-${var.region}.s3.${var.region}.amazonaws.com/${var.inst_version}/oc -O /usr/local/bin/oc",
            "sudo wget https://${var.s3-bucket}-${var.region}.s3.${var.region}.amazonaws.com/${var.inst_version}/kubectl -O /usr/local/bin/kubectl",

            "mkdir -p ${local.ocptemplates}",
            "mkdir -p ${local.ocpdir}",
            "chmod +x openshift-install",
            "sudo chmod +x /usr/local/bin/oc",
            "sudo chmod +x /usr/local/bin/kubectl",
            "sudo yum install -y httpd-tools",
            "cat > ${local.ocpdir}/install-config.yaml <<EOL\n${local.install-config}\nEOL",
            "./openshift-install create cluster --dir=${local.ocpdir} --log-level=debug",

            "mkdir -p /home/${var.admin-username}/.kube",
            "cp /home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig /home/${var.admin-username}/.kube/config",
            "cat > ${local.ocptemplates}/cluster-autoscaler.yaml <<EOL\n${data.template_file.clusterautoscaler.rendered}\nEOL",
            "cat > ${local.ocptemplates}/machine-autoscaler.yaml <<EOL\n${data.template_file.machineautoscaler.rendered}\nEOL",
            "cat > ${local.ocptemplates}/machineset-worker-ocs.yaml <<EOL\n${data.template_file.workerocs.rendered}\nEOL",
            "cat > ${local.ocptemplates}/machine-health-check.yaml <<EOL\n${data.template_file.machinehealthcheck.rendered}\nEOL",
            "cat > /home/${var.admin-username}/.ssh/id_rsa <<EOL\n${file("${var.ssh-private-key-file-path}")}\nEOL",

            "sudo chmod 0600 /home/${var.admin-username}/.ssh/id_rsa",
            "oc login -u kubeadmin -p $(cat ${local.ocpdir}/auth/kubeadmin-password)",
            "./autoscaler-prereq.sh",
            "oc create -f ${local.ocptemplates}/cluster-autoscaler.yaml",
            "oc create -f ${local.ocptemplates}/machine-health-check.yaml",
        ]
    }
    depends_on = [
        aws_instance.bootnode,
        null_resource.file_copy,
    ]
}

#Install Portoworx as storage type.
resource "null_resource" "install_portworx" {
    count    = var.storage-type == "portworx" ? 1 : 0
    triggers = {
        bootnode_public_ip      = aws_instance.bootnode.public_ip
        username                = var.admin-username
        private-key-file-path   = var.ssh-private-key-file-path
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "cat > ${local.ocptemplates}/px-install.yaml <<EOL\n${file("../portworx_module/px-install.yaml")}\nEOL",
            "cat > /home/${var.admin-username}/policy.json <<EOL\n${file("../portworx_module/policy.json")}\nEOL",
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",

            "./portworx-prereq.sh",
            "./portworx-install.sh",
            "oc create -f ${local.ocptemplates}/px-install.yaml",
            "sleep 180",
            "oc apply -f \"${var.portworx-spec-url}\"",
            "sleep 360",
            "./px-storageclasses.sh",
        ]
    }
    depends_on = [
        null_resource.install_openshift,
    ]
}

#Install OCS as storage type.
resource "null_resource" "install_ocs" {
    count    = var.storage-type == "ocs" ? 1 : 0
    triggers = {
        bootnode_public_ip      = aws_instance.bootnode.public_ip
        username                = var.admin-username
        private-key-file-path   = var.ssh-private-key-file-path
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "cat > ${local.ocptemplates}/toolbox.yaml <<EOL\n${file("../ocs_module/toolbox.yaml")}\nEOL",
            "sed -i s/\"namespace: rook-ceph\"/\"namespace: openshift-storage\"/g ${local.ocptemplates}/toolbox.yaml",
            "cat > ${local.ocptemplates}/deploy-with-olm.yaml <<EOL\n${file("../ocs_module/deploy-with-olm.yaml")}\nEOL",
            "cat > ${local.ocptemplates}/ocs-storagecluster.yaml <<EOL\n${file("../ocs_module/ocs-storagecluster.yaml")}\nEOL",
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",

            "oc create -f ${local.ocptemplates}/machineset-worker-ocs.yaml",
            "sleep 420",
            "./ocs-prereq.sh",
            "oc create -f ${local.ocptemplates}/deploy-with-olm.yaml",
            "sleep 300",
            "oc apply -f ${local.ocptemplates}/ocs-storagecluster.yaml",
            "sleep 600",
            "oc apply -f ${local.ocptemplates}/toolbox.yaml",
            "sleep 60",
            "./delete-noobaa-buckets.sh 2> /dev/null",
        ]
    }
    depends_on = [
        null_resource.install_openshift,
    ]
}

#Install EFS as storage type.
resource "null_resource" "install_efs" {
    count    = var.storage-type == "efs" ? 1 : 0
    triggers = {
        bootnode_public_ip      = aws_instance.bootnode.public_ip
        username                = var.admin-username
        private-key-file-path   = var.ssh-private-key-file-path
    }
    connection {
        type        = "ssh"
        host        = self.triggers.bootnode_public_ip
        user        = self.triggers.username
        private_key = file(self.triggers.private-key-file-path)
    }
    provisioner "remote-exec" {
        inline = [
            "curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null",
            "python get-pip.py --user > /dev/null",
            "export PATH=\"~/.local/bin:$PATH\"",
            "source ~/.bash_profile > /dev/null",
            "pip install awscli --upgrade --user > /dev/null",

            "cat > ${local.ocptemplates}/efs-configmap.yaml <<EOL\n${data.template_file.efs-configmap.rendered}\nEOL",
            "cat > ${local.ocptemplates}/efs-namespace.yaml <<EOL\n${file("../efs_module/efs-namespace.yaml")}\nEOL",
            "cat > ${local.ocptemplates}/efs-roles.yaml <<EOL\n${file("../efs_module/efs-roles.yaml")}\nEOL",
            "cat > ${local.ocptemplates}/efs-storageclass.yaml <<EOL\n${file("../efs_module/efs-storageclass.yaml")}\nEOL",
            "cat > ${local.ocptemplates}/efs-provisioner.yaml <<EOL\n${file("../efs_module/efs-provisioner.yaml")}\nEOL",
            "cat > ${local.ocptemplates}/efs-pvc.yaml <<EOL\n${file("../efs_module/efs-pvc.yaml")}\nEOL",
            "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",

            "./create-efs.sh ${var.region} ${var.vpc_cidr} ${local.vpcid} ${var.efs-performance-mode}",
            "sleep 180",
            "CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\\.openshift\\.io/cluster-api-cluster}')",
            "FILESYSTEMID=$(aws efs describe-file-systems --query FileSystems[?Name==\\'$CLUSTERID-efs\\'].FileSystemId --output text)",
            "DNSNAME=$FILESYSTEMID.efs.${var.region}.amazonaws.com",

            "sed -i s/FILESYSTEMID/$FILESYSTEMID/g ${local.ocptemplates}/efs-configmap.yaml",
            "sed -i s/DNSNAME/$DNSNAME/g ${local.ocptemplates}/efs-configmap.yaml",
            "sed -i s/DNSNAME/$DNSNAME/g ${local.ocptemplates}/efs-provisioner.yaml",

            "oc create -f ${local.ocptemplates}/efs-configmap.yaml",
            "oc create serviceaccount efs-provisioner",
            "oc create -f ${local.ocptemplates}/efs-roles.yaml",
            "oc create -f ${local.ocptemplates}/efs-storageclass.yaml",
            "oc create -f ${local.ocptemplates}/efs-provisioner.yaml",
            "sleep 60",
            "oc create -f ${local.ocptemplates}/efs-namespace.yaml",
            "oc create -f ${local.ocptemplates}/efs-pvc.yaml",
            "sleep 60",
        ]
    }
    depends_on = [
        null_resource.install_openshift,
    ]
}
