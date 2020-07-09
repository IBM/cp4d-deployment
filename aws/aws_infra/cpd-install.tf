locals {
    #General
    installerhome = "/home/${var.admin-username}/ibm"
}

resource "null_resource" "cpd_config" {
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
          "cat > ${local.ocptemplates}/insecure-registry-mc.yaml <<EOL\n${data.template_file.registry-mc.rendered}\nEOL",
          "cat > ${local.ocptemplates}/sysctl-machineconfig.yaml <<EOL\n${data.template_file.sysctl-machineconfig.rendered}\nEOL",
          "cat > ${local.ocptemplates}/security-limits-mc.yaml <<EOL\n${data.template_file.security-limits-mc.rendered}\nEOL",
          "cat > ${local.ocptemplates}/crio-mc.yaml <<EOL\n${data.template_file.crio-mc.rendered}\nEOL",
          "cat > ${local.ocptemplates}/registries.conf <<EOL\n${data.template_file.registry-conf.rendered}\nEOL",
          "cat > ${local.ocptemplates}/oauth-token.yaml <<EOL\n${file("../openshift_module/oauth-token.yaml")}\nEOL",
          "oc create -f ${local.ocptemplates}/machine-autoscaler.yaml 2> /dev/null",
          "oc create -f ${local.ocptemplates}/insecure-registry-mc.yaml",
          "oc create -f ${local.ocptemplates}/sysctl-machineconfig.yaml",
          "oc create -f ${local.ocptemplates}/security-limits-mc.yaml",
          "oc create -f ${local.ocptemplates}/crio-mc.yaml",
          "oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{\"spec\":{\"defaultRoute\":true,\"replicas\":${lookup(var.image-replica,var.azlist)}}}'",
          "oc set env deployment/image-registry -n openshift-image-registry REGISTRY_STORAGE_S3_CHUNKSIZE=104857600",
          "oc patch svc/image-registry -p '{\"spec\":{\"sessionAffinity\": \"ClientIP\"}}' -n openshift-image-registry",
          "echo 'Sleeping for 10mins while MachineConfigs apply and the cluster restarts' ",
          "sleep 12m",
          "mkdir -p ${local.installerhome}",
          "cat > ${local.installerhome}/repo.yaml <<EOL\n${data.template_file.repo.rendered}\nEOL",
          "cat > ${local.installerhome}/portworx-override.yaml <<EOL\n${data.template_file.portworx-override.rendered}\nEOL",
          "cat > ${local.installerhome}/ocs-override.yaml <<EOL\n${file("../cpd_module/ocs-override.yaml")}\nEOL",
          "cat > ${local.installerhome}/ca-override.yaml <<EOL\n${file("../cpd_module/ca-override.yaml")}\nEOL",
          "wget https://${var.s3-bucket}-${var.region}.s3.${var.region}.amazonaws.com/${var.inst_version}/cpd-linux -O ${local.installerhome}/cpd-linux",
          "chmod +x ${local.installerhome}/cpd-linux delete-elb-outofservice.sh",
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "oc new-project ${var.cpd-namespace}",
          "oc create serviceaccount cpdtoken",
          "oc policy add-role-to-user admin system:serviceaccount:${var.cpd-namespace}:cpdtoken",
          "oc apply -f ${local.ocptemplates}/oauth-token.yaml",
          "oc annotate route default-route haproxy.router.openshift.io/timeout=600s -n openshift-image-registry",
          "./delete-elb-outofservice.sh ${var.vpc_cidr}",
      ]
  }
  depends_on = [
      null_resource.install_portworx,
      null_resource.install_ocs,
      null_resource.install_efs,
  ]
}

resource "null_resource" "provisioner" {
  count = var.storage-type == "efs" ? 1 : 0
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
        "oc create serviceaccount efs-provisioner -n default 2> /dev/null",
        "oc apply -f ${local.ocptemplates}/efs-provisioner.yaml -n default 2> /dev/null",
      ]
    }
    depends_on = [
        null_resource.cpd_config,
    ]
}

resource "null_resource" "install_lite" {
  count = var.accept-cpd-license == "accept" ? 1 : 0
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a lite -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a lite -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
      ]
    }
    depends_on = [
        null_resource.cpd_config,
        null_resource.provisioner,
    ]
}

resource "null_resource" "install_dv" {
  count = var.data-virtualization == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a dv -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a dv -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
      ]
    }
    depends_on = [
        null_resource.install_lite,
    ]
}

resource "null_resource" "install_spark" {
  count = var.apache-spark == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a spark -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a spark -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a wkc -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a wkc -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a wsl -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a wsl -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a wml -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a wml -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a aiopenscale -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a aiopenscale -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a cde -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux  --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a cde -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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
    ]
}

resource "null_resource" "install_streams" {
  count = var.streams == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a streams -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.streams-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a streams -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a streams-flows -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux  --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a streams-flows -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a ds -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a ds -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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
  count = var.db2_warehouse == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a db2wh -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a db2wh -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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
  count = var.db2_advanced_edition == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a db2oltp -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a db2oltp -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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

resource "null_resource" "install_dods" {
  count = var.decision_optimization == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a dods -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a dods -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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

resource "null_resource" "install_ca" {
  count = var.cognos_analytics == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a ca -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a ca -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses -o ${local.installerhome}/ca-override.yaml --insecure-skip-tls-verify"
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
        null_resource.install_dods,
    ]
}

resource "null_resource" "install_spss" {
  count = var.spss_modeler == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken)",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a spss-modeler -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${lookup(var.cpd-storageclass,var.storage-type)} -r ${local.installerhome}/repo.yaml -a spss-modeler -n ${var.cpd-namespace}  --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses ${lookup(var.cpd-override,var.storage-type)} --insecure-skip-tls-verify"
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
        null_resource.install_dods,
        null_resource.install_ca,
    ]
}
