locals {
    #General
    installerhome = "/home/${var.admin-username}/ibm"
	
    #Watson AI Services Storage Classes
    watson-asst-storageclass      = var.storage-type == "portworx" ? "portworx-assistant" : "gp2"
    watson-discovery-storageclass = var.storage-type == "portworx" ? "portworx-db-gp3" : "gp2"
    watson-ks-storageclass        = var.storage-type == "portworx" ? "portworx-db-gp3" : "gp2"
    watson-lt-storageclass        = var.storage-type == "portworx" ? "portworx-sc" : "gp2"
    watson-speech-storageclass    = var.storage-type == "portworx" ? "portworx-sc" : "gp2"
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
          #Create identity provider.
          "htpasswd -c -B -b /tmp/.htpasswd '${var.openshift-username}' '${var.openshift-password}'",
          "sleep 3",
          "oc create secret generic htpass-secret --from-file=htpasswd=/tmp/.htpasswd -n openshift-config",
          "cat > ${local.ocptemplates}/auth-htpasswd.yaml <<EOL\n${file("../openshift_module/auth-htpasswd.yaml")}\nEOL",
          "oc apply -f ${local.ocptemplates}/auth-htpasswd.yaml",
          "oc adm policy add-cluster-role-to-user cluster-admin '${var.openshift-username}'",

          "cat > ${local.ocptemplates}/insecure-registry-mc.yaml <<EOL\n${data.template_file.registry-mc.rendered}\nEOL",
          "cat > ${local.ocptemplates}/sysctl-machineconfig.yaml <<EOL\n${data.template_file.sysctl-machineconfig.rendered}\nEOL",
          "cat > ${local.ocptemplates}/security-limits-mc.yaml <<EOL\n${data.template_file.security-limits-mc.rendered}\nEOL",
          "cat > ${local.ocptemplates}/crio-mc.yaml <<EOL\n${data.template_file.crio-mc.rendered}\nEOL",
          "cat > ${local.ocptemplates}/registries.conf <<EOL\n${data.template_file.registry-conf.rendered}\nEOL",
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
          "oc annotate route default-route haproxy.router.openshift.io/timeout=600s -n openshift-image-registry",
      ]
  }
  depends_on = [
      null_resource.install_portworx,
      null_resource.install_ocs,
      null_resource.install_efs,
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
  count = var.db2-warehouse == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
  count = var.db2-advanced-edition == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
  count = var.decision-optimization == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
  count = var.cognos-analytics == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
  count = var.spss-modeler == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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

resource "null_resource" "install_watson_assistant" {
  count = var.watson-assistant == "yes" && var.storage-type != "ocs" && var.accept-cpd-license == "accept" ? 1 : 0 
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
          "cat > ${local.installerhome}/watson-asst-override.yaml <<EOL\n${data.template_file.watson-asst-override.rendered}\nEOL",
          "oc adm policy add-scc-to-group restricted system:serviceaccounts:${var.cpd-namespace}",
          "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
          "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-asst-override.yaml",
          "oc label --overwrite namespace ${var.cpd-namespace} ns=${var.cpd-namespace}",
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${var.cpd-namespace})",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a ibm-watson-assistant -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${local.watson-asst-storageclass} -r ${local.installerhome}/repo.yaml -a ibm-watson-assistant --version 1.4.2 -n ${var.cpd-namespace} --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses --override ${local.installerhome}/watson-asst-override.yaml --insecure-skip-tls-verify"
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
        null_resource.install_spss,
    ]
}

resource "null_resource" "install_watson_discovery" {
  count = var.watson-discovery == "yes" && var.storage-type != "ocs" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "cat > ${local.installerhome}/watson-discovery-override.yaml <<EOL\n${data.template_file.watson-discovery-override.rendered}\nEOL",
          "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
          "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-discovery-override.yaml",
          "host_ip=$(dig +short api.${var.cluster-name}.${var.dnszone} | awk 'NR==1{print $1}')",
          "sed -i s/k8_host_ip/$host_ip/g ${local.installerhome}/watson-discovery-override.yaml",
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${var.cpd-namespace})",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a watson-discovery -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${local.watson-discovery-storageclass} -r ${local.installerhome}/repo.yaml -a watson-discovery -n ${var.cpd-namespace} --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses --override ${local.installerhome}/watson-discovery-override.yaml --insecure-skip-tls-verify"
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
        null_resource.install_spss,
        null_resource.install_watson_assistant,
    ]
}

resource "null_resource" "install_watson_knowledge_studio" {
  count = var.watson-knowledge-studio == "yes" && var.storage-type != "ocs" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "cat > ${local.installerhome}/watson-ks-override.yaml <<EOL\n${file("../cpd_module/watson-knowledge-studio-override.yaml")}\nEOL",
          "oc label --overwrite namespace ${var.cpd-namespace} ns=${var.cpd-namespace}",
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${var.cpd-namespace})",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a watson-ks -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${local.watson-ks-storageclass} -r ${local.installerhome}/repo.yaml -a watson-ks -n ${var.cpd-namespace} --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses --override ${local.installerhome}/watson-ks-override.yaml --insecure-skip-tls-verify"
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
        null_resource.install_spss,
        null_resource.install_watson_assistant,
        null_resource.install_watson_discovery,
    ]
}

resource "null_resource" "install_watson_language_translator" {
  count = var.watson-language-translator == "yes" && var.storage-type != "ocs" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "cat > ${local.installerhome}/watson-lt-override.yaml <<EOL\n${data.template_file.watson-language-translator-override.rendered}\nEOL",
          "oc adm policy add-scc-to-group restricted system:serviceaccounts:${var.cpd-namespace}",
          "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
          "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-lt-override.yaml",
          "oc label --overwrite namespace ${var.cpd-namespace} ns=${var.cpd-namespace}",
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${var.cpd-namespace})",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a watson-language-translator -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${local.watson-lt-storageclass} -r ${local.installerhome}/repo.yaml -a watson-language-translator --version 1.1.2 --optional-modules watson-language-pak-1 -n ${var.cpd-namespace} --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses --override ${local.installerhome}/watson-lt-override.yaml --insecure-skip-tls-verify"
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
        null_resource.install_spss,
        null_resource.install_watson_assistant,
        null_resource.install_watson_discovery,
        null_resource.install_watson_knowledge_studio,
    ]
}

resource "null_resource" "install_watson_speech" {
  count = var.watson-speech == "yes" && var.storage-type != "ocs" && var.accept-cpd-license == "accept" ? 1 : 0
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
          "cat > ${local.installerhome}/watson-speech-override.yaml <<EOL\n${data.template_file.watson-speech-override.rendered}\nEOL",
          "cat > ${local.installerhome}/minio-secret.yaml <<EOL\n${data.template_file.minio-secret.rendered}\nEOL",
          "cat > ${local.installerhome}/postgre-secret.yaml <<EOL\n${data.template_file.postgre-secret.rendered}\nEOL",
          "oc adm policy add-scc-to-group restricted system:serviceaccounts:${var.cpd-namespace}",
          "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
          "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-speech-override.yaml",
          "oc label --overwrite namespace ${var.cpd-namespace} ns=${var.cpd-namespace}",
          "oc apply -f ${local.installerhome}/minio-secret.yaml",
          "oc apply -f ${local.installerhome}/postgre-secret.yaml",
          "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
          "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${var.cpd-namespace})",
          "${local.installerhome}/cpd-linux adm -r ${local.installerhome}/repo.yaml -a watson-speech -n ${var.cpd-namespace} --accept-all-licenses --apply",
          "${local.installerhome}/cpd-linux --storageclass ${local.watson-speech-storageclass} -r ${local.installerhome}/repo.yaml -a watson-speech --version 1.1.4 -n ${var.cpd-namespace} --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses --override ${local.installerhome}/watson-speech-override.yaml --insecure-skip-tls-verify"
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
        null_resource.install_spss,
        null_resource.install_watson_assistant,
        null_resource.install_watson_discovery,
        null_resource.install_watson_knowledge_studio,
        null_resource.install_watson_language_translator,
    ]
}



