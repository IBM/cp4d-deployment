locals {
  #General
  installerhome = "/home/${var.admin-username}/ibm"

  # Operator
  operator = "/home/${var.admin-username}/operator"

  # Override
  override-value = var.storage == "nfs" ? "\"\"" : var.storage
  #Storage Classes
  cpd-storageclass = lookup(var.cpd-storageclass, var.storage)
  ccs-class-or-vendor = var.storage == "nfs" ? "Class" : "Vendor"
  ccs-storageclass-value = var.storage == "nfs" ? "nfs" : "portworx"
  storagevendor = var.storage == "nfs" ? "\"\"" : var.storage
  # streams-storageclass = lookup(var.streams-storageclass, var.storage)
  # bigsql-storageclass  = lookup(var.bigsql-storageclass, var.storage)

  //watson-asst-storageclass = var.storage == "portworx" ? "portworx-assistant" : "managed-premium"
  //watson-discovery-storageclass = var.storage == "portworx" ? "portworx-db-gp3" : "managed-premium"
}

resource "null_resource" "install-cloudctl" {
  triggers = {
    bootnode_ip_address   = local.bootnode_ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    namespace             = var.cpd-namespace
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [

      ## Create directory to keep the files. 

      "mkdir -p /home/${var.admin-username}/cpd-common-files",

      ## Download and install cloudctl  

      "cd /home/${var.admin-username}/cpd-common-files",

      # Download cloudctl and aiopenscale case package. 

      "wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.7.1/cloudctl-linux-amd64.tar.gz",
      "wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.7.1/cloudctl-linux-amd64.tar.gz.sig",
      "sudo tar -xvf cloudctl-linux-amd64.tar.gz -C /usr/local/bin",
      "sudo mv /usr/local/bin/cloudctl-linux-amd64 /usr/local/bin/cloudctl",
      "cloudctl version"
    ]
  }
  depends_on = [
    null_resource.openshift_post_install,
    null_resource.install_portworx,
    null_resource.setup_sc_with_pwx_encryption,
    null_resource.setup_sc_without_pwx_encryption,
    null_resource.install_ocs,
    null_resource.install_nfs_client,
  ]
}


resource "null_resource" "install-cpd-platform-operator" {
  count = var.cpd-platform-operator == "yes" ? 1 : 0
  triggers = {
    bootnode_ip_address   = local.bootnode_ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    namespace             = var.cpd-namespace
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [

      # Create directory
      "mkdir -p /home/${var.admin-username}/cpd-platform-operator",

      # Copy the required yaml files for bedrock zen operator setup .. 

      "cd /home/${var.admin-username}/cpd-platform-operator",

      "cat > bedrock-catalog-source.yaml <<EOL\n${file("../cpd4_module/bedrock-catalog-source.yaml")}\nEOL",
      "cat > zen-catalog-source.yaml <<EOL\n${file("../cpd4_module/zen-catalog-source.yaml")}\nEOL",
      "cat > bedrock-edge-mirror-cpd-platform-operator.yaml <<EOL\n${file("../cpd4_module/bedrock-edge-mirror-cpd-platform-operator.yaml")}\nEOL",
      "cat > cpd-platform-operator-catalogsource.yaml <<EOL\n${file("../cpd4_module/cpd-platform-operator-catalogsource.yaml")}\nEOL",
      "cat > cpd-platform-operator-og.yaml <<EOL\n${file("../cpd4_module/cpd-platform-operator-og.yaml")}\nEOL",
      "cat > cpd-platform-operator-sub.yaml <<EOL\n${file("../cpd4_module/cpd-platform-operator-sub.yaml")}\nEOL",
      "cat > cpd-platform-operator-operandrequest.yaml <<EOL\n${file("../cpd4_module/cpd-platform-operator-operandrequest.yaml")}\nEOL",
      "cat > ibmcpd-cr.yaml <<EOL\n${data.template_file.ibmcpd-cr-file.rendered}\nEOL",

      # Setup global_pull secret 

      "cat > setup-global-pull-secret-bedrock-cpd-po.sh <<EOL\n${file("../cpd4_module/setup-global-pull-secret-bedrock-cpd-po.sh")}\nEOL",
      "sudo chmod +x setup-global-pull-secret-bedrock-cpd-po.sh",
      "./setup-global-pull-secret-bedrock-cpd-po.sh ${var.artifactory-username} ${var.artifactory-apikey}",
      # Set up image mirroring. Adding bootstrap artifactory so that the cluster can pull un-promoted catalog images (and zen images)

      "echo  '*************************************************************'",
      "echo  ' setting up imagecontentsource policy for platform operator  '",
      "echo  '*************************************************************'",

      "echo '*** executing **** oc create -f bedrock-edge-mirror-cpd-platform-operator.yaml'",
      "result=$(oc create -f bedrock-edge-mirror-cpd-platform-operator.yaml)",
      "echo $result",
      "echo 'Waiting 15 minutes for the nodes to get ready'",
      "sleep 15m",

      # create bedrock catalog source 

      "echo '*** executing **** oc create -f bedrock-catalog-source.yaml'",
      "result=$(oc create -f bedrock-catalog-source.yaml)",
      "echo $result",
      "sleep 1m",

      # Waiting and checking till the opencloud operator is ready in the openshift-marketplace namespace 

      "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
      "sudo chmod +x pod-status-check.sh",
      "./pod-status-check.sh opencloud-operator openshift-marketplace",

      # create cpd-platform catalog source 

      "echo '*** executing **** oc create -f cpd-platform-operator-catalogsource.yaml'",
      "result=$(oc create -f cpd-platform-operator-catalogsource.yaml)",
      "echo $result",
      "sleep 1m",

      # Waiting and checking till the cpd-platform operator is ready in the openshift-marketplace namespace 

      "./pod-status-check.sh cpd-platform openshift-marketplace",

      # Creating zen catalog source 

      "echo '*** executing **** oc create -f zen-catalog-source.yaml'",
      "result=$(oc create -f zen-catalog-source.yaml)",
      "echo $result",
      "sleep 1m",

      # Waiting and checking till the ibm-zen-operator-catalog is ready in the openshift-marketplace namespace 

      "./pod-status-check.sh ibm-zen-operator-catalog openshift-marketplace",

      # Creating the ibm-common-services namespace: 

      "oc new-project ${var.operator-namespace}",
      "oc new-project ${var.cpd-namespace}",
      "oc project ${var.operator-namespace}",

      # Create cpd-operator operator group: 

      "echo '*** executing **** oc create -f cpd-platform-operator-og.yaml'",
      "result=$(oc create -f cpd-platform-operator-og.yaml)",
      "echo $result",
      "sleep 1m",


      # Create cpd-platform-operator subscription. This will deploy the bedrock and zen: 

      "echo '*** executing **** oc create -f cpd-platform-operator-sub.yaml'",
      "result=$(oc create -f cpd-platform-operator-sub.yaml)",
      "echo $result",
      "sleep 1m",

      # Waiting and checking till the cpd-platform-operator-manager pod is up in ibm-common-services namespace.  

      "./pod-status-check.sh cpd-platform-operator-manager ${var.operator-namespace}",

      # Checking if the bedrock operator pods are ready and running. 

      # checking status of ibm-namespace-scope-operator

      "cat > bedrock-pod-status-check.sh <<EOL\n${file("../cpd4_module/bedrock-pod-status-check.sh")}\nEOL",
      "sudo chmod +x bedrock-pod-status-check.sh",
      "./bedrock-pod-status-check.sh ibm-namespace-scope-operator ${var.operator-namespace}",

      # checking status of operand-deployment-lifecycle-manager

      "./bedrock-pod-status-check.sh operand-deployment-lifecycle-manager ${var.operator-namespace}",

      # checking status of ibm-common-service-operator

      "./bedrock-pod-status-check.sh ibm-common-service-operator ${var.operator-namespace}",

      # (Important) Edit operand registry *** 

      "oc get operandregistry -n ${var.operator-namespace} -o yaml > operandregistry.yaml",
      "cp operandregistry.yaml operandregistry.yaml_original",
      "sed -i '/\\s\\s\\s\\s\\s\\spackageName: ibm-zen-operator/{n;n;s/.*/      sourceName: ibm-zen-operator-catalog/}' operandregistry.yaml ",
      "sed -zEi 's/    - channel: v3([^\\n]*\\n[^\\n]*name: ibm-zen-operator)/    - channel: stable-v1\\1/' operandregistry.yaml",

      "echo '*** executing **** oc create -f operandregistry.yaml'",
      "result=$(oc apply -f operandregistry.yaml)",
      "echo $result",

      # Create cpd-platform-operator operand request. This creates the zen operator.

      "echo '*** executing **** oc create -f cpd-platform-operator-operandrequest.yaml'",
      "result=$(oc create -f cpd-platform-operator-operandrequest.yaml)",
      "echo $result",
      "sleep 1m",

      # Create lite ibmcpd-CR: 

      "oc project ${var.cpd-namespace}",
      "sed -i -e s#STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/cpd-platform-operator/ibmcpd-cr.yaml",
      "echo '*** executing **** oc create -f ibmcpd-cr.yaml'",
      "result=$(oc create -f ibmcpd-cr.yaml)",
      "echo $result",

      # check if the zen operator pod is up and running.

      "./bedrock-pod-status-check.sh ibm-zen-operator ${var.operator-namespace}",
      "./bedrock-pod-status-check.sh ibm-cert-manager-operator ${var.operator-namespace}",

      # check the lite cr status

      "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
      "sudo mv jq /usr/local/bin",
      "sudo chmod +x /usr/local/bin/jq",
      "cat > check-ibmcpd-cr-status.sh <<EOL\n${file("../cpd4_module/check-ibmcpd-cr-status.sh")}\nEOL",
      "sudo chmod +x check-ibmcpd-cr-status.sh",
      "./check-ibmcpd-cr-status.sh ibmcpd ibmcpd-cr ${var.cpd-namespace}",
    ]
  }
  depends_on = [
    null_resource.openshift_post_install,
    null_resource.install_portworx,
    null_resource.setup_sc_with_pwx_encryption,
    null_resource.setup_sc_without_pwx_encryption,
    null_resource.install_ocs,
    null_resource.install_nfs_client,
    null_resource.install-cloudctl
  ]
}


resource "null_resource" "bedrock_zen_operator" {
  count = var.bedrock-zen-operator == "yes" ? 1 : 0
  triggers = {
    bootnode_ip_address   = local.bootnode_ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    namespace             = var.cpd-namespace
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [
      #Create directory
      "mkdir -p /home/${var.admin-username}/bedrock-zen",

      ## Copy the required yaml files for bedrock zen operator setup .. 

      "cd /home/${var.admin-username}/bedrock-zen",

      "cat > bedrock-edge-mirror.yaml <<EOL\n${file("../cpd4_module/bedrock-edge-mirror.yaml")}\nEOL",
      "cat > bedrock-catalog-source.yaml <<EOL\n${file("../cpd4_module/bedrock-catalog-source.yaml")}\nEOL",
      "cat > bedrock-operator-group.yaml <<EOL\n${file("../cpd4_module/bedrock-operator-group.yaml")}\nEOL",
      "cat > bedrock-sub.yaml <<EOL\n${file("../cpd4_module/bedrock-sub.yaml")}\nEOL",
      "cat > zen-catalog-source.yaml <<EOL\n${file("../cpd4_module/zen-catalog-source.yaml")}\nEOL",
      "cat > zen-operandrequest.yaml <<EOL\n${file("../cpd4_module/zen-operandrequest.yaml")}\nEOL",
      "cat > zen-lite-cr.yaml <<EOL\n${file("../cpd4_module/zen-lite-cr.yaml")}\nEOL",


      # Set up image mirroring. Adding bootstrap artifactory so that the cluster can pull un-promoted catalog images (and zen images)

      "echo  '*************************************'",
      "echo 'setting up imagecontentsource policy for bedrock'",
      "echo  '*************************************'",

      "echo '*** executing **** oc create -f bedrock-edge-mirror.yaml'",
      "result=$(oc create -f bedrock-edge-mirror.yaml)",
      "echo $result",
      # Setup global_pull secret 

      "cat > setup-global-pull-secret-bedrock.sh <<EOL\n${file("../cpd4_module/setup-global-pull-secret-bedrock.sh")}\nEOL",
      "sudo chmod +x setup-global-pull-secret-bedrock.sh",
      "./setup-global-pull-secret-bedrock.sh ${var.artifactory-username} ${var.artifactory-apikey}",
      "echo 'Waiting 15 minutes for the nodes to get ready'",
      "sleep 15m",

      # create bedrock catalog source 

      "echo '*** executing **** oc create -f bedrock-catalog-source.yaml'",
      "result=$(oc create -f bedrock-catalog-source.yaml)",
      "echo $result",
      "sleep 1m",

      # Waiting and checking till the opencloud operator is ready in the openshift-marketplace namespace 

      "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
      "sudo chmod +x pod-status-check.sh",
      "./pod-status-check.sh opencloud-operator openshift-marketplace",

      # Creating the ibm-common-services namespace: 

      "oc new-project ${var.operator-namespace}",
      "oc project ${var.operator-namespace}",

      # Create bedrock operator group: 

      "echo '*** executing **** oc create -f bedrock-operator-group.yaml'",
      "result=$(oc create -f bedrock-operator-group.yaml)",
      "echo $result",
      "sleep 1m",

      # Create bedrock subscription. This will deploy the bedrock: 

      "echo '*** executing **** oc create -f bedrock-sub.yaml'",
      "result=$(oc create -f bedrock-sub.yaml)",
      "echo $result",
      "sleep 1m",

      # Checking if the bedrock operator pods are ready and running. 

      # checking status of ibm-common-service-operator

      "cat > bedrock-pod-status-check.sh <<EOL\n${file("../cpd4_module/bedrock-pod-status-check.sh")}\nEOL",
      "sudo chmod +x bedrock-pod-status-check.sh",
      "./bedrock-pod-status-check.sh -n ${var.cpd-namespace} ibm-common-service-operator  ${var.operator-namespace}",

      # checking status of operand-deployment-lifecycle-manager

      "./bedrock-pod-status-check.sh operand-deployment-lifecycle-manager ${var.operator-namespace}",

      # checking status of ibm-namespace-scope-operator

      "./bedrock-pod-status-check.sh ibm-namespace-scope-operator  ${var.operator-namespace}",

      # Creating zen catalog source 

      "echo '*** executing **** oc create -f zen-catalog-source.yaml'",
      "result=$(oc create -f zen-catalog-source.yaml)",
      "echo $result",
      "sleep 1m",

      # (Important) Edit operand registry *** 

      "oc get operandregistry -n ${var.operator-namespace} -o yaml > operandregistry.yaml",
      "cp operandregistry.yaml operandregistry.yaml_original",
      "sed -i '/\\s\\s\\s\\s\\s\\spackageName: ibm-zen-operator/{n;n;s/.*/      sourceName: ibm-zen-operator-catalog/}' operandregistry.yaml ",
      "sed -zEi 's/    - channel: v3([^\\n]*\\n[^\\n]*name: ibm-zen-operator)/    - channel: stable-v1\\1/' operandregistry.yaml",

      "echo '*** executing **** oc create -f operandregistry.yaml'",
      "result=$(oc apply -f operandregistry.yaml)",
      "echo $result",

      # Create zen namespace

      "oc new-project ${var.cpd-namespace}",
      "oc project ${var.cpd-namespace}",

      # Create the zen operator 

      "echo '*** executing **** oc create -f zen-operandrequest.yaml'",
      "result=$(oc create -f zen-operandrequest.yaml)",
      "echo $result",
      "sleep 5m",

      # check if the zen operator pod is up and running.

      "./bedrock-pod-status-check.sh ibm-zen-operator ${var.operator-namespace}",
      "./bedrock-pod-status-check.sh ibm-cert-manager-operator ${var.operator-namespace}",

      # Create lite CR: 

      "echo '*** executing **** oc create -f zen-lite-cr.yaml'",
      "result=$(oc create -f zen-lite-cr.yaml)",
      "echo $result",

      # check the lite cr status

      "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
      "sudo mv jq /usr/local/bin",
      "sudo chmod +x /usr/local/bin/jq",
      "cat > check-cr-status.sh <<EOL\n${file("../cpd4_module/check-cr-status.sh")}\nEOL",
      "sudo chmod +x check-cr-status.sh",
      "./check-cr-status.sh zenservice lite-cr ${var.cpd-namespace} zenStatus",
    ]
  }
  depends_on = [
    null_resource.openshift_post_install,
    null_resource.install_portworx,
    null_resource.setup_sc_with_pwx_encryption,
    null_resource.setup_sc_without_pwx_encryption,
    null_resource.install_ocs,
    null_resource.install_nfs_client,
    null_resource.install-cloudctl,
    null_resource.install-cpd-platform-operator
  ]
}

### Installing CCS service. 


resource "null_resource" "install-ccs" {
  count = var.ccs == "yes" ? 1 : 0
  triggers = {
    bootnode_ip_address   = local.bootnode_ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    namespace             = var.cpd-namespace
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [
      # #Create directory
      "mkdir -p /home/${var.admin-username}/ccs-files",

      ## Copy the required yaml files for ccs setup .. 

      "cd /home/${var.admin-username}/ccs-files",

      "cat > ccs-mirror.yaml <<EOL\n${file("../cpd4_module/ccs-mirror.yaml")}\nEOL",
      # "cat > ccs-catalog-source.yaml <<EOL\n${file("../cpd4_module/ccs-catalog-source.yaml")}\nEOL",
      # "cat > ccs-sub.yaml <<EOL\n${file("../cpd4_module/ccs-sub.yaml")}\nEOL",
      "cat > ccs-cr.yaml <<EOL\n${file("../cpd4_module/ccs-cr.yaml")}\nEOL",

      ## Download the case package for CCS

      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-ccs/1.0.0-746/ibm-ccs-1.0.0-746.tgz -o ibm-ccs-1.0.0-746.tgz",

      # Set up image mirroring. Adding bootstrap artifactory so that the cluster can pull un-promoted catalog images (and zen images)

      "echo  '*************************************'",
      "echo 'setting up imagecontentsource policy for ccs'",
      "echo  '*************************************'",

      "echo '*** executing **** oc create -f ccs-mirror.yaml'",
      "result=$(oc create -f ccs-mirror.yaml)",
      "echo $result",

      ##Setup global_pull secret 

      "cat > setup-global-pull-secret-ccs.sh <<EOL\n${file("../cpd4_module/setup-global-pull-secret-ccs.sh")}\nEOL",
      "sudo chmod +x setup-global-pull-secret-ccs.sh",
      "./setup-global-pull-secret-ccs.sh ${var.staging-username} ${var.staging-apikey}",
      "echo 'sleeping 15 minutest untill the nodes get ready'",
      "sleep 15m",

      # Install ccs operator using CLI (OLM)

      "cat > install-ccs-operator.sh <<EOL\n${file("../cpd4_module/install-ccs-operator.sh")}\nEOL",
      "sudo chmod +x install-ccs-operator.sh",
      "./install-ccs-operator.sh ibm-ccs-1.0.0-746.tgz ${var.operator-namespace}",

      # Checking if the ccs operator pods are ready and running. 

      # checking status of ibm-cpd-ccs-operator

      "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
      "sudo chmod +x pod-status-check.sh",
      # "OPERATOR_POD_NAME=$(oc get pods -n ${var.operator-namespace} | grep ibm-cpd-ccs-operator | awk '{print $1}')",
      "./pod-status-check.sh ibm-cpd-ccs-operator ${var.operator-namespace}",

      # switch zen namespace

      "oc project ${var.cpd-namespace}",

      # Create CCS CR: 
      
      "sed -i -e s#CLASS_OR_VENDOR#${local.ccs-class-or-vendor}#g /home/${var.admin-username}/ccs-files/ccs-cr.yaml",
      "sed -i -e s#STORAGECLASS#${local.ccs-storageclass-value}#g /home/${var.admin-username}/ccs-files/ccs-cr.yaml",
      "echo '*** executing **** oc create -f ccs-cr.yaml'",
      "result=$(oc create -f ccs-cr.yaml)",
      "echo $result",

      # check the CCS cr status

      "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
      "sudo mv jq /usr/local/bin",
      "sudo chmod +x /usr/local/bin/jq",
      "cat > check-cr-status.sh <<EOL\n${file("../cpd4_module/check-cr-status.sh")}\nEOL",
      "sudo chmod +x check-cr-status.sh",
      "./check-cr-status.sh ccs ccs-cr ${var.cpd-namespace} ccsStatus",
    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.install-cpd-platform-operator,
    null_resource.bedrock_zen_operator

  ]
}


resource "null_resource" "install-wsl" {
  count = var.wsl == "yes" ? 1 : 0
  triggers = {
    bootnode_ip_address   = local.bootnode_ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    namespace             = var.cpd-namespace
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [
      #Create directory
      "mkdir -p /home/${var.admin-username}/wsl-files",
      "mkdir -p /home/${var.admin-username}/wsl-files/offline",

      ## Copy the required yaml files for ccs setup .. 

      "cd /home/${var.admin-username}/wsl-files",

      # "cat > wsl-catalog-source.yaml <<EOL\n${file("../cpd4_module/wsl-catalog-source.yaml")}\nEOL",
      # "cat > wsl-sub.yaml <<EOL\n${file("../cpd4_module/wsl-sub.yaml")}\nEOL",
      "cat > wsl-cr.yaml <<EOL\n${file("../cpd4_module/wsl-cr.yaml")}\nEOL",
      "cat > resolvers.yaml <<EOL\n${file("../cpd4_module/wsl-resolvers.yaml")}\nEOL",
      "cat > resolversAuth.yaml <<EOL\n${data.template_file.wslresolversAuth.rendered}\nEOL",



      ## Download the case package for wsl

      #"curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/local/case-repo-local/ibm-wsl/2.0.0-372/ibm-wsl-2.0.0-372.tgz -o ibm-wsl-2.0.0-372.tgz",

      # # create wsl catalog source 

      # "echo '*** executing **** oc create -f wsl-catalog-source.yaml'",
      # "result=$(oc create -f wsl-catalog-source.yaml)",
      # "echo $result",
      # "sleep 1m",

      # # Create wsl subscription. This will deploy the wsl: 

      # "echo '*** executing **** oc create -f wsl-sub.yaml'",
      # "result=$(oc create -f wsl-sub.yaml -n ${var.operator-namespace})",
      # "echo $result",
      # "sleep 1m",

      # Install wsl operator using CLI (OLM)
      "cd /home/${var.admin-username}/wsl-files/offline",
      "cat > install-wsl-operator.sh <<EOL\n${file("../cpd4_module/install-wsl-operator.sh")}\nEOL",
      "sudo chmod +x install-wsl-operator.sh",
      "./install-wsl-operator.sh ibm-wsl-2.0.0-372.tgz ${var.operator-namespace} ${var.gituser} ${var.gittoken}",

      # Checking if the wsl operator pods are ready and running. 

      # checking status of ibm-cpd-ws-operator

      "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
      "sudo chmod +x pod-status-check.sh",
      # "OPERATOR_POD_NAME=$(oc get pods -n ${var.operator-namespace} | grep ibm-cpd-ws-operator | awk '{print $1}')",
      "./pod-status-check.sh ibm-cpd-ws-operator ${var.operator-namespace}",

      # switch zen namespace

      "oc project ${var.cpd-namespace}",

      # Create wsl CR: 
      "cd /home/${var.admin-username}/wsl-files",
      "sed -i -e s#STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/wsl-files/wsl-cr.yaml",
      "sed -i -e s#STORAGEVENDOR#${local.storagevendor}#g /home/${var.admin-username}/wsl-files/wsl-cr.yaml",
      "echo '*** executing **** oc create -f wsl-cr.yaml'",
      "result=$(oc create -f wsl-cr.yaml)",
      "echo $result",

      # check the CCS cr status

      "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
      "sudo mv jq /usr/local/bin",
      "sudo chmod +x /usr/local/bin/jq",
      "cat > check-cr-status.sh <<EOL\n${file("../cpd4_module/check-cr-status.sh")}\nEOL",
      "sudo chmod +x check-cr-status.sh",
      "./check-cr-status.sh ws ws-cr ${var.cpd-namespace} wsStatus",
    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.install-cpd-platform-operator,
    null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
  ]
}


resource "null_resource" "install-aiopenscale" {
  count = var.aiopenscale == "yes" ? 1 : 0
  triggers = {
    bootnode_ip_address   = local.bootnode_ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    namespace             = var.cpd-namespace
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [
      #Create directory
      "mkdir -p /home/${var.admin-username}/aiopenscale-files",

      ## Copy the required yaml files for aiopenscale setup .. 

      "cd /home/${var.admin-username}/aiopenscale-files",

      "cat > openscale-cr.yaml <<EOL\n${file("../cpd4_module/openscale-cr.yaml")}\nEOL",

      # Case package. 

      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/local/case-repo-local/ibm-watson-openscale/2.0.0-190/ibm-watson-openscale-2.0.0-190.tgz -o ibm-watson-openscale-2.0.0-190.tgz",


      # Install OpenScale operator using CLI (OLM)

      "cat > install-openscale-operator.sh <<EOL\n${file("../cpd4_module/install-openscale-operator.sh")}\nEOL",
      "sudo chmod +x install-openscale-operator.sh",
      "./install-openscale-operator.sh ibm-watson-openscale-2.0.0-190.tgz ${var.operator-namespace}",

      # Checking if the openscale operator pods are ready and running. 

      # checking status of ibm-watson-openscale-operator

      "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
      "sudo chmod +x pod-status-check.sh",
      # "OPERATOR_POD_NAME=$(oc get pods -n ${var.operator-namespace} | grep ibm-watson-openscale-operator | awk '{print $1}')",
      "./pod-status-check.sh ibm-watson-openscale-operator ${var.operator-namespace}",

      # switch zen namespace

      "oc project ${var.cpd-namespace}",

      # Create openscale CR: 

      "sed -i -e s#STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/aiopenscale-files/openscale-cr.yaml",
      "echo '*** executing **** oc create -f openscale-cr.yaml'",
      "result=$(oc create -f openscale-cr.yaml)",
      "echo $result",

      # check the CCS cr status

      "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
      "sudo mv jq /usr/local/bin",
      "sudo chmod +x /usr/local/bin/jq",
      "cat > check-cr-status.sh <<EOL\n${file("../cpd4_module/check-cr-status.sh")}\nEOL",
      "sudo chmod +x check-cr-status.sh",
      "./check-cr-status.sh WOService aiopenscale ${var.cpd-namespace} wosStatus",
    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.install-cpd-platform-operator,
    null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
    null_resource.install-wsl,
  ]
}

resource "null_resource" "install-spss" {
  count = var.spss == "yes" ? 1 : 0
  triggers = {
    bootnode_ip_address   = local.bootnode_ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    namespace             = var.cpd-namespace
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [
      #Create directory
      "mkdir -p /home/${var.admin-username}/spss-files",

      ## Copy the required yaml files for spss setup .. 

      "cd /home/${var.admin-username}/spss-files",

      "cat > spss-cr.yaml <<EOL\n${file("../cpd4_module/spss-cr.yaml")}\nEOL",

      # Case package. 

      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-spss/1.0.0-153/ibm-spss-1.0.0-153.tgz -o ibm-spss-1.0.0-153.tgz",


      # # Install spss operator using CLI (OLM)

      "cat > install-spss-operator.sh <<EOL\n${file("../cpd4_module/install-spss-operator.sh")}\nEOL",
      "sudo chmod +x install-spss-operator.sh",
      "./install-spss-operator.sh ibm-spss-1.0.0-153.tgz ${var.operator-namespace}",

      # Checking if the spss operator pods are ready and running. 

      # checking status of ibm-watson-spss-operator

      "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
      "sudo chmod +x pod-status-check.sh",
      # "OPERATOR_POD_NAME=$(oc get pods -n ${var.operator-namespace} | grep ibm-watson-spss-operator | awk '{print $1}')",
      "./pod-status-check.sh ibm-cpd-spss-operator ${var.operator-namespace}",

      # switch zen namespace

      "oc project ${var.cpd-namespace}",

      # Create spss CR: 

      "echo '*** executing **** oc create -f spss-cr.yaml'",
      "result=$(oc create -f spss-cr.yaml)",
      "echo $result",

      # check the CCS cr status

      "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
      "sudo mv jq /usr/local/bin",
      "sudo chmod +x /usr/local/bin/jq",
      "cat > check-cr-status.sh <<EOL\n${file("../cpd4_module/check-cr-status.sh")}\nEOL",
      "sudo chmod +x check-cr-status.sh",
      "./check-cr-status.sh spss spss-cr ${var.cpd-namespace} spssmodelerStatus",
    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.install-cpd-platform-operator,
    null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
    null_resource.install-wsl,
    null_resource.install-aiopenscale,
  ]
}

resource "null_resource" "install-wml" {
  count = var.wml == "yes" ? 1 : 0
  triggers = {
    bootnode_ip_address   = local.bootnode_ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    namespace             = var.cpd-namespace
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }

  provisioner "file" {
    source      = "../cpd4_module/ibm-wml-cpd-4.0.0-1380.tgz"
    destination = "/home/core/ocpfourx/ibm-wml-cpd-4.0.0-1380.tgz"
  }
  provisioner "remote-exec" {
    inline = [
      #Create directory
      "mkdir -p /home/${var.admin-username}/wml-files",

      ## Copy the required yaml files for wml setup .. 

      "cd /home/${var.admin-username}/wml-files",

      "cat > wml-cr.yaml <<EOL\n${file("../cpd4_module/wml-cr.yaml")}\nEOL",

      # Case package. 
      ### Currently the case package is in ibm internal site. Hence downloading it and keeping it as part of the repo.

      # "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-wml/1.0.0-153/ibm-wml-1.0.0-153.tgz -o ibm-wml-1.0.0-153.tgz",

      "cp /home/core/ocpfourx/ibm-wml-cpd-4.0.0-1380.tgz .",
      # "cat > ibm-wml-cpd-4.0.0-1380.tgz	 <<EOL\n${file("../cpd4_module/ibm-wml-cpd-4.0.0-1380.tgz")}\nEOL",

      ###### If CCS is installed already , the ccs catalog source would be already created. 
      ###### If not we need to create CCS catalog source as the first step before we proceed here. 
      ######

      # # Install wml operator using CLI (OLM)

      "cat > install-wml-operator.sh <<EOL\n${file("../cpd4_module/install-wml-operator.sh")}\nEOL",
      "sudo chmod +x install-wml-operator.sh",
      "./install-wml-operator.sh ibm-wml-cpd-4.0.0-1380.tgz ${var.operator-namespace}",

      # Checking if the wml operator pods are ready and running. 

      # checking status of ibm-watson-wml-operator

      "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
      "sudo chmod +x pod-status-check.sh",
      # "OPERATOR_POD_NAME=$(oc get pods -n ${var.operator-namespace} | grep ibm-watson-wml-operator | awk '{print $1}')",
      "./pod-status-check.sh ibm-cpd-wml-operator ${var.operator-namespace}",

      # switch zen namespace

      "oc project ${var.cpd-namespace}",

      # Create wml CR: 

      "echo '*** executing **** oc create -f wml-cr.yaml'",
      "result=$(oc create -f wml-cr.yaml)",
      "echo $result",

      # check the WML cr status

      "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
      "sudo mv jq /usr/local/bin",
      "sudo chmod +x /usr/local/bin/jq",
      "cat > check-cr-status.sh <<EOL\n${file("../cpd4_module/check-cr-status.sh")}\nEOL",
      "sudo chmod +x check-cr-status.sh",
      "./check-cr-status.sh WmlBase wml-cr ${var.cpd-namespace} wmlStatus",
    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.install-cpd-platform-operator,
    null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
    null_resource.install-wsl,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
  ]
}


resource "null_resource" "install-cde" {
  count = var.cde == "yes" ? 1 : 0
  triggers = {
    bootnode_ip_address   = local.bootnode_ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    namespace             = var.cpd-namespace
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }

  provisioner "remote-exec" {
    inline = [
      #Create directory
      "mkdir -p /home/${var.admin-username}/cde-files",

      ## Copy the required yaml files for cde setup .. 

      "cd /home/${var.admin-username}/cde-files",

      "cat > cde-mirror.yaml <<EOL\n${file("../cpd4_module/cde-mirror.yaml")}\nEOL",
      "cat > cde-cr.yaml <<EOL\n${file("../cpd4_module/cde-cr.yaml")}\nEOL",

      # Setup global_pull secret 

      "cat > setup-global-pull-secret-cde.sh <<EOL\n${file("../cpd4_module/setup-global-pull-secret-cde.sh")}\nEOL",
      "sudo chmod +x setup-global-pull-secret-cde.sh",
      "./setup-global-pull-secret-cde.sh ${var.artifactory-username} ${var.artifactory-apikey}",

      # Set up image mirroring. Adding bootstrap artifactory so that the cluster can pull un-promoted catalog images (and zen images)

      "echo  '*************************************************************'",
      "echo  ' setting up imagecontentsource policy for cde operator  '",
      "echo  '*************************************************************'",

      "echo '*** executing **** oc create -f cde-mirror.yaml'",
      "result=$(oc create -f cde-mirror.yaml)",
      "echo $result",
      "echo 'Waiting 15 minutes for the nodes to get ready'",
      "sleep 15m",


      # Case package. 

      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-cde/2.0.0-17/ibm-cde-2.0.0-17.tgz -o ibm-cde-2.0.0-17.tgz",

      # # Install cde operator using CLI (OLM)

      "cat > install-cde-operator.sh <<EOL\n${file("../cpd4_module/install-cde-operator.sh")}\nEOL",
      "sudo chmod +x install-cde-operator.sh",
      "./install-cde-operator.sh ibm-cde-2.0.0-17.tgz ${var.operator-namespace}",

      # Checking if the cde operator pods are ready and running. 

      # checking status of ibm-watson-cde-operator

      "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
      "sudo chmod +x pod-status-check.sh",
      # "OPERATOR_POD_NAME=$(oc get pods -n ${var.operator-namespace} | grep ibm-watson-cde-operator | awk '{print $1}')",
      "./pod-status-check.sh ibm-cde-operator ${var.operator-namespace}",

      # switch zen namespace

      "oc project ${var.cpd-namespace}",

      # Create cde CR: 

      "echo '*** executing **** oc create -f cde-cr.yaml'",
      "result=$(oc create -f cde-cr.yaml)",
      "echo $result",

      # check the cde cr status

      "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
      "sudo mv jq /usr/local/bin",
      "sudo chmod +x /usr/local/bin/jq",
      "cat > check-cr-status.sh <<EOL\n${file("../cpd4_module/check-cr-status.sh")}\nEOL",
      "sudo chmod +x check-cr-status.sh",
      "./check-cr-status.sh CdeProxyService cde-cr ${var.cpd-namespace} cdeStatus",
    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.install-cpd-platform-operator,
    null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
    null_resource.install-wsl,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-wml,
  ]
}
