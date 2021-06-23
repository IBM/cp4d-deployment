locals {
  #General
  installerhome = "/home/${var.admin-username}/ibm"

  # Operator
  operator = "/home/${var.admin-username}/operator"

  # Override
  override-value = var.storage == "nfs" ? "\"\"" : var.storage
  #Storage Classes
  cpd-storageclass       = lookup(var.cpd-storageclass, var.storage)
  ccs-class-or-vendor    = var.storage == "nfs" ? "Class" : "Vendor"
  ccs-storageclass-value = var.storage == "nfs" ? "nfs" : "portworx"
  storagevendor          = var.storage == "nfs" ? "\"\"" : var.storage

  wml-cr-file = var.storage == "nfs" ? data.template_file.wmlcrnfsfile.rendered : data.template_file.wmlcrpwxocsfile.rendered
  wsl-cr-file = var.storage == "nfs" ? data.template_file.wslcrnfsfile.rendered : data.template_file.wslcrpwxocsfile.rendered
  wkc-cr-file = var.storage == "nfs" ? data.template_file.wkccrnfsfile.rendered : data.template_file.wkccrpwxocsfile.rendered
  wkc-iis-cr-file = var.storage == "nfs" ? data.template_file.wkciiscrnfsfile.rendered : data.template_file.wkciiscrpwxocsfile.rendered
  wkc-ug-cr-file = var.storage == "nfs" ? data.template_file.wkcugcrnfsfile.rendered : data.template_file.wkcugcrpwxocsfile.rendered
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
      "cloudctl version",

      ## Downloading common files required for the execution of resources. 
      "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
      "sudo chmod +x pod-status-check.sh",
      "cat > check-cr-status.sh <<EOL\n${file("../cpd4_module/check-cr-status.sh")}\nEOL",
      "sudo chmod +x check-cr-status.sh",

      ## Installing jq

      "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
      "sudo mv jq /usr/local/bin",
      "sudo chmod +x /usr/local/bin/jq",

      ## OC login with kubeadmin user

      "cat > oc-login-with-kubeadmin.sh <<EOL\n${file("../cpd4_module/oc-login-with-kubeadmin.sh")}\nEOL",
      "sudo chmod +x oc-login-with-kubeadmin.sh",
      "./oc-login-with-kubeadmin.sh",
      "kubeadminpass=$(cat /home/core/ocpfourx/auth/kubeadmin-password)",
      "sudo oc login https://api.${var.cluster-name}.${var.dnszone}:6443 -u 'kubeadmin' -p '$kubeadminpass' --certificate-authority=/home/core/ocpfourx/ingress-ca.crt",
      "result=$(oc whoami)",
      "echo $result",

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

resource "null_resource" "cpd-setup-pull-secret-and-mirror-config" {
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

      "cd /home/${var.admin-username}/cpd-common-files",

      # Download Common files  

      "cat > cpd-mirror-config.yaml <<EOL\n${file("../cpd4_module/cpd-mirror-config.yaml")}\nEOL",
      "cat > setup-global-pull-secret-cpd.sh <<EOL\n${file("../cpd4_module/setup-global-pull-secret-cpd.sh")}\nEOL",

      # Setup global_pull secret 

      "sudo chmod +x setup-global-pull-secret-cpd.sh",
      "./setup-global-pull-secret-cpd.sh ${var.artifactory-username} ${var.artifactory-apikey} ${var.staging-username} ${var.staging-apikey}",
      # Set up image mirroring. Adding bootstrap artifactory so that the cluster can pull un-promoted catalog images (and zen images)

      "echo  '************************************************'",
      "echo  ' setting up imagecontentsource policy for CPD '",
      "echo  '************************************************'",

      "echo '*** executing **** oc create -f cpd-mirror-config.yaml'",
      "result=$(oc create -f cpd-mirror-config.yaml)",
      "echo $result",
      "echo 'Waiting 15 minutes for the nodes to get ready'",
      "sleep 15m",

      ## Checking if the nodes are ready. 

      "cat > node-status-check.sh <<EOL\n${file("../cpd4_module/node-status-check.sh")}\nEOL",
      "sudo chmod +x node-status-check.sh",
      "./node-status-check.sh",
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
      "cat > cpd-platform-operator-catalogsource.yaml <<EOL\n${file("../cpd4_module/cpd-platform-operator-catalogsource.yaml")}\nEOL",
      "cat > cpd-platform-operator-og.yaml <<EOL\n${file("../cpd4_module/cpd-platform-operator-og.yaml")}\nEOL",
      "cat > cpd-platform-operator-sub.yaml <<EOL\n${file("../cpd4_module/cpd-platform-operator-sub.yaml")}\nEOL",
      "cat > cpd-platform-operator-operandrequest.yaml <<EOL\n${file("../cpd4_module/cpd-platform-operator-operandrequest.yaml")}\nEOL",
      "cat > ibmcpd-cr.yaml <<EOL\n${data.template_file.ibmcpd-cr-file.rendered}\nEOL",

      # create bedrock catalog source 
      "echo '*** executing **** oc create -f bedrock-catalog-source.yaml'",
      "result=$(oc create -f bedrock-catalog-source.yaml)",
      "echo $result",
      "sleep 1m",

      # Waiting and checking till the opencloud operator is ready in the openshift-marketplace namespace 
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh opencloud-operator openshift-marketplace",

      # create cpd-platform catalog source 
      "echo '*** executing **** oc create -f cpd-platform-operator-catalogsource.yaml'",
      "result=$(oc create -f cpd-platform-operator-catalogsource.yaml)",
      "echo $result",
      "sleep 1m",

      # Waiting and checking till the cpd-platform operator is ready in the openshift-marketplace namespace 
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh cpd-platform openshift-marketplace",

      # Creating zen catalog source 
      "echo '*** executing **** oc create -f zen-catalog-source.yaml'",
      "result=$(oc create -f zen-catalog-source.yaml)",
      "echo $result",
      "sleep 1m",

      # Waiting and checking till the ibm-zen-operator-catalog is ready in the openshift-marketplace namespace 
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-zen-operator-catalog openshift-marketplace",

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
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh cpd-platform-operator-manager ${var.operator-namespace}",

      # Checking if the bedrock operator pods are ready and running. 
      # checking status of ibm-namespace-scope-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-namespace-scope-operator ${var.operator-namespace}",

      # checking status of operand-deployment-lifecycle-manager
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh operand-deployment-lifecycle-manager ${var.operator-namespace}",

      # checking status of ibm-common-service-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-common-service-operator ${var.operator-namespace}",

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
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/cpd-platform-operator/ibmcpd-cr.yaml",
      "echo '*** executing **** oc create -f ibmcpd-cr.yaml'",
      "result=$(oc create -f ibmcpd-cr.yaml)",
      "echo $result",

      # check if the zen operator pod is up and running.
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-zen-operator ${var.operator-namespace}",
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cert-manager-operator ${var.operator-namespace}",

      # Waiting and checking till the cert manager pods are ready in the openshift-marketplace namespace 
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh cert-manager-cainjector ${var.operator-namespace}",
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh cert-manager-controller ${var.operator-namespace}",
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh cert-manager-webhook ${var.operator-namespace}",

      # check the lite cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh ibmcpd ibmcpd-cr ${var.cpd-namespace} controlPlaneStatus",

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
    null_resource.cpd-setup-pull-secret-and-mirror-config,
  ]
}


# resource "null_resource" "bedrock_zen_operator" {
#   count = var.bedrock-zen-operator == "yes" ? 1 : 0
#   triggers = {
#     bootnode_ip_address   = local.bootnode_ip_address
#     username              = var.admin-username
#     private_key_file_path = var.ssh-private-key-file-path
#     namespace             = var.cpd-namespace
#   }
#   connection {
#     type        = "ssh"
#     host        = self.triggers.bootnode_ip_address
#     user        = self.triggers.username
#     private_key = file(self.triggers.private_key_file_path)
#   }
#   provisioner "remote-exec" {
#     inline = [
#       #Create directory
#       "mkdir -p /home/${var.admin-username}/bedrock-zen",

#       ## Copy the required yaml files for bedrock zen operator setup .. 

#       "cd /home/${var.admin-username}/bedrock-zen",

#       "cat > bedrock-edge-mirror.yaml <<EOL\n${file("../cpd4_module/bedrock-edge-mirror.yaml")}\nEOL",
#       "cat > bedrock-catalog-source.yaml <<EOL\n${file("../cpd4_module/bedrock-catalog-source.yaml")}\nEOL",
#       "cat > bedrock-operator-group.yaml <<EOL\n${file("../cpd4_module/bedrock-operator-group.yaml")}\nEOL",
#       "cat > bedrock-sub.yaml <<EOL\n${file("../cpd4_module/bedrock-sub.yaml")}\nEOL",
#       "cat > zen-catalog-source.yaml <<EOL\n${file("../cpd4_module/zen-catalog-source.yaml")}\nEOL",
#       "cat > zen-operandrequest.yaml <<EOL\n${file("../cpd4_module/zen-operandrequest.yaml")}\nEOL",
#       "cat > zen-lite-cr.yaml <<EOL\n${file("../cpd4_module/zen-lite-cr.yaml")}\nEOL",


#       # Set up image mirroring. Adding bootstrap artifactory so that the cluster can pull un-promoted catalog images (and zen images)

#       "echo  '*************************************'",
#       "echo 'setting up imagecontentsource policy for bedrock'",
#       "echo  '*************************************'",

#       "echo '*** executing **** oc create -f bedrock-edge-mirror.yaml'",
#       "result=$(oc create -f bedrock-edge-mirror.yaml)",
#       "echo $result",
#       # Setup global_pull secret 

#       "cat > setup-global-pull-secret-bedrock.sh <<EOL\n${file("../cpd4_module/setup-global-pull-secret-bedrock.sh")}\nEOL",
#       "sudo chmod +x setup-global-pull-secret-bedrock.sh",
#       "./setup-global-pull-secret-bedrock.sh ${var.artifactory-username} ${var.artifactory-apikey}",
#       "echo 'Waiting 15 minutes for the nodes to get ready'",
#       "sleep 15m",

#       # create bedrock catalog source 

#       "echo '*** executing **** oc create -f bedrock-catalog-source.yaml'",
#       "result=$(oc create -f bedrock-catalog-source.yaml)",
#       "echo $result",
#       "sleep 1m",

#       # Waiting and checking till the opencloud operator is ready in the openshift-marketplace namespace 

#       "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
#       "sudo chmod +x pod-status-check.sh",
#       "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh opencloud-operator openshift-marketplace",

#       # Creating the ibm-common-services namespace: 

#       "oc new-project ${var.operator-namespace}",
#       "oc project ${var.operator-namespace}",

#       # Create bedrock operator group: 

#       "echo '*** executing **** oc create -f bedrock-operator-group.yaml'",
#       "result=$(oc create -f bedrock-operator-group.yaml)",
#       "echo $result",
#       "sleep 1m",

#       # Create bedrock subscription. This will deploy the bedrock: 

#       "echo '*** executing **** oc create -f bedrock-sub.yaml'",
#       "result=$(oc create -f bedrock-sub.yaml)",
#       "echo $result",
#       "sleep 1m",

#       # Checking if the bedrock operator pods are ready and running. 

#       # checking status of ibm-common-service-operator

#       "cat > bedrock-pod-status-check.sh <<EOL\n${file("../cpd4_module/bedrock-pod-status-check.sh")}\nEOL",
#       "sudo chmod +x bedrock-pod-status-check.sh",
#       "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh -n ${var.cpd-namespace} ibm-common-service-operator  ${var.operator-namespace}",

#       # checking status of operand-deployment-lifecycle-manager

#       "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh operand-deployment-lifecycle-manager ${var.operator-namespace}",

#       # checking status of ibm-namespace-scope-operator

#       "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-namespace-scope-operator  ${var.operator-namespace}",

#       # Creating zen catalog source 

#       "echo '*** executing **** oc create -f zen-catalog-source.yaml'",
#       "result=$(oc create -f zen-catalog-source.yaml)",
#       "echo $result",
#       "sleep 1m",

#       # (Important) Edit operand registry *** 

#       "oc get operandregistry -n ${var.operator-namespace} -o yaml > operandregistry.yaml",
#       "cp operandregistry.yaml operandregistry.yaml_original",
#       "sed -i '/\\s\\s\\s\\s\\s\\spackageName: ibm-zen-operator/{n;n;s/.*/      sourceName: ibm-zen-operator-catalog/}' operandregistry.yaml ",
#       "sed -zEi 's/    - channel: v3([^\\n]*\\n[^\\n]*name: ibm-zen-operator)/    - channel: stable-v1\\1/' operandregistry.yaml",

#       "echo '*** executing **** oc create -f operandregistry.yaml'",
#       "result=$(oc apply -f operandregistry.yaml)",
#       "echo $result",

#       # Create zen namespace

#       "oc new-project ${var.cpd-namespace}",
#       "oc project ${var.cpd-namespace}",

#       # Create the zen operator 

#       "echo '*** executing **** oc create -f zen-operandrequest.yaml'",
#       "result=$(oc create -f zen-operandrequest.yaml)",
#       "echo $result",
#       "sleep 5m",

#       # check if the zen operator pod is up and running.

#       "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-zen-operator ${var.operator-namespace}",
#       "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cert-manager-operator ${var.operator-namespace}",

#       # Create lite CR: 

#       "echo '*** executing **** oc create -f zen-lite-cr.yaml'",
#       "result=$(oc create -f zen-lite-cr.yaml)",
#       "echo $result",

#       # check the lite cr status

#       "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
#       "sudo mv jq /usr/local/bin",
#       "sudo chmod +x /usr/local/bin/jq",
#       "cat > check-cr-status.sh <<EOL\n${file("../cpd4_module/check-cr-status.sh")}\nEOL",
#       "sudo chmod +x check-cr-status.sh",
#       "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh zenservice lite-cr ${var.cpd-namespace} zenStatus",
#     ]
#   }
#   depends_on = [
#     null_resource.openshift_post_install,
#     null_resource.install_portworx,
#     null_resource.setup_sc_with_pwx_encryption,
#     null_resource.setup_sc_without_pwx_encryption,
#     null_resource.install_ocs,
#     null_resource.install_nfs_client,
#     null_resource.install-cloudctl,
#     null_resource.cpd-setup-pull-secret-and-mirror-config,
#     null_resource.install-cpd-platform-operator
#   ]
# }

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
      "cat > ccs-cr.yaml <<EOL\n${file("../cpd4_module/ccs-cr.yaml")}\nEOL",

      ## Download the case package for CCS
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-ccs/1.0.0-746/ibm-ccs-1.0.0-746.tgz -o ibm-ccs-1.0.0-746.tgz",

      # Install ccs operator using CLI (OLM)
      "cat > install-ccs-operator.sh <<EOL\n${file("../cpd4_module/install-ccs-operator.sh")}\nEOL",
      "sudo chmod +x install-ccs-operator.sh",
      "./install-ccs-operator.sh ibm-ccs-1.0.0-746.tgz ${var.operator-namespace}",

      # Checking if the ccs operator pods are ready and running. 
      # checking status of ibm-cpd-ccs-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cpd-ccs-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create CCS CR: 
      "sed -i -e s#CLASS_OR_VENDOR#${local.ccs-class-or-vendor}#g /home/${var.admin-username}/ccs-files/ccs-cr.yaml",
      "sed -i -e s#REPLACE_STORAGECLASS#${local.ccs-storageclass-value}#g /home/${var.admin-username}/ccs-files/ccs-cr.yaml",
      "echo '*** executing **** oc create -f ccs-cr.yaml'",
      "result=$(oc create -f ccs-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh ccs ccs-cr ${var.cpd-namespace} ccsStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator

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

      ## Copy the required yaml files for wsl setup .. 
      "cd /home/${var.admin-username}/wsl-files",
      "cat > wsl-cr.yaml <<EOL\n${local.wsl-cr-file}\nEOL",
      "cat > resolvers.yaml <<EOL\n${file("../cpd4_module/wsl-resolvers.yaml")}\nEOL",
      "cat > resolversAuth.yaml <<EOL\n${data.template_file.wslresolversAuth.rendered}\nEOL",

      # ## Download the case package for wsl

      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/local/case-repo-local/ibm-wsl/2.0.0-382/ibm-wsl-2.0.0-382.tgz -o ibm-wsl-2.0.0-382.tgz",

      # Install wsl operator using CLI (OLM)
      "cd /home/${var.admin-username}/wsl-files/offline",
      "cat > install-wsl-operator.sh <<EOL\n${file("../cpd4_module/install-wsl-operator.sh")}\nEOL",
      "sudo chmod +x install-wsl-operator.sh",
      "./install-wsl-operator.sh ibm-wsl-2.0.0-382.tgz ${var.operator-namespace} ${var.gituser} ${var.gittoken}",

      # Checking if the wsl operator pods are ready and running. 
      # checking status of ibm-cpd-ws-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cpd-ws-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create wsl CR: 
      "cd /home/${var.admin-username}/wsl-files",
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/wsl-files/wsl-cr.yaml",
      "echo '*** executing **** oc create -f wsl-cr.yaml'",
      # "result=$(oc create -f wsl-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh ws ws-cr ${var.cpd-namespace} wsStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
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
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/local/case-repo-local/ibm-watson-openscale/2.0.0-237/ibm-watson-openscale-2.0.0-237.tgz -o ibm-watson-openscale-2.0.0-237.tgz",

      # Install OpenScale operator using CLI (OLM)
      "cat > install-openscale-operator.sh <<EOL\n${file("../cpd4_module/install-openscale-operator.sh")}\nEOL",
      "sudo chmod +x install-openscale-operator.sh",
      "./install-openscale-operator.sh ibm-watson-openscale-2.0.0-237.tgz ${var.operator-namespace}",

      # Checking if the openscale operator pods are ready and running. 
      # checking status of ibm-cpd-wos-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cpd-wos-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create openscale CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/aiopenscale-files/openscale-cr.yaml",
      "echo '*** executing **** oc create -f openscale-cr.yaml'",
      "result=$(oc create -f openscale-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh WOService aiopenscale ${var.cpd-namespace} wosStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
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
      # checking status of ibm-cpd-spss-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cpd-spss-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create spss CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/spss-files/spss-cr.yaml",
      "echo '*** executing **** oc create -f spss-cr.yaml'",
      "result=$(oc create -f spss-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh spss spss-cr ${var.cpd-namespace} spssmodelerStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
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
      "cat > wml-cr.yaml <<EOL\n${local.wml-cr-file}\nEOL",

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
      # checking status of ibm-cpd-wml-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cpd-wml-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create wml CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/wml-files/wml-cr.yaml",
      "echo '*** executing **** oc create -f wml-cr.yaml'",
      "result=$(oc create -f wml-cr.yaml)",
      "echo $result",

      # check the WML cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh WmlBase wml-cr ${var.cpd-namespace} wmlStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
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
      "cat > cde-cr.yaml <<EOL\n${file("../cpd4_module/cde-cr.yaml")}\nEOL",

      # Case package. 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-cde/2.0.0-17/ibm-cde-2.0.0-17.tgz -o ibm-cde-2.0.0-17.tgz",

      # # Install cde operator using CLI (OLM)
      "cat > install-cde-operator.sh <<EOL\n${file("../cpd4_module/install-cde-operator.sh")}\nEOL",
      "sudo chmod +x install-cde-operator.sh",
      "./install-cde-operator.sh ibm-cde-2.0.0-17.tgz ${var.operator-namespace}",

      # Checking if the cde operator pods are ready and running. 
      # checking status of ibm-cde-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cde-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create cde CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/cde-files/cde-cr.yaml",
      "echo '*** executing **** oc create -f cde-cr.yaml'",
      "result=$(oc create -f cde-cr.yaml)",
      "echo $result",

      # check the cde cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh CdeProxyService cde-cr ${var.cpd-namespace} cdeStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
    null_resource.install-wsl,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-wml,
  ]
}

### *** This module will need changes after GA as the image will be pulled from a public repo .
resource "null_resource" "install-dods" {
  count = var.dods == "yes" ? 1 : 0
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
      "mkdir -p /home/${var.admin-username}/dods-files",
      "mkdir -p /home/${var.admin-username}/dods-files/case-saved",

      ## Copy the required yaml files for ccs setup .. 
      "cd /home/${var.admin-username}/dods-files",
      "cat > dods-cr.yaml <<EOL\n${file("../cpd4_module/dods-cr.yaml")}\nEOL",
      "cat > resolvers.yaml <<EOL\n${file("../cpd4_module/dods-resolvers.yaml")}\nEOL",
      "cat > resolversAuth.yaml <<EOL\n${data.template_file.dodsresolversAuth.rendered}\nEOL",

      # Download the case package for dods
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-dods/4.0.0-175/ibm-dods-4.0.0-175.tgz -o ibm-dods-4.0.0-175.tgz",

      # Install dods operator using CLI (OLM)
      "cd /home/${var.admin-username}/dods-files/case-saved",
      "cat > install-dods-operator.sh <<EOL\n${file("../cpd4_module/install-dods-operator.sh")}\nEOL",
      "sudo chmod +x install-dods-operator.sh",
      "./install-dods-operator.sh ibm-dods-4.0.0-175.tgz ${var.operator-namespace}",

      # Checking if the dods operator pods are ready and running. 
      # checking status of ibm-cpd-dods-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cpd-dods-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create dods CR: 
      "cd /home/${var.admin-username}/dods-files",
      "echo '*** executing **** oc create -f dods-cr.yaml'",
      "result=$(oc create -f dods-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh DODS dods-cr ${var.cpd-namespace} dodsStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
    null_resource.install-wsl,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-wml,
    null_resource.install-cde,
  ]
}

resource "null_resource" "install-spark" {
  count = var.spark == "yes" ? 1 : 0
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
      "mkdir -p /home/${var.admin-username}/spark-files",

      ## Copy the required yaml files for spark setup .. 
      "cd /home/${var.admin-username}/spark-files",
      "cat > spark-cr.yaml <<EOL\n${file("../cpd4_module/spark-cr.yaml")}\nEOL",

      # Case package. 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-analyticsengine/4.0.0-209/ibm-analyticsengine-4.0.0-209.tgz -o ibm-analyticsengine-4.0.0-209.tgz",

      # # Install spark operator using CLI (OLM)
      "cat > install-spark-operator.sh <<EOL\n${file("../cpd4_module/install-spark-operator.sh")}\nEOL",
      "sudo chmod +x install-spark-operator.sh",
      "./install-spark-operator.sh ibm-analyticsengine-4.0.0-209.tgz ${var.operator-namespace}",

      # Checking if the spark operator pods are ready and running. 
      # checking status of ibm-cpd-ae-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cpd-ae-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create spark CR: 
      "sed -i -e s#REPLACE_SC#${local.cpd-storageclass}#g /home/${var.admin-username}/spark-files/spark-cr.yaml",
      "sed -i -e s#BUILD_NUMBER#4.0.0-209#g /home/${var.admin-username}/spark-files/spark-cr.yaml",
      "echo '*** executing **** oc create -f spark-cr.yaml'",
      "result=$(oc create -f spark-cr.yaml)",
      "echo $result",

      # check the spark cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh AnalyticsEngine analyticsengine-cr ${var.cpd-namespace} analyticsengineStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
    null_resource.install-wsl,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-wml,
    null_resource.install-cde,
    null_resource.install-dods,
  ]
}

resource "null_resource" "install-dv" {
  count = var.dv == "yes" ? 1 : 0
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
      "mkdir -p /home/${var.admin-username}/dv-files",

      ## Copy the required yaml files for dv setup .. 
      "cd /home/${var.admin-username}/dv-files",

      # Case package. 
      ## Db2u Operator 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-db2uoperator/4.0.0-3731.2361/ibm-db2uoperator-4.0.0-3731.2361.tgz -o ibm-db2uoperator-4.0.0-3731.2361.tgz",

      ## DMC Operator 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-dmc/4.0.0-253/ibm-dmc-4.0.0-253.tgz -o ibm-dmc-4.0.0-253.tgz",

      ## DV case 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-dv-case/1.7.0-115/ibm-dv-case-1.7.0-115.tgz -o ibm-dv-case-1.7.0-115.tgz",

      # # Install db2u operator using CLI (OLM)
      "cat > install-db2u-operator.sh <<EOL\n${file("../cpd4_module/install-db2u-operator.sh")}\nEOL",
      "sudo chmod +x install-db2u-operator.sh",
      "./install-db2u-operator.sh ibm-db2uoperator-4.0.0-3731.2361.tgz ${var.operator-namespace}",

      # Checking if the DB2U operator pods are ready and running. 
      # checking status of db2u-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh db2u-operator ${var.operator-namespace}",

      # # Install dmc operator using CLI (OLM)
      "cat > install-dmc-operator.sh <<EOL\n${file("../cpd4_module/install-dmc-operator.sh")}\nEOL",
      "sudo chmod +x install-dmc-operator.sh",
      "./install-dmc-operator.sh ibm-dmc-4.0.0-253.tgz ${var.operator-namespace} ${local.cpd-storageclass}",

      # Checking if the dmc operator pods are ready and running. 
      # checking status of dmc-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-dmc-controller ${var.operator-namespace}",

      # # Install dv operator using CLI (OLM)
      "cat > install-dv-operator.sh <<EOL\n${file("../cpd4_module/install-dv-operator.sh")}\nEOL",
      "sudo chmod +x install-dv-operator.sh",
      "./install-dv-operator.sh ibm-dv-case-1.7.0-115.tgz ${var.operator-namespace}",

      # Checking if the dv operator pods are ready and running. 
      # checking status of ibm-dv-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-dv-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # # Install dv Customer Resource
      "cat > install-dv-cr.sh <<EOL\n${file("../cpd4_module/install-dv-cr.sh")}\nEOL",
      "sudo chmod +x install-dv-cr.sh",
      "./install-dv-cr.sh ibm-dv-case-1.7.0-115.tgz ${var.cpd-namespace}",

      # check the dv cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh dvservice dv-service ${var.cpd-namespace} reconcileStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
    null_resource.install-wsl,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-wml,
    null_resource.install-cde,
    null_resource.install-dods,
    null_resource.install-spark,
  ]
}

resource "null_resource" "install-bigsql" {
  count = var.bigsql == "yes" ? 1 : 0
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
      "mkdir -p /home/${var.admin-username}/bigsql-files",

      ## Copy the required yaml files for bigsql setup .. 
      "cd /home/${var.admin-username}/bigsql-files",

      # Case package. 
      ## Db2u Operator 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-db2uoperator/4.0.0-3731.2361/ibm-db2uoperator-4.0.0-3731.2361.tgz -o ibm-db2uoperator-4.0.0-3731.2361.tgz",

      ## bigsql case package 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-bigsql-case/7.2.0-115/ibm-bigsql-case-7.2.0-115.tgz -o ibm-bigsql-case-7.2.0-115.tgz",

      # # Install db2u operator using CLI (OLM)
      "cat > install-db2u-operator.sh <<EOL\n${file("../cpd4_module/install-db2u-operator.sh")}\nEOL",
      "sudo chmod +x install-db2u-operator.sh",
      "./install-db2u-operator.sh ibm-db2uoperator-4.0.0-3731.2361.tgz ${var.operator-namespace}",

      # Checking if the db2u operator pods are ready and running. 
      # checking status of db2u-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh db2u-operator ${var.operator-namespace}",

      # # Install bigsql operator using CLI (OLM)
      "cat > install-bigsql-operator.sh <<EOL\n${file("../cpd4_module/install-bigsql-operator.sh")}\nEOL",
      "sudo chmod +x install-bigsql-operator.sh",
      "./install-bigsql-operator.sh ibm-bigsql-case-7.2.0-115.tgz ${var.operator-namespace}",

      # Checking if the bigsql operator pods are ready and running. 
      # checking status of ibm-bigsql-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-bigsql-operator ${var.operator-namespace}",

      # switch to zen namespace

      "oc project ${var.cpd-namespace}",

      # # Install bigsql Customer Resource

      "cat > install-bigsql-cr.sh <<EOL\n${file("../cpd4_module/install-bigsql-cr.sh")}\nEOL",
      "sudo chmod +x install-bigsql-cr.sh",
      "./install-bigsql-cr.sh ibm-bigsql-case-7.2.0-115.tgz ${var.cpd-namespace}",

      # check the bigsql cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh bigsqlservice bigsql-service ${var.cpd-namespace} reconcileStatus",
    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
    null_resource.install-wsl,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-wml,
    null_resource.install-cde,
    null_resource.install-dods,
    null_resource.install-spark,
    null_resource.install-dv,
  ]
}

resource "null_resource" "install-wkc" {
  count = var.wkc == "yes" ? 1 : 0
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
      "mkdir -p /home/${var.admin-username}/wkc-files",

      # Copy the required yaml files for wkc setup .. 
      "cd /home/${var.admin-username}/wkc-files",
      "cat > wkc-cr.yaml <<EOL\n${local.wkc-cr-file}\nEOL",
      "cat > db2aaservice-cr.yaml <<EOL\n${file("../cpd4_module/db2aaservice-cr.yaml")}\nEOL",
      "cat > wkc-iis-scc.yaml <<EOL\n${file("../cpd4_module/wkc-iis-scc.yaml")}\nEOL",
      "cat > wkc-iis-cr.yaml <<EOL\n${local.wkc-iis-cr-file}\nEOL",
      "cat > wkc-ug-cr.yaml <<EOL\n${local.wkc-ug-cr-file}\nEOL",

      # Creating the db2 sysctl config shell script.

      "cat > sysctl-config-db2.sh <<EOL\n${file("../cpd4_module/sysctl-config-db2.sh")}\nEOL",
      "sudo chmod +x sysctl-config-db2.sh",
      "./sysctl-config-db2.sh",

      # Case package. 
      ## Db2u Operator 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-db2uoperator/4.0.0-3731.2361/ibm-db2uoperator-4.0.0-3731.2361.tgz -o ibm-db2uoperator-4.0.0-3731.2361.tgz",

      # Case package. 
      ## Db2asaservice 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-db2aaservice/4.0.0-1228.749/ibm-db2aaservice-4.0.0-1228.749.tgz -o ibm-db2aaservice-4.0.0-1228.749.tgz",


      # ## wkc case package 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-wkc/4.0.0-416/ibm-wkc-4.0.0-416.tgz -o ibm-wkc-4.0.0-416.tgz",

      # ## IIS case package 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-iis/4.0.0-355/ibm-iis-4.0.0-355.tgz -o ibm-iis-4.0.0-355.tgz",

      # # Install db2u operator using CLI (OLM)
      "cat > install-db2u-operator.sh <<EOL\n${file("../cpd4_module/install-db2u-operator.sh")}\nEOL",
      "sudo chmod +x install-db2u-operator.sh",
      "./install-db2u-operator.sh ibm-db2uoperator-4.0.0-3731.2361.tgz ${var.operator-namespace}",

      # Checking if the db2u operator pods are ready and running. 
      # checking status of db2u-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh db2u-operator ${var.operator-namespace}",

      # # Install db2aaservice operator using CLI (OLM)
      "cat > install-db2aaservice-operator.sh <<EOL\n${file("../cpd4_module/install-db2aaservice-operator.sh")}\nEOL",
      "sudo chmod +x install-db2aaservice-operator.sh",
      "./install-db2aaservice-operator.sh ibm-db2aaservice-4.0.0-1228.749.tgz ${var.operator-namespace}",

      # Checking if the db2aaservice operator pods are ready and running. 
      # checking status of db2aaservice-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-db2aaservice-cp4d-operator-controller-manager ${var.operator-namespace}",

      # switch to zen namespace

      "oc project ${var.cpd-namespace}",

      # Install db2aaservice Customer Resource

      "echo '*** executing **** oc create -f db2aaservice-cr.yaml'",
      "result=$(oc create -f db2aaservice-cr.yaml)",
      "echo $result",

      # check the db2aaservice cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh Db2aaserviceService db2aaservice-cr ${var.cpd-namespace} db2aaserviceStatus",

      # # Install wkc operator using CLI (OLM)
      "cat > install-wkc-operator.sh <<EOL\n${file("../cpd4_module/install-wkc-operator.sh")}\nEOL",
      "sudo chmod +x install-wkc-operator.sh",
      "./install-wkc-operator.sh ibm-wkc-4.0.0-416.tgz ${var.operator-namespace}",

      # Checking if the wkc operator pods are ready and running. 
      # checking status of ibm-wkc-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cpd-wkc-operator ${var.operator-namespace}",

      # switch to zen namespace

      "oc project ${var.cpd-namespace}",

      # # Install wkc Customer Resource

      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/wkc-files/wkc-cr.yaml",
      "echo '*** executing **** oc create -f wkc-cr.yaml'",
      "result=$(oc create -f wkc-cr.yaml)",
      "echo $result",

      # check the wkc cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh wkc wkc-cr ${var.cpd-namespace} wkcStatus",

      ## IIS cr installation 

      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g /home/${var.admin-username}/wkc-files/wkc-iis-scc.yaml",
      "echo '*** executing **** oc create -f wkc-iis-scc.yaml'",
      "result=$(oc create -f wkc-iis-scc.yaml)",
      "echo $result",
     
      # Install IIS operator using CLI (OLM)

      "cat > install-wkc-iis-operator.sh <<EOL\n${file("../cpd4_module/install-wkc-iis-operator.sh")}\nEOL",
      "sudo chmod +x install-wkc-iis-operator.sh",
      "./install-wkc-iis-operator.sh ibm-iis-4.0.0-355.tgz ${var.operator-namespace}",

      # Checking if the wkc iis operator pods are ready and running. 
      # checking status of ibm-cpd-iis-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cpd-iis-operator ${var.operator-namespace}",

      # switch to zen namespace

      "oc project ${var.cpd-namespace}",

      # # Install wkc Customer Resource

      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/wkc-files/wkc-iis-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g /home/${var.admin-username}/wkc-files/wkc-iis-cr.yaml",
      "echo '*** executing **** oc create -f wkc-iis-cr.yaml'",
      "result=$(oc create -f wkc-iis-cr.yaml)",
      "echo $result",

      # check the wkc cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh iis iis-cr ${var.cpd-namespace} iisStatus",

      # switch to zen namespace

      "oc project ${var.cpd-namespace}",

      # # Install wkc Customer Resource

      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/wkc-files/wkc-ug-cr.yaml",
      "echo '*** executing **** oc create -f wkc-ug-cr.yaml'",
      "result=$(oc create -f wkc-ug-cr.yaml)",
      "echo $result",

      # check the wkc cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh ug ug-cr ${var.cpd-namespace} ugStatus",
    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
    null_resource.install-wsl,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-wml,
    null_resource.install-cde,
    null_resource.install-dods,
    null_resource.install-spark,
    null_resource.install-dv,
    null_resource.install-bigsql,
  ]
}


resource "null_resource" "install-ca" {
  count = var.ca == "yes" ? 1 : 0
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
      "mkdir -p /home/${var.admin-username}/ca-files",

      ## Copy the required yaml files for ca setup .. 
      "cd /home/${var.admin-username}/ca-files",
      "cat > ca-cr.yaml <<EOL\n${file("../cpd4_module/ca-cr.yaml")}\nEOL",

      # Case package. 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-cognos-analytics-prod/4.0.0-591/ibm-cognos-analytics-prod-4.0.0-591.tgz -o ibm-cognos-analytics-prod-4.0.0-591.tgz

      # Install ca operator using CLI (OLM)
      "cat > install-ca-operator.sh <<EOL\n${file("../cpd4_module/install-ca-operator.sh")}\nEOL",
      "sudo chmod +x install-ca-operator.sh",
      "./install-ca-operator.sh ibm-cognos-analytics-prod-4.0.0-591.tgz ${var.operator-namespace}",

      # Checking if the ca operator pods are ready and running. 
      # checking status of ca-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ca-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create ca CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/ca-files/ca-cr.yaml",
      "echo '*** executing **** oc create -f ca-cr.yaml'",
      "result=$(oc create -f ca-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh CAService ca-cr ${var.cpd-namespace} caAddonStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
  ]
}


resource "null_resource" "install-ds" {
  count = var.ds == "yes" ? 1 : 0
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
      "mkdir -p /home/${var.admin-username}/ds-files",

      ## Copy the required yaml files for ca setup .. 
      "cd /home/${var.admin-username}/ds-files",
      "cat > ds-cr.yaml <<EOL\n${file("../cpd4_module/ds-cr.yaml")}\nEOL",

      # Case package. 
      "curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-datastage/4.0.0-521/ibm-datastage-4.0.0-521.tgz -o ibm-datastage-4.0.0-521.tgz

      # Install ds operator using CLI (OLM)
      "cat > install-ds-operator.sh <<EOL\n${file("../cpd4_module/install-ds-operator.sh")}\nEOL",
      "sudo chmod +x install-ds-operator.sh",
      "./install-ca-operator.sh ibm-datastage-4.0.0-521.tgz ${var.operator-namespace}",

      # Checking if the ca operator pods are ready and running. 
      # checking status of ca-operator
      "/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ds-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create ds CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/ds-files/ds-cr.yaml",
      "echo '*** executing **** oc create -f ds-cr.yaml'",
      "result=$(oc create -f ds-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "/home/${var.admin-username}/cpd-common-files/check-cr-status.sh DataStageService ds-cr ${var.cpd-namespace} dsStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret-and-mirror-config,
    null_resource.install-cpd-platform-operator,
    #null_resource.bedrock_zen_operator,
    null_resource.install-ccs,
    null_resource.install-iis,
  ]
}
