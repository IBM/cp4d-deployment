locals {
  #General
  installerhome = "/home/${var.admin-username}/ibm"
  userbinhome   = "/home/${var.admin-username}/bin"
  operator      = "/home/${var.admin-username}/operator"

  #Watson AI Services Storage Classes
  watson-asst-storageclass      = var.storage-type == "portworx" ? "portworx-assistant" : "gp2"
  watson-discovery-storageclass = var.storage-type == "portworx" ? "portworx-db-gp3" : "gp2"
  watson-ks-storageclass        = var.storage-type == "portworx" ? "portworx-db-gp3" : "gp2"
  watson-lt-storageclass        = var.storage-type == "portworx" ? "portworx-sc" : "gp2"
  watson-speech-storageclass    = var.storage-type == "portworx" ? "portworx-sc" : "gp2"

  override-value = var.storage-type == "efs" ? "\"\"" : var.storage-type
}

resource "null_resource" "cpd_config" {
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "oc create -f ${local.ocptemplates}/insecure-registry-mc.yaml",
      "oc create -f ${local.ocptemplates}/sysctl-machineconfig.yaml",
      "oc create -f ${local.ocptemplates}/security-limits-mc.yaml",
      "oc create -f ${local.ocptemplates}/crio-mc.yaml",
      "echo 'Sleeping for 12 minutes while MachineConfigs apply and the cluster restarts' ",
      "sleep 12m",

      "mkdir -p ${local.installerhome}",
      "mkdir -p ${local.operator}",
      "wget https://github.com/IBM/cloud-pak-cli/releases/download/${var.cloudctl-version}/cloudctl-linux-amd64.tar.gz -O ${local.operator}/cloudctl-linux-amd64.tar.gz",
      "wget https://github.com/IBM/cloud-pak-cli/releases/download/${var.cloudctl-version}/cloudctl-linux-amd64.tar.gz.sig -O ${local.operator}/cloudctl-linux-amd64.tar.gz.sig",
      #"curl https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cp-datacore-${var.datacore-version}.tgz -o /home/${var.admin-username}/ibm-cp-datacore-${var.datacore-version}.tgz",
      "sudo tar -xvf ${local.operator}/cloudctl-linux-amd64.tar.gz -C /usr/local/bin",
      "tar -xf /home/${var.admin-username}/ibm-cp-datacore-${var.datacore-version}.tgz",

      "oc annotate route default-route haproxy.router.openshift.io/timeout=600s -n openshift-image-registry",
      "oc patch svc/image-registry -p '{\"spec\":{\"sessionAffinity\": \"ClientIP\"}}' -n openshift-image-registry",
      "oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{\"spec\":{\"managementState\":\"Unmanaged\"}}'",
      "sleep 3m",
      "oc set env deployment/image-registry -n openshift-image-registry REGISTRY_STORAGE_S3_CHUNKSIZE=104857600",
      "sleep 2m",
      "./update-elb-timeout.sh ${local.vpcid} ${var.classic-lb-timeout}",
    ]
  }
  depends_on = [
    null_resource.install_ocs,
    null_resource.install_ocs_disconnected,
    null_resource.install_portworx,
    null_resource.install_portworx_disconnected,
    null_resource.install_efs,
  ]
}

resource "null_resource" "cpd_operator_connected" {
  count = var.disconnected-cluster == "no" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_public_ip
    user        = self.triggers.username
    private_key = file(self.triggers.private-key-file-path)
  }
  provisioner "remote-exec" {
    inline = [
      "oc new-project cpd-meta-ops",
      "./install-cpd-operator.sh ${var.api-key} cpd-meta-ops",
      "sleep 5m",
      "OP_STATUS=$(oc get pods -n cpd-meta-ops -l name=ibm-cp-data-operator --no-headers | awk '{print $3}')",
      "if [ $OP_STATUS != 'Running' ] ; then echo \"CPD Operator Installation Failed\" ; exit 1 ; fi",
      "oc new-project ${var.cpd-namespace}",
    ]
  }
  depends_on = [
    null_resource.cpd_config,
  ]
}

resource "null_resource" "cpd_operator_disconnected" {
  count = var.disconnected-cluster == "yes" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_public_ip
    user        = self.triggers.username
    private_key = file(self.triggers.private-key-file-path)
  }
  provisioner "remote-exec" {
    inline = [
      "sudo subscription-manager register --username=${var.redhat-username} --password=${var.redhat-password}",
      "sudo subscription-manager attach --auto",
      "sudo subscription-manager repos --enable=rhel-7-server-extras-rpms",
      "sudo yum install -y podman httpd-tools",

      "cat > /home/${var.admin-username}/repo.yaml <<EOL\n${data.template_file.repo.rendered}\nEOL",
      "wget https://github.com/IBM/cpd-cli/releases/download/${var.cpd-cli-version}/cpd-cli-linux-EE-3.5.1.tgz -O ${local.operator}/cpd-cli-linux-EE-3.5.1.tgz",
      "tar -xf ${local.operator}/cpd-cli-linux-EE-3.5.1.tgz -C ${local.operator}",
      "sudo mv ${local.operator}/cpd-cli ${local.operator}/plugins ${local.operator}/LICENSES /usr/local/bin",
      "mkdir -p /home/${var.admin-username}/offline",
      "sed -i -e s#CPDSERVICESLIST#${var.cpdservices-to-install}#g /home/${var.admin-username}/install-cpd-operator-airgap.sh",

      "oc new-project cpd-meta-ops",
      "./install-cpd-operator-airgap.sh ${var.api-key} ${var.local-registry} ${var.local-registry-username} ${var.local-registry-pwd}",
      "OP_STATUS=$(oc get pods -n cpd-meta-ops -l name=ibm-cp-data-operator --no-headers | awk '{print $3}')",
      "if [ $OP_STATUS != 'Running' ] ; then echo \"CPD Operator Installation Failed\" ; exit 1 ; fi",
      "oc new-project ${var.cpd-namespace}",
    ]
  }
  depends_on = [
    null_resource.cpd_config,
  ]
}

resource "null_resource" "install_lite" {
  count = var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-lite.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
      "sed -i -e s#SERVICE#lite#g ${local.installerhome}/cpd-lite.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-lite.yaml",
      "oc create -f ${local.installerhome}/cpd-lite.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh lite ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"Lite Installation Failed\" ; exit 1 ; fi",
    ]
  }
  depends_on = [
    null_resource.cpd_operator_connected,
    null_resource.cpd_operator_disconnected,
  ]
}

resource "null_resource" "install_dv" {
  count = var.data-virtualization == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-dv.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
      "sed -i -e s#SERVICE#dv#g ${local.installerhome}/cpd-dv.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-dv.yaml",
      "oc create -f ${local.installerhome}/cpd-dv.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh dv ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"DV Installation Failed\" ; exit 1 ; fi",
    ]
  }
  depends_on = [
    null_resource.install_lite,
  ]
}

resource "null_resource" "install_spark" {
  count = var.apache-spark == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-spark.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
      "sed -i -e s#SERVICE#spark#g ${local.installerhome}/cpd-spark.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-spark.yaml",
      "oc create -f ${local.installerhome}/cpd-spark.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh spark ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"Spark Installation Failed\" ; exit 1 ; fi",
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
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-wkc.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
      "sed -i -e s#SERVICE#wkc#g ${local.installerhome}/cpd-wkc.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-wkc.yaml",
      "oc create -f ${local.installerhome}/cpd-wkc.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh wkc ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"WKC Installation Failed\" ; exit 1 ; fi",
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
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-wsl.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
      "sed -i -e s#SERVICE#wsl#g ${local.installerhome}/cpd-wsl.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-wsl.yaml",
      "oc create -f ${local.installerhome}/cpd-wsl.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh wsl ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"WSL Installation Failed\" ; exit 1 ; fi",
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
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-wml.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
      "sed -i -e s#SERVICE#wml#g ${local.installerhome}/cpd-wml.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-wml.yaml",
      "oc create -f ${local.installerhome}/cpd-wml.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh wml ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"WML Installation Failed\" ; exit 1 ; fi",
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
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-aiopenscale.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
      "sed -i -e s#SERVICE#aiopenscale#g ${local.installerhome}/cpd-aiopenscale.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-aiopenscale.yaml",
      "oc create -f ${local.installerhome}/cpd-aiopenscale.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh aiopenscale ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"AIOpenscale Installation Failed\" ; exit 1 ; fi",
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
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-cde.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
      "sed -i -e s#SERVICE#cde#g ${local.installerhome}/cpd-cde.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-cde.yaml",
      "oc create -f ${local.installerhome}/cpd-cde.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh cde ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"CDE Installation Failed\" ; exit 1 ; fi",
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
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "sed -i -e s#STORAGECLASS#${lookup(var.streams-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-streams.yaml",
      "oc create -f ${local.installerhome}/cpd-streams.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh streams ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"Streams Installation Failed\" ; exit 1 ; fi",
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
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-streams-flows.yaml <<EOL\n${data.template_file.cpd-service-no-override.rendered}\nEOL",
      "sed -i -e s#SERVICE#streams-flows#g ${local.installerhome}/cpd-streams-flows.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-streams-flows.yaml",
      "oc create -f ${local.installerhome}/cpd-streams-flows.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh streams-flows ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"Streams-Flows Installation Failed\" ; exit 1 ; fi",
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
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-ds.yaml",
      "oc create -f ${local.installerhome}/cpd-ds.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh ds ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"DS Installation Failed\" ; exit 1 ; fi",
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
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-db2wh.yaml <<EOL\n${data.template_file.cpd-service-no-override.rendered}\nEOL",
      "sed -i -e s#SERVICE#db2wh#g ${local.installerhome}/cpd-db2wh.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-db2wh.yaml",
      "oc create -f ${local.installerhome}/cpd-db2wh.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh db2wh ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"Db2Wh Installation Failed\" ; exit 1 ; fi",
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
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-db2oltp.yaml <<EOL\n${data.template_file.cpd-service-no-override.rendered}\nEOL",
      "sed -i -e s#SERVICE#db2oltp#g ${local.installerhome}/cpd-db2oltp.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-db2oltp.yaml",
      "oc create -f ${local.installerhome}/cpd-db2oltp.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh db2oltp ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"Db2Oltp Installation Failed\" ; exit 1 ; fi",
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

resource "null_resource" "install_dmc" {
  count = var.data-management-console == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-dmc.yaml <<EOL\n${data.template_file.cpd-service-no-override.rendered}\nEOL",
      "sed -i -e s#SERVICE#dmc#g ${local.installerhome}/cpd-dmc.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-dmc.yaml",
      "oc create -f ${local.installerhome}/cpd-dmc.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh dmc ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"DMC Installation Failed\" ; exit 1 ; fi",
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

resource "null_resource" "install_datagate" {
  count = var.datagate == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-datagate.yaml",
      "oc create -f ${local.installerhome}/cpd-datagate.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh datagate ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"DataGate Installation Failed\" ; exit 1 ; fi",
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
    null_resource.install_dmc,
  ]
}

resource "null_resource" "install_dods" {
  count = var.decision-optimization == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-dods.yaml",
      "oc create -f ${local.installerhome}/cpd-dods.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh dods ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"DODS Installation Failed\" ; exit 1 ; fi",
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
    null_resource.install_dmc,
    null_resource.install_datagate,
  ]
}

resource "null_resource" "install_ca" {
  count = var.cognos-analytics == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-ca.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
      "sed -i -e s#SERVICE#ca#g ${local.installerhome}/cpd-ca.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-ca.yaml",
      "oc create -f ${local.installerhome}/cpd-ca.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh ca ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"CA Installation Failed\" ; exit 1 ; fi",
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
    null_resource.install_dmc,
    null_resource.install_datagate,
    null_resource.install_dods,
  ]
}

resource "null_resource" "install_spss" {
  count = var.spss-modeler == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-spss-modeler.yaml",
      "oc create -f ${local.installerhome}/cpd-spss-modeler.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh spss-modeler ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"SPSS-Modeler Installation Failed\" ; exit 1 ; fi",
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
    null_resource.install_dmc,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
  ]
}

resource "null_resource" "install_bigsql" {
  count = var.db2-bigsql == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-big-sql.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
      "sed -i -e s#SERVICE#big-sql#g ${local.installerhome}/cpd-big-sql.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.bigsql-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-big-sql.yaml",
      "oc create -f ${local.installerhome}/cpd-big-sql.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh big-sql ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"BigSql Installation Failed\" ; exit 1 ; fi",
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
    null_resource.install_dmc,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_spss,
  ]
}

resource "null_resource" "install_pa" {
  count = var.planning-analytics == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
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
      "cat > ${local.installerhome}/cpd-pa.yaml <<EOL\n${data.template_file.cpd-service.rendered}\nEOL",
      "sed -i -e s#SERVICE#pa#g ${local.installerhome}/cpd-pa.yaml",
      "sed -i -e s#STORAGECLASS#${lookup(var.cpd-storageclass, var.storage-type)}#g ${local.installerhome}/cpd-pa.yaml",
      "oc create -f ${local.installerhome}/cpd-pa.yaml -n ${var.cpd-namespace}",
      "./wait-for-service-install.sh pa ${var.cpd-namespace} ; if [ $? -ne 0 ] ; then echo \"PA Installation Failed\" ; exit 1 ; fi",
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
    null_resource.install_dmc,
    null_resource.install_datagate,
    null_resource.install_dods,
    null_resource.install_ca,
    null_resource.install_spss,
    null_resource.install_bigsql,
  ]
}

# resource "null_resource" "install_watson_assistant" {
#     count = var.watson-assistant == "yes" && var.storage-type != "ocs" && var.accept-cpd-license == "accept" ? 1 : 0 
#     triggers = {
#         bootnode_public_ip      = aws_instance.bootnode.public_ip
#         username                = var.admin-username
#         private-key-file-path   = var.ssh-private-key-file-path
#     }
#     connection {
#         type        = "ssh"
#         host        = self.triggers.bootnode_public_ip
#         user        = self.triggers.username
#         private_key = file(self.triggers.private-key-file-path)
#     }
#     provisioner "remote-exec" {
#         inline = [
#             "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
#             "cat > ${local.installerhome}/watson-asst-override.yaml <<EOL\n${data.template_file.watson-asst-override.rendered}\nEOL",
#             "oc adm policy add-scc-to-group restricted system:serviceaccounts:${var.cpd-namespace}",
#             "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
#             "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-asst-override.yaml",
#             "oc label --overwrite namespace ${var.cpd-namespace} ns=${var.cpd-namespace}",
#             "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
#             "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${var.cpd-namespace})",
#             "${local.userbinhome}/cpd-cli adm --repo ${local.installerhome}/repo.yaml -a ibm-watson-assistant -n ${var.cpd-namespace} --accept-all-licenses --apply",
#             "${local.userbinhome}/cpd-cli install --storageclass ${local.watson-asst-storageclass} --repo ${local.installerhome}/repo.yaml -a ibm-watson-assistant --version 1.4.2 -n ${var.cpd-namespace} --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses --override ${local.installerhome}/watson-asst-override.yaml --insecure-skip-tls-verify"
#         ]
#     }
#     depends_on = [
#         null_resource.install_lite,
#         null_resource.install_dv,
#         null_resource.install_spark,
#         null_resource.install_wkc,
#         null_resource.install_wsl,
#         null_resource.install_wml,
#         null_resource.install_aiopenscale,
#         null_resource.install_cde,
#         null_resource.install_streams,
#         null_resource.install_streams_flows,
#         null_resource.install_ds,
#         null_resource.install_db2wh,
#         null_resource.install_db2oltp,
#     	  null_resource.install_datagate,
#         null_resource.install_dods,
#         null_resource.install_ca,
#         null_resource.install_spss,
#     ]
# }

# resource "null_resource" "install_watson_discovery" {
#     count = var.watson-discovery == "yes" && var.storage-type != "ocs" && var.accept-cpd-license == "accept" ? 1 : 0
#     triggers = {
#         bootnode_public_ip      = aws_instance.bootnode.public_ip
#         username                = var.admin-username
#         private-key-file-path   = var.ssh-private-key-file-path
#     }
#     connection {
#         type        = "ssh"
#         host        = self.triggers.bootnode_public_ip
#         user        = self.triggers.username
#         private_key = file(self.triggers.private-key-file-path)
#     }
#     provisioner "remote-exec" {
#         inline = [
#             "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
#             "cat > ${local.installerhome}/watson-discovery-override.yaml <<EOL\n${data.template_file.watson-discovery-override.rendered}\nEOL",
#             "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
#             "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-discovery-override.yaml",
#             "host_ip=$(dig +short api.${var.cluster-name}.${var.dnszone} | awk 'NR==1{print $1}')",
#             "sed -i s/k8_host_ip/$host_ip/g ${local.installerhome}/watson-discovery-override.yaml",
#             "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
#             "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${var.cpd-namespace})",
#             "${local.userbinhome}/cpd-cli adm --repo ${local.installerhome}/repo.yaml -a watson-discovery -n ${var.cpd-namespace} --accept-all-licenses --apply",
#             "${local.userbinhome}/cpd-cli install --storageclass ${local.watson-discovery-storageclass} --repo ${local.installerhome}/repo.yaml -a watson-discovery -n ${var.cpd-namespace} --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses --override ${local.installerhome}/watson-discovery-override.yaml --insecure-skip-tls-verify"
#         ]
#     }
#     depends_on = [
#         null_resource.install_lite,
#         null_resource.install_dv,
#         null_resource.install_spark,
#         null_resource.install_wkc,
#         null_resource.install_wsl,
#         null_resource.install_wml,
#         null_resource.install_aiopenscale,
#         null_resource.install_cde,
#         null_resource.install_streams,
#         null_resource.install_streams_flows,
#         null_resource.install_ds,
#         null_resource.install_db2wh,
#         null_resource.install_db2oltp,
#     	  null_resource.install_datagate,
#         null_resource.install_dods,
#         null_resource.install_ca,
#         null_resource.install_spss,
#         null_resource.install_watson_assistant,
#     ]
# }

# resource "null_resource" "install_watson_knowledge_studio" {
#     count = var.watson-knowledge-studio == "yes" && var.storage-type != "ocs" && var.accept-cpd-license == "accept" ? 1 : 0
#     triggers = {
#         bootnode_public_ip      = aws_instance.bootnode.public_ip
#         username                = var.admin-username
#         private-key-file-path   = var.ssh-private-key-file-path
#     }
#     connection {
#         type        = "ssh"
#         host        = self.triggers.bootnode_public_ip
#         user        = self.triggers.username
#         private_key = file(self.triggers.private-key-file-path)
#     }
#     provisioner "remote-exec" {
#         inline = [
#             "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
#             "cat > ${local.installerhome}/watson-ks-override.yaml <<EOL\n${file("../cpd_module/watson-knowledge-studio-override.yaml")}\nEOL",
#             "oc label --overwrite namespace ${var.cpd-namespace} ns=${var.cpd-namespace}",
#             "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
#             "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${var.cpd-namespace})",
#             "${local.userbinhome}/cpd-cli adm --repo ${local.installerhome}/repo.yaml -a watson-ks -n ${var.cpd-namespace} --accept-all-licenses --apply",
#             "${local.userbinhome}/cpd-cli install --storageclass ${local.watson-ks-storageclass} --repo ${local.installerhome}/repo.yaml -a watson-ks -n ${var.cpd-namespace} --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses --override ${local.installerhome}/watson-ks-override.yaml --insecure-skip-tls-verify"
#         ]
#     }
#     depends_on = [
#         null_resource.install_lite,
#         null_resource.install_dv,
#         null_resource.install_spark,
#         null_resource.install_wkc,
#         null_resource.install_wsl,
#         null_resource.install_wml,
#         null_resource.install_aiopenscale,
#         null_resource.install_cde,
#         null_resource.install_streams,
#         null_resource.install_streams_flows,
#         null_resource.install_ds,
#         null_resource.install_db2wh,
#         null_resource.install_db2oltp,
#     	  null_resource.install_datagate,
#         null_resource.install_dods,
#         null_resource.install_ca,
#         null_resource.install_spss,
#         null_resource.install_watson_assistant,
#         null_resource.install_watson_discovery,
#     ]
# }

# resource "null_resource" "install_watson_language_translator" {
#     count = var.watson-language-translator == "yes" && var.storage-type != "ocs" && var.accept-cpd-license == "accept" ? 1 : 0
#     triggers = {
#         bootnode_public_ip      = aws_instance.bootnode.public_ip
#         username                = var.admin-username
#         private-key-file-path   = var.ssh-private-key-file-path
#     }
#     connection {
#         type        = "ssh"
#         host        = self.triggers.bootnode_public_ip
#         user        = self.triggers.username
#         private_key = file(self.triggers.private-key-file-path)
#     }
#     provisioner "remote-exec" {
#         inline = [
#             "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
#             "cat > ${local.installerhome}/watson-lt-override.yaml <<EOL\n${data.template_file.watson-language-translator-override.rendered}\nEOL",
#             "oc adm policy add-scc-to-group restricted system:serviceaccounts:${var.cpd-namespace}",
#             "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
#             "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-lt-override.yaml",
#             "oc label --overwrite namespace ${var.cpd-namespace} ns=${var.cpd-namespace}",
#             "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
#             "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${var.cpd-namespace})",
#             "${local.userbinhome}/cpd-cli adm --repo ${local.installerhome}/repo.yaml -a watson-language-translator -n ${var.cpd-namespace} --accept-all-licenses --apply",
#             "${local.userbinhome}/cpd-cli install --storageclass ${local.watson-lt-storageclass} --repo ${local.installerhome}/repo.yaml -a watson-language-translator --version 1.1.2 --optional-modules watson-language-pak-1 -n ${var.cpd-namespace} --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses --override ${local.installerhome}/watson-lt-override.yaml --insecure-skip-tls-verify"
#         ]
#     }
#     depends_on = [
#         null_resource.install_lite,
#         null_resource.install_dv,
#         null_resource.install_spark,
#         null_resource.install_wkc,
#         null_resource.install_wsl,
#         null_resource.install_wml,
#         null_resource.install_aiopenscale,
#         null_resource.install_cde,
#         null_resource.install_streams,
#         null_resource.install_streams_flows,
#         null_resource.install_ds,
#         null_resource.install_db2wh,
#         null_resource.install_db2oltp,
#     	  null_resource.install_datagate,
#         null_resource.install_dods,
#         null_resource.install_ca,
#         null_resource.install_spss,
#         null_resource.install_watson_assistant,
#         null_resource.install_watson_discovery,
#         null_resource.install_watson_knowledge_studio,
#     ]
# }

# resource "null_resource" "install_watson_speech" {
#     count = var.watson-speech == "yes" && var.storage-type != "ocs" && var.accept-cpd-license == "accept" ? 1 : 0
#     triggers = {
#         bootnode_public_ip      = aws_instance.bootnode.public_ip
#         username                = var.admin-username
#         private-key-file-path   = var.ssh-private-key-file-path
#     }
#     connection {
#         type        = "ssh"
#         host        = self.triggers.bootnode_public_ip
#         user        = self.triggers.username
#         private_key = file(self.triggers.private-key-file-path)
#     }
#     provisioner "remote-exec" {
#         inline = [
#             "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
#             "cat > ${local.installerhome}/watson-speech-override.yaml <<EOL\n${data.template_file.watson-speech-override.rendered}\nEOL",
#             "cat > ${local.installerhome}/minio-secret.yaml <<EOL\n${data.template_file.minio-secret.rendered}\nEOL",
#             "cat > ${local.installerhome}/postgre-secret.yaml <<EOL\n${data.template_file.postgre-secret.rendered}\nEOL",
#             "oc adm policy add-scc-to-group restricted system:serviceaccounts:${var.cpd-namespace}",
#             "docker_secret=$(oc get secrets | grep default-dockercfg | awk '{print $1}')",
#             "sed -i s/default-dockercfg-xxxxx/$docker_secret/g ${local.installerhome}/watson-speech-override.yaml",
#             "oc label --overwrite namespace ${var.cpd-namespace} ns=${var.cpd-namespace}",
#             "oc apply -f ${local.installerhome}/minio-secret.yaml",
#             "oc apply -f ${local.installerhome}/postgre-secret.yaml",
#             "REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')",
#             "TOKEN=$(oc serviceaccounts get-token cpdtoken -n ${var.cpd-namespace})",
#             "${local.userbinhome}/cpd-cli adm --repo ${local.installerhome}/repo.yaml -a watson-speech -n ${var.cpd-namespace} --accept-all-licenses --apply",
#             "${local.userbinhome}/cpd-cli install --storageclass ${local.watson-speech-storageclass} --repo ${local.installerhome}/repo.yaml -a watson-speech --version 1.1.4 -n ${var.cpd-namespace} --transfer-image-to $REGISTRY/${var.cpd-namespace} --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/${var.cpd-namespace} --target-registry-username kubeadmin --target-registry-password $TOKEN --accept-all-licenses --override ${local.installerhome}/watson-speech-override.yaml --insecure-skip-tls-verify"
#         ]
#     }
#     depends_on = [
#         null_resource.install_lite,
#         null_resource.install_dv,
#         null_resource.install_spark,
#         null_resource.install_wkc,
#         null_resource.install_wsl,
#         null_resource.install_wml,
#         null_resource.install_aiopenscale,
#         null_resource.install_cde,
#         null_resource.install_streams,
#         null_resource.install_streams_flows,
#         null_resource.install_ds,
#         null_resource.install_db2wh,
#         null_resource.install_db2oltp,
#     	  null_resource.install_datagate,
#         null_resource.install_dods,
#         null_resource.install_ca,
#         null_resource.install_spss,
#         null_resource.install_watson_assistant,
#         null_resource.install_watson_discovery,
#         null_resource.install_watson_knowledge_studio,
#         null_resource.install_watson_language_translator,
#     ]
# }
