locals {
  #General
  cpd-installer-home = "/home/${var.admin-username}/cpd4.0"
  cpd-common-files   = "/home/${var.admin-username}/cpd4.0/cpd-common-files"
  cpd-repo-url       = "https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case"

  #Storage Classes
  cpd-storageclass = lookup(var.cpd-storageclass, var.storage)
  storagevendor    = var.storage == "nfs" ? "\"\"" : var.storage

  ## CR Files 
  ibmcpd-cr-file = var.storage == "nfs" ? data.template_file.ibmcpd-cr-nfs-file.rendered : data.template_file.ibmcpd-cr-pwx-ocs-file.rendered
  wml-cr-file    = var.storage == "nfs" ? data.template_file.wmlcrnfsfile.rendered : data.template_file.wmlcrpwxocsfile.rendered
  wsl-cr-file    = var.storage == "nfs" ? data.template_file.wslcrnfsfile.rendered : data.template_file.wslcrpwxocsfile.rendered
  wkc-cr-file    = var.storage == "nfs" ? data.template_file.wkccrnfsfile.rendered : data.template_file.wkccrpwxocsfile.rendered

}

resource "null_resource" "install-prereqs" {
  count = var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-common-files}",

      ## Download and install prereqs  
      "cd ${local.cpd-common-files}",

      ## Downloading common files required for the execution of resources. 
      "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
      "sudo chmod +x pod-status-check.sh",
      "cat > check-cr-status.sh <<EOL\n${file("../cpd4_module/check-cr-status.sh")}\nEOL",
      "sudo chmod +x check-cr-status.sh",
      "cat > check-subscription-status.sh <<EOL\n${file("../cpd4_module/check-subscription-status.sh")}\nEOL",
      "sudo chmod +x check-subscription-status.sh",

      ## Installing jq
      "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
      "sudo mv jq /usr/local/bin",
      "sudo chmod +x /usr/local/bin/jq",

      ## OC login with kubeadmin user
      # "cat > oc-login-with-kubeadmin.sh <<EOL\n${file("../cpd4_module/oc-login-with-kubeadmin.sh")}\nEOL",
      # "sudo chmod +x oc-login-with-kubeadmin.sh",
      # "./oc-login-with-kubeadmin.sh",
      # "kubeadminpass=$(cat /home/core/ocpfourx/auth/kubeadmin-password)",
      # "sudo oc login https://api.${var.cluster-name}.${var.dnszone}:6443 -u 'kubeadmin' -p '$kubeadminpass' --certificate-authority=/home/core/ocpfourx/ingress-ca.crt",
      "sudo oc login https://api.${var.cluster-name}.${var.dnszone}:6443 -u '${var.openshift-username}' -p '${var.openshift-password}' --insecure-skip-tls-verify=true",
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

resource "null_resource" "cpd-setup-pull-secret" {
  count = var.accept-cpd-license == "accept" ? 1 : 0
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

      "cd ${local.cpd-common-files}",

      # Download Common files  
      "cat > setup-global-pull-secret-prod.sh <<EOL\n${file("../cpd4_module/setup-global-pull-secret-prod.sh")}\nEOL",

      # Setup global_pull secret 
      "sudo chmod +x setup-global-pull-secret-prod.sh",
      "./setup-global-pull-secret-prod.sh cp ${var.apikey}",

      # Creating the db2 sysctl config shell script.
      "cat > sysctl-config-db2.sh <<EOL\n${file("../cpd4_module/sysctl-config-db2.sh")}\nEOL",
      "sudo chmod +x sysctl-config-db2.sh",
      "./sysctl-config-db2.sh",
      "sleep 2m",

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
    null_resource.install-prereqs,
  ]
}

resource "null_resource" "install-cpd-platform-operator" {
  count = var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-platform-operator",

      # Copy the required yaml files for bedrock zen operator setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-platform-operator",
      "cat > ibm-operator-catalogsource.yaml <<EOL\n${file("../cpd4_module/ibm-operator-catalogsource.yaml")}\nEOL",
      "cat > ibm-operator-og.yaml <<EOL\n${file("../cpd4_module/ibm-operator-og.yaml")}\nEOL",
      "cat > cpd-platform-operator-sub.yaml <<EOL\n${data.template_file.cpdsubfile.rendered}\nEOL",
      "cat > cpd-platform-operator-operandrequest.yaml <<EOL\n${data.template_file.cpdoperandrequestfile.rendered}\nEOL",
      "cat > ibmcpd-cr.yaml <<EOL\n${local.ibmcpd-cr-file}\nEOL",
      "cat > db2u-catalog-source.yaml <<EOL\n${file("../cpd4_module/db2u-catalog-source.yaml")}\nEOL",

      # create IBM Operator catalog source 
      "echo '*** executing **** oc apply -f ibm-operator-catalogsource.yaml'",
      "result=$(oc apply -f ibm-operator-catalogsource.yaml)",
      "echo $result",

      # Waiting and checking till the opencloud operator is ready in the openshift-marketplace namespace 
      "${local.cpd-common-files}/pod-status-check.sh ibm-operator-catalog openshift-marketplace",

      # Creating the ibm-common-services namespace: 
      "oc new-project ${var.operator-namespace}",
      "oc new-project ${var.cpd-namespace}",
      "oc project ${var.operator-namespace}",

      # Create ibm-operator operator group: 
      "echo '*** executing **** oc apply -f ibm-operator-og.yaml'",
      "result=$(oc apply -f ibm-operator-og.yaml)",
      "echo $result",

      # # Create ibm-operator subscription. This will deploy the bedrock and zen: 
      # "echo '*** executing **** oc apply -f ibm-operator-sub.yaml'",
      # "result=$(oc apply -f ibm-operator-sub.yaml)",
      # "echo $result",
      # "sleep 1m",

      # Create cpd-platform-operator subscription. This will deploy the bedrock and zen: 
      "echo '*** executing **** oc apply -f cpd-platform-operator-sub.yaml'",
      "result=$(oc apply -f cpd-platform-operator-sub.yaml)",
      "echo $result",


      #Check subcription status
      "${local.cpd-common-files}/check-subscription-status.sh cpd-operator ${var.operator-namespace} state",

      # Waiting and checking till the cpd-platform-operator-manager pod is up in ibm-common-services namespace.  
      "${local.cpd-common-files}/pod-status-check.sh cpd-platform-operator-manager ${var.operator-namespace}",

      # Checking if the bedrock operator pods are ready and running. 
      # checking status of ibm-namespace-scope-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-namespace-scope-operator ${var.operator-namespace}",

      # checking status of ibm-common-service-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-common-service-operator ${var.operator-namespace}",

      # checking status of operand-deployment-lifecycle-manager
      "${local.cpd-common-files}/pod-status-check.sh operand-deployment-lifecycle-manager ${var.operator-namespace}",

      # Create cpd-platform-operator operand request. This creates the zen operator.
      "echo '*** executing **** oc apply -f cpd-platform-operator-operandrequest.yaml'",
      "result=$(oc apply -f cpd-platform-operator-operandrequest.yaml)",
      "echo $result",

      # Create lite ibmcpd-CR: 
      "oc project ${var.cpd-namespace}",
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-platform-operator/ibmcpd-cr.yaml",
      "echo '*** executing **** oc apply -f ibmcpd-cr.yaml'",
      "result=$(oc apply -f ibmcpd-cr.yaml)",
      "echo $result",

      # check if the zen operator pod is up and running.
      "${local.cpd-common-files}/pod-status-check.sh ibm-zen-operator ${var.operator-namespace}",
      "${local.cpd-common-files}/pod-status-check.sh ibm-cert-manager-operator ${var.operator-namespace}",

      # Waiting and checking till the cert manager pods are ready in the openshift-marketplace namespace 
      "${local.cpd-common-files}/pod-status-check.sh cert-manager-cainjector ${var.operator-namespace}",
      # "oc patch certmanagers default -n ibm-common-services -p '{\"spec\":{\"certManagerCAInjector\":{\"resources\":{\"limits\":{\"cpu\":\"100\"}}}}}' --type=merge",
      # "sleep 1m",
      "${local.cpd-common-files}/pod-status-check.sh cert-manager-cainjector ${var.operator-namespace}",
      "${local.cpd-common-files}/pod-status-check.sh cert-manager-controller ${var.operator-namespace}",
      "${local.cpd-common-files}/pod-status-check.sh cert-manager-webhook ${var.operator-namespace}",

      # check the lite cr status
      "${local.cpd-common-files}/check-cr-status.sh ibmcpd ibmcpd-cr ${var.cpd-namespace} controlPlaneStatus",

      # Create the db2u catalogsource
      "result=$(oc apply -f db2u-catalog-source.yaml)",
      "echo $result",

      # ## Patch required for DMC to install redis related 
      # "oc patch namespacescope common-service --type='json' -p='[{\"op\":\"replace\", \"path\": \"/spec/csvInjector/enable\", \"value\":true}]' -n ${var.operator-namespace}",

    ]
  }
  depends_on = [
    null_resource.openshift_post_install,
    null_resource.install_portworx,
    null_resource.setup_sc_with_pwx_encryption,
    null_resource.setup_sc_without_pwx_encryption,
    null_resource.install_ocs,
    null_resource.install_nfs_client,
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
  ]
}
resource "null_resource" "install-wsl" {
  count = var.wsl == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-wsl-files",

      ## Copy the required yaml files for wsl setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-wsl-files",
      "cat > wsl-cr.yaml <<EOL\n${local.wsl-cr-file}\nEOL",
      "cat > wsl-sub.yaml <<EOL\n${data.template_file.wslsubfile.rendered}\nEOL",

      # Install WSL operator by creating the WSL subscription 
      "echo '*** executing **** oc apply -f wsl-sub.yaml'",
      "result=$(oc apply -f wsl-sub.yaml)",
      "echo $result",

      # Checking if the wsl operator pods are ready and running. 
      # checking status of ibm-cpd-ws-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-ws-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create wsl CR: 
      "cd ${local.cpd-installer-home}/ibm-cpd-wsl-files",
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-wsl-files/wsl-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-wsl-files/wsl-cr.yaml",
      "echo '*** executing **** oc apply -f wsl-cr.yaml'",
      "result=$(oc apply -f wsl-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "${local.cpd-common-files}/check-cr-status.sh ws ws-cr ${var.cpd-namespace} wsStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
  ]
}

resource "null_resource" "install-wml" {
  count = var.wml == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-wml-files",

      ## Copy the required yaml files for wml setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-wml-files",
      "cat > wml-cr.yaml <<EOL\n${local.wml-cr-file}\nEOL",
      "cat > wml-sub.yaml <<EOL\n${data.template_file.wmlsubfile.rendered}\nEOL",

      # Install WML operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f wml-sub.yaml'",
      "result=$(oc apply -f wml-sub.yaml)",
      "echo $result",

      # Checking if the wml operator pods are ready and running. 
      # checking status of ibm-cpd-wml-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-wml-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create wml CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-wml-files/wml-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-wml-files/wml-cr.yaml",
      "echo '*** executing **** oc apply -f wml-cr.yaml'",
      "result=$(oc apply -f wml-cr.yaml)",
      "echo $result",

      # check the WML cr status
      "${local.cpd-common-files}/check-cr-status.sh WmlBase wml-cr ${var.cpd-namespace} wmlStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
  ]
}
resource "null_resource" "install-aiopenscale" {
  count = var.aiopenscale == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-aiopenscale-files",

      ## Copy the required yaml files for aiopenscale setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-aiopenscale-files",
      "cat > openscale-cr.yaml <<EOL\n${file("../cpd4_module/openscale-cr.yaml")}\nEOL",
      "cat > wos-sub.yaml <<EOL\n${data.template_file.wossubfile.rendered}\nEOL",

      # Install SPSS operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f wos-sub.yaml'",
      "result=$(oc apply -f wos-sub.yaml)",
      "echo $result",

      # Checking if the openscale operator pods are ready and running. 
      # checking status of ibm-cpd-wos-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-wos-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create openscale CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-aiopenscale-files/openscale-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-aiopenscale-files/openscale-cr.yaml",
      "echo '*** executing **** oc apply -f openscale-cr.yaml'",
      "result=$(oc apply -f openscale-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "${local.cpd-common-files}/check-cr-status.sh WOService aiopenscale ${var.cpd-namespace} wosStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
  ]
}

resource "null_resource" "install-spss" {
  count = var.spss == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-spss-files",

      ## Copy the required yaml files for spss setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-spss-files",
      "cat > spss-cr.yaml <<EOL\n${file("../cpd4_module/spss-cr.yaml")}\nEOL",
      "cat > spss-sub.yaml <<EOL\n${data.template_file.spsssubfile.rendered}\nEOL",

      # Install SPSS operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f spss-sub.yaml'",
      "result=$(oc apply -f spss-sub.yaml)",
      "echo $result",

      # Checking if the spss operator pods are ready and running. 
      # checking status of ibm-cpd-spss-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-spss-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create spss CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-spss-files/spss-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-spss-files/spss-cr.yaml",
      "echo '*** executing **** oc apply -f spss-cr.yaml'",
      "result=$(oc apply -f spss-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "${local.cpd-common-files}/check-cr-status.sh spss spss-cr ${var.cpd-namespace} spssmodelerStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
    null_resource.install-aiopenscale,
  ]
}

resource "null_resource" "install-cde" {
  count = var.cde == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-cde-files",

      ## Copy the required yaml files for cde setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-cde-files",
      "cat > cde-cr.yaml <<EOL\n${file("../cpd4_module/cde-cr.yaml")}\nEOL",
      "cat > cde-sub.yaml <<EOL\n${data.template_file.cdesubfile.rendered}\nEOL",

      # Install cde operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f cde-sub.yaml'",
      "result=$(oc apply -f cde-sub.yaml)",
      "echo $result",

      # Checking if the cde operator pods are ready and running. 
      # checking status of ibm-cde-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cde-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create cde CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-cde-files/cde-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-cde-files/cde-cr.yaml",
      "echo '*** executing **** oc apply -f cde-cr.yaml'",
      "result=$(oc apply -f cde-cr.yaml)",
      "echo $result",

      # check the cde cr status
      "${local.cpd-common-files}/check-cr-status.sh CdeProxyService cde-cr ${var.cpd-namespace} cdeStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
  ]
}

resource "null_resource" "install-dods" {
  count = var.dods == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-dods-files",

      ## Copy the required yaml files for ccs setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-dods-files",
      "cat > dods-cr.yaml <<EOL\n${file("../cpd4_module/dods-cr.yaml")}\nEOL",
      "cat > dods-sub.yaml <<EOL\n${data.template_file.dodssubfile.rendered}\nEOL",

      # Install dods operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f dods-sub.yaml'",
      "result=$(oc apply -f dods-sub.yaml)",
      "echo $result",

      # Checking if the dods operator pods are ready and running. 
      # checking status of ibm-cpd-dods-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-dods-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create dods CR: 
      "cd ${local.cpd-installer-home}/ibm-cpd-dods-files",
      "echo '*** executing **** oc apply -f dods-cr.yaml'",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-dods-files/dods-cr.yaml",
      "result=$(oc apply -f dods-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "${local.cpd-common-files}/check-cr-status.sh DODS dods-cr ${var.cpd-namespace} dodsStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-cde,
  ]
}

resource "null_resource" "install-spark" {
  count = var.spark == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-spark-files",

      ## Copy the required yaml files for spark setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-spark-files",
      "cat > spark-cr.yaml <<EOL\n${file("../cpd4_module/spark-cr.yaml")}\nEOL",
      "cat > spark-sub.yaml <<EOL\n${data.template_file.sparksubfile.rendered}\nEOL",

      # Install spark operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f spark-sub.yaml'",
      "result=$(oc apply -f spark-sub.yaml)",
      "echo $result",

      # Checking if the spark operator pods are ready and running. 
      # checking status of ibm-cpd-ae-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-ae-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create spark CR: 
      "sed -i -e s#REPLACE_SC#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-spark-files/spark-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-spark-files/spark-cr.yaml",
      "echo '*** executing **** oc apply -f spark-cr.yaml'",
      "result=$(oc apply -f spark-cr.yaml)",
      "echo $result",

      # check the spark cr status
      "${local.cpd-common-files}/check-cr-status.sh AnalyticsEngine analyticsengine-cr ${var.cpd-namespace} analyticsengineStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-cde,
    null_resource.install-dods,
  ]
}

resource "null_resource" "install-dv" {
  count = var.dv == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-dv-files",

      ## Copy the required yaml files for dv setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-dv-files",
      "cat > dv-sub.yaml <<EOL\n${data.template_file.dvsubfile.rendered}\nEOL",

      # Install dv operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f dv-sub.yaml'",
      "result=$(oc apply -f dv-sub.yaml)",
      "echo $result",

      # Checking if the dv operator pods are ready and running. 
      # checking status of ibm-dv-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-dv-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # # Install dv Custom Resource
      "cat > dv-cr.yaml <<EOL\n${file("../cpd4_module/dv-cr.yaml")}\nEOL",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-dv-files/dv-cr.yaml",
      "echo '*** executing **** oc apply -f dv-cr.yaml'",
      "result=$(oc apply -f dv-cr.yaml)",
      "echo $result",

      # check the dv cr status
      "${local.cpd-common-files}/check-cr-status.sh dvservice dv-service ${var.cpd-namespace} reconcileStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-cde,
    null_resource.install-dods,
    null_resource.install-spark,
  ]
}

resource "null_resource" "install-bigsql" {
  count = var.bigsql == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-bigsql-files",

      ## Copy the required yaml files for bigsql setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-bigsql-files",
      "cat > bigsql-sub.yaml <<EOL\n${data.template_file.bigsqlsubfile.rendered}\nEOL",

      # Install bigsql operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f bigsql-sub.yaml'",
      "result=$(oc apply -f bigsql-sub.yaml)",
      "echo $result",

      # Checking if the bigsql operator pods are ready and running. 
      # checking status of ibm-bigsql-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-bigsql-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # # Install bigsql Custome Resource
      "cat > bigsql-cr.yaml <<EOL\n${file("../cpd4_module/bigsql-cr.yaml")}\nEOL",
      "sed -i -e s#REPLACE_STORAGE_CLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-bigsql-files/bigsql-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-bigsql-files/bigsql-cr.yaml",
      "echo '*** executing **** oc apply -f bigsql-cr.yaml'",
      "result=$(oc apply -f bigsql-cr.yaml)",
      "echo $result",

      # check the bigsql cr status
      "${local.cpd-common-files}/check-cr-status.sh BigsqlService bigsql-service-cr ${var.cpd-namespace} reconcileStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-cde,
    null_resource.install-dods,
    null_resource.install-spark,
    null_resource.install-dv,
  ]
}

resource "null_resource" "install-ca" {
  count = var.ca == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
  triggers = {
    bootnode_ip_address   = local.bootnode_ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    namespace             = var.cpd-namespace
    agent                 = false
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-ca-files",

      ## Copy the required yaml files for ca setup .. 	
      "cd ${local.cpd-installer-home}/ibm-cpd-ca-files",
      "cat > ca-cr.yaml <<EOL\n${file("../cpd4_module/ca-cr.yaml")}\nEOL",
      "cat > ca-sub.yaml <<EOL\n${data.template_file.casubfile.rendered}\nEOL",

      # Install ca operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f ca-sub.yaml'",
      "result=$(oc apply -f ca-sub.yaml)",
      "echo $result",

      # Checking if the ca operator pods are ready and running. 	
      # checking status of ca-operator	
      "${local.cpd-common-files}/pod-status-check.sh ca-operator ${var.operator-namespace}",

      # switch to zen namespace	
      "oc project ${var.cpd-namespace}",

      # Create ca CR: 	
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-ca-files/ca-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-ca-files/ca-cr.yaml",
      "echo '*** executing **** oc apply -f ca-cr.yaml'",
      "result=$(oc apply -f ca-cr.yaml)",
      "echo $result",

      # check the CCS cr status	
      "${local.cpd-common-files}/check-cr-status.sh CAService ca-cr ${var.cpd-namespace} caAddonStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-cde,
    null_resource.install-dods,
    null_resource.install-spark,
    null_resource.install-dv,
    null_resource.install-bigsql,
  ]
}

resource "null_resource" "install-db2oltp" {
  count = var.db2oltp == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-db2oltp-files",

      ## Copy the required yaml files for db2oltp setup .. 	
      "cd ${local.cpd-installer-home}/ibm-cpd-db2oltp-files",
      "cat > db2oltp-cr.yaml <<EOL\n${file("../cpd4_module/db2oltp-cr.yaml")}\nEOL",
      "cat > db2oltp-sub.yaml <<EOL\n${data.template_file.db2oltpsubfile.rendered}\nEOL",

      # Install db2oltp operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f db2oltp-sub.yaml'",
      "result=$(oc apply -f db2oltp-sub.yaml)",
      "echo $result",

      # Checking if the db2oltp operator podb2oltp are ready and running. 	
      # checking status of db2oltp-operator	
      "${local.cpd-common-files}/pod-status-check.sh ibm-db2oltp-cp4d-operator ${var.operator-namespace}",

      # switch to zen namespace	
      "oc project ${var.cpd-namespace}",

      # Create db2oltp CR: 	
      "echo '*** executing **** oc apply -f db2oltp-cr.yaml'",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-db2oltp-files/db2oltp-cr.yaml",
      "result=$(oc apply -f db2oltp-cr.yaml)",
      "echo $result",

      # check the CCS cr status	
      "${local.cpd-common-files}/check-cr-status.sh Db2oltpService db2oltp-cr ${var.cpd-namespace} db2oltpStatus",


    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-cde,
    null_resource.install-dods,
    null_resource.install-spark,
    null_resource.install-dv,
    null_resource.install-bigsql,
    null_resource.install-ca,
  ]
}

resource "null_resource" "install-db2wh" {
  count = var.db2wh == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-db2wh-files",

      ## Copy the required yaml files for db2wh setup .. 	
      "cd ${local.cpd-installer-home}/ibm-cpd-db2wh-files",
      "cat > db2wh-cr.yaml <<EOL\n${file("../cpd4_module/db2wh-cr.yaml")}\nEOL",
      "cat > db2wh-sub.yaml <<EOL\n${data.template_file.db2whsubfile.rendered}\nEOL",

      # Install db2wh operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f db2wh-sub.yaml'",
      "result=$(oc apply -f db2wh-sub.yaml)",
      "echo $result",

      # Checking if the db2wh operator podb2wh are ready and running. 	
      # checking status of db2wh-operator	
      "${local.cpd-common-files}/pod-status-check.sh ibm-db2wh-cp4d-operator ${var.operator-namespace}",

      # switch to zen namespace	
      "oc project ${var.cpd-namespace}",

      # Create db2wh CR: 	
      "echo '*** executing **** oc apply -f db2wh-cr.yaml'",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-db2wh-files/db2wh-cr.yaml",
      "result=$(oc apply -f db2wh-cr.yaml)",
      "echo $result",

      # check the CCS cr status	
      "${local.cpd-common-files}/check-cr-status.sh db2whService db2wh-cr ${var.cpd-namespace} db2whStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-cde,
    null_resource.install-dods,
    null_resource.install-spark,
    null_resource.install-dv,
    null_resource.install-bigsql,
    null_resource.install-ca,
    null_resource.install-db2oltp,
  ]
}

resource "null_resource" "install-wkc" {
  count = var.wkc == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-wkc-files",

      # Copy the required yaml files for wkc setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-wkc-files",
      "cat > wkc-cr.yaml <<EOL\n${local.wkc-cr-file}\nEOL",
      "cat > wkc-iis-scc.yaml <<EOL\n${file("../cpd4_module/wkc-iis-scc.yaml")}\nEOL",
      "cat > wkc-sub.yaml <<EOL\n${data.template_file.wkcsubfile.rendered}\nEOL",

      # Install wkc operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f wkc-sub.yaml'",
      "result=$(oc apply -f wkc-sub.yaml)",
      "echo $result",

      # Checking if the wkc operator pods are ready and running. 
      # checking status of ibm-wkc-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-wkc-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      ## IIS SCC
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-wkc-files/wkc-iis-scc.yaml",
      "echo '*** executing **** oc apply -f wkc-iis-scc.yaml'",
      "result=$(oc apply -f wkc-iis-scc.yaml)",
      "echo $result",

      # # Install wkc CR
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-wkc-files/wkc-cr.yaml",
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-wkc-files/wkc-cr.yaml",
      "echo '*** executing **** oc apply -f wkc-cr.yaml'",
      "result=$(oc apply -f wkc-cr.yaml)",
      "echo $result",

      # check the wkc cr status
      "${local.cpd-common-files}/check-cr-status.sh wkc wkc-cr ${var.cpd-namespace} wkcStatus",

      # check the wkc iis cr status
      "${local.cpd-common-files}/check-cr-status.sh iis iis-cr ${var.cpd-namespace} iisStatus",

      # check the wkc cr status
      "${local.cpd-common-files}/check-cr-status.sh ug ug-cr ${var.cpd-namespace} ugStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-cde,
    null_resource.install-dods,
    null_resource.install-spark,
    null_resource.install-dv,
    null_resource.install-bigsql,
    null_resource.install-ca,
    null_resource.install-db2oltp,
    null_resource.install-db2wh,
  ]
}

resource "null_resource" "install-ds" {
  count = var.ds == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-ds-files",

      ## Copy the required yaml files for ds setup .. 	
      "cd ${local.cpd-installer-home}/ibm-cpd-ds-files",
      "cat > ds-cr.yaml <<EOL\n${file("../cpd4_module/ds-cr.yaml")}\nEOL",
      "cat > ds-sub.yaml <<EOL\n${data.template_file.dssubfile.rendered}\nEOL",

      # Install ds operator by creating the WML subscription 
      "echo '*** executing **** oc apply -f ds-sub.yaml'",
      "result=$(oc apply -f ds-sub.yaml)",
      "echo $result",

      # Checking if the ds operator pods are ready and running. 	
      # checking status of ds-operator	
      "${local.cpd-common-files}/pod-status-check.sh datastage-operator ${var.operator-namespace}",

      # switch to zen namespace	
      "oc project ${var.cpd-namespace}",

      # Create ds CR: 	
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-ds-files/ds-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-ds-files/ds-cr.yaml",
      "echo '*** executing **** oc apply -f ds-cr.yaml'",
      "result=$(oc apply -f ds-cr.yaml)",
      "echo $result",

      # check the CCS cr status	
      "${local.cpd-common-files}/check-cr-status.sh DataStageService datastage-cr ${var.cpd-namespace} dsStatus",

    ]
  }
  depends_on = [
    null_resource.install-prereqs,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-wsl,
    null_resource.install-wml,
    null_resource.install-aiopenscale,
    null_resource.install-spss,
    null_resource.install-cde,
    null_resource.install-dods,
    null_resource.install-spark,
    null_resource.install-dv,
    null_resource.install-bigsql,
    null_resource.install-ca,
    null_resource.install-db2oltp,
    null_resource.install-db2wh,
    null_resource.install-wkc,
  ]
}