locals {
  #General
  cpd-installer-home = "/home/${var.admin-username}/cpd4.0"
  cpd-common-files   = "/home/${var.admin-username}/cpd4.0/cpd-common-files"
  cpd-repo-url       = "https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case"

  #Storage Classes
  cpd-storageclass       = lookup(var.cpd-storageclass, var.storage)
  ccs-class-or-vendor    = var.storage == "nfs" ? "Class" : "Vendor"
  ccs-storageclass-value = var.storage == "nfs" ? "nfs" : "portworx"
  storagevendor          = var.storage == "nfs" ? "\"\"" : var.storage

  ## CR Files 
  wml-cr-file     = var.storage == "nfs" ? data.template_file.wmlcrnfsfile.rendered : data.template_file.wmlcrpwxocsfile.rendered
  wsl-cr-file     = var.storage == "nfs" ? data.template_file.wslcrnfsfile.rendered : data.template_file.wslcrpwxocsfile.rendered
  wkc-cr-file     = var.storage == "nfs" ? data.template_file.wkccrnfsfile.rendered : data.template_file.wkccrpwxocsfile.rendered
  wkc-iis-cr-file = var.storage == "nfs" ? data.template_file.wkciiscrnfsfile.rendered : data.template_file.wkciiscrpwxocsfile.rendered
  wkc-ug-cr-file  = var.storage == "nfs" ? data.template_file.wkcugcrnfsfile.rendered : data.template_file.wkcugcrpwxocsfile.rendered

  # Conditions 
  ccs-condition          = (var.ca == "yes" || var.cde == "yes" || var.wsl == "yes" || var.wml == "yes" || var.wkc == "yes" || var.dv == "yes" || var.bigsql == "yes" ? "yes" : "no")
  datarefinery-condition = (var.wsl == "yes" || var.wkc == "yes" ? "yes" : "no")
  db2uoperator-condition = (var.db2wh == "yes" || var.db2oltp == "yes" || var.wkc == "yes" || var.dv == "yes" || var.bigsql == "yes" ? "yes" : "no")
  dmc-condition          = (var.dv == "yes" || var.bigsql == "yes" ? "yes" : "no")
  db2aaservice-condition = (var.wkc == "yes" || var.db2oltp == "yes" ? "yes" : "no")

  ## Build number details 

  ccs-case          = "ibm-ccs-1.0.0.tgz"
  db2uoperator-case = "ibm-db2uoperator-4.0.0-3731.2407.tgz"
  datarefinery-case = "ibm-datarefinery-1.0.0.tgz"
  dmc-case          = "ibm-dmc-4.0.0.tgz"
  db2aaservice-case = "ibm-db2aaservice-4.0.0.tgz"
  wsl-case          = "ibm-wsl-2.0.0.tgz"
  aiopenscale-case  = "ibm-watson-openscale-2.0.0.tgz"
  spss-case         = "ibm-spss-1.0.0.tgz"
  wml-case          = "ibm-wml-cpd-4.0.0.tgz"
  cde-case          = "ibm-cde-2.0.0.tgz"
  dods-case         = "ibm-dods-4.0.0.tgz"
  spark-case        = "ibm-analyticsengine-4.0.0.tgz"
  dv-case           = "ibm-dv-case-1.7.0.tgz"
  bigsql-case       = "ibm-bigsql-case-7.2.0.tgz"
  wkc-core-case     = "ibm-wkc-4.0.0.tgz"
  wkc-iis-case      = "ibm-iis-4.0.0.tgz"
  ca-case           = "ibm-cognos-analytics-prod-4.0.0.tgz"
  ds-case           = "ibm-datastage-4.0.1.tgz"
  db2oltp-case      = "ibm-db2oltp-4.0.0.tgz"
  db2wh-case        = "ibm-db2wh-4.0.0.tgz"

}

resource "null_resource" "install-cloudctl" {
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

      ## Download and install cloudctl  
      "cd ${local.cpd-common-files}",

      # Download cloudctl and aiopenscale case package. 
      "wget https://github.com/IBM/cloud-pak-cli/releases/${var.cloudctl_version}/download/cloudctl-linux-amd64.tar.gz",
      "wget https://github.com/IBM/cloud-pak-cli/releases/${var.cloudctl_version}/download/cloudctl-linux-amd64.tar.gz.sig",
      "sudo tar -xvf cloudctl-linux-amd64.tar.gz -C /usr/local/bin",
      "sudo mv /usr/local/bin/cloudctl-linux-amd64 /usr/local/bin/cloudctl",
      "cloudctl version",

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
      "./sysctl-config-db2.sh ${local.db2uoperator-condition}",
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
    null_resource.install-cloudctl,
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
      "cat > ibm-operator-sub.yaml <<EOL\n${file("../cpd4_module/ibm-operator-sub.yaml")}\nEOL",
      "cat > ibm-operator-og.yaml <<EOL\n${file("../cpd4_module/ibm-operator-og.yaml")}\nEOL",
      "cat > cpd-platform-operator-sub.yaml <<EOL\n${file("../cpd4_module/cpd-platform-operator-sub.yaml")}\nEOL",
      "cat > cpd-platform-operator-operandrequest.yaml <<EOL\n${file("../cpd4_module/cpd-platform-operator-operandrequest.yaml")}\nEOL",
      "cat > ibmcpd-cr.yaml <<EOL\n${data.template_file.ibmcpd-cr-file.rendered}\nEOL",

      # create IBM Operator catalog source 
      "echo '*** executing **** oc create -f ibm-operator-catalogsource.yaml'",
      "result=$(oc create -f ibm-operator-catalogsource.yaml)",
      "echo $result",
      "sleep 1m",

      # Waiting and checking till the opencloud operator is ready in the openshift-marketplace namespace 
      "${local.cpd-common-files}/pod-status-check.sh ibm-operator-catalog openshift-marketplace",

      # Creating the ibm-common-services namespace: 
      "oc new-project ${var.operator-namespace}",
      "oc new-project ${var.cpd-namespace}",
      "oc project ${var.operator-namespace}",

      # Create ibm-operator operator group: 
      "echo '*** executing **** oc create -f ibm-operator-og.yaml'",
      "result=$(oc create -f ibm-operator-og.yaml)",
      "echo $result",
      "sleep 1m",

      # Create ibm-operator subscription. This will deploy the bedrock and zen: 
      "echo '*** executing **** oc create -f ibm-operator-sub.yaml'",
      "result=$(oc create -f ibm-operator-sub.yaml)",
      "echo $result",
      "sleep 1m",

      #Check subcription status
      "${local.cpd-common-files}/check-subscription-status.sh ibm-common-service-operator ${var.operator-namespace} state",

      # Checking if the bedrock operator pods are ready and running. 
      # checking status of ibm-namespace-scope-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-namespace-scope-operator ${var.operator-namespace}",

      # checking status of operand-deployment-lifecycle-manager
      "${local.cpd-common-files}/pod-status-check.sh operand-deployment-lifecycle-manager ${var.operator-namespace}",

      # checking status of ibm-common-service-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-common-service-operator ${var.operator-namespace}",

      # Create cpd-platform-operator subscription. This will deploy the bedrock and zen: 
      "echo '*** executing **** oc create -f cpd-platform-operator-sub.yaml'",
      "result=$(oc create -f cpd-platform-operator-sub.yaml)",
      "echo $result",
      "sleep 1m",

      # Waiting and checking till the cpd-platform-operator-manager pod is up in ibm-common-services namespace.  
      "${local.cpd-common-files}/pod-status-check.sh cpd-platform-operator-manager ${var.operator-namespace}",
      "sleep 1m",

      # Create cpd-platform-operator operand request. This creates the zen operator.
      "echo '*** executing **** oc create -f cpd-platform-operator-operandrequest.yaml'",
      "result=$(oc create -f cpd-platform-operator-operandrequest.yaml)",
      "echo $result",
      "sleep 1m",

      # Create lite ibmcpd-CR: 
      "oc project ${var.cpd-namespace}",
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-platform-operator/ibmcpd-cr.yaml",
      "echo '*** executing **** oc create -f ibmcpd-cr.yaml'",
      "result=$(oc create -f ibmcpd-cr.yaml)",
      "echo $result",

      # check if the zen operator pod is up and running.
      "${local.cpd-common-files}/pod-status-check.sh ibm-zen-operator ${var.operator-namespace}",
      "${local.cpd-common-files}/pod-status-check.sh ibm-cert-manager-operator ${var.operator-namespace}",

      # Waiting and checking till the cert manager pods are ready in the openshift-marketplace namespace 
      "${local.cpd-common-files}/pod-status-check.sh cert-manager-cainjector ${var.operator-namespace}",
      "sleep 5m",
      "oc patch certmanagers default -n ibm-common-services -p '{\"spec\":{\"certManagerCAInjector\":{\"resources\":{\"limits\":{\"cpu\":\"100\"}}}}}' --type=merge",
      "sleep 1m",
      "${local.cpd-common-files}/pod-status-check.sh cert-manager-cainjector ${var.operator-namespace}",
      "${local.cpd-common-files}/pod-status-check.sh cert-manager-controller ${var.operator-namespace}",
      "${local.cpd-common-files}/pod-status-check.sh cert-manager-webhook ${var.operator-namespace}",

      # check the lite cr status
      "${local.cpd-common-files}/check-cr-status.sh ibmcpd ibmcpd-cr ${var.cpd-namespace} controlPlaneStatus",

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
    null_resource.cpd-setup-pull-secret,
  ]
}

### Installing CCS service. 
resource "null_resource" "install-ccs" {
  count = local.ccs-condition == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-ccs-files",

      ## Copy the required yaml files for ccs setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-ccs-files",
      "cat > ccs-cr.yaml <<EOL\n${file("../cpd4_module/ccs-cr.yaml")}\nEOL",

      ## Download the case package for CCS
      "wget ${local.cpd-repo-url}/${local.ccs-case}",

      # Install ccs operator using CLI (OLM)
      "cat > install-ccs-operator.sh <<EOL\n${file("../cpd4_module/install-ccs-operator.sh")}\nEOL",
      "sudo chmod +x install-ccs-operator.sh",
      "./install-ccs-operator.sh ${local.ccs-case} ${var.operator-namespace}",

      # Checking if the ccs operator pods are ready and running. 
      # checking status of ibm-cpd-ccs-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-ccs-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create CCS CR: 
      "sed -i -e s#CLASS_OR_VENDOR#${local.ccs-class-or-vendor}#g ${local.cpd-installer-home}/ibm-cpd-ccs-files/ccs-cr.yaml",
      "sed -i -e s#REPLACE_STORAGECLASS#${local.ccs-storageclass-value}#g ${local.cpd-installer-home}/ibm-cpd-ccs-files/ccs-cr.yaml",
      "echo '*** executing **** oc create -f ccs-cr.yaml'",
      "result=$(oc create -f ccs-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "${local.cpd-common-files}/check-cr-status.sh ccs ccs-cr ${var.cpd-namespace} ccsStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
  ]
}

### Installing Db2uOperator service. 
resource "null_resource" "install-db2uoperator" {
  count = local.db2uoperator-condition == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-db2uoperator-files",

      ## Copy the required yaml files for db2uoperator setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-db2uoperator-files",

      # Case package. 
      ## Db2u Operator 
      "wget ${local.cpd-repo-url}/${local.db2uoperator-case}",

      # # Install db2u operator using CLI (OLM)
      "cat > install-db2u-operator.sh <<EOL\n${file("../cpd4_module/install-db2u-operator.sh")}\nEOL",
      "sudo chmod +x install-db2u-operator.sh",
      "./install-db2u-operator.sh ${local.db2uoperator-case} ${var.operator-namespace}",

      # Checking if the DB2U operator pods are ready and running. 
      # checking status of db2u-operator
      "${local.cpd-common-files}/pod-status-check.sh db2u-operator ${var.operator-namespace}",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
  ]
}

### Installing Datarefinery service. 
resource "null_resource" "install-data-refinery" {
  count = local.datarefinery-condition == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-data-refinery-files",

      ## Copy the required yaml files for data-refinery setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-data-refinery-files",
      "cat > data-refinery-cr.yaml <<EOL\n${file("../cpd4_module/data-refinery-cr.yaml")}\nEOL",

      ## Download the case package for data-refinery
      "wget ${local.cpd-repo-url}/${local.datarefinery-case}",

      # Install data-refinery operator using CLI (OLM)
      "cat > install-data-refinery-operator.sh <<EOL\n${file("../cpd4_module/install-data-refinery-operator.sh")}\nEOL",
      "sudo chmod +x install-data-refinery-operator.sh",
      "./install-data-refinery-operator.sh ${local.datarefinery-case} ${var.operator-namespace}",

      # Checking if the data-refinery operator pods are ready and running. 
      # checking status of ibm-cpd-datarefinery-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-datarefinery-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create data-refinery CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-data-refinery-files/data-refinery-cr.yaml",
      "echo '*** executing **** oc create -f data-refinery-cr.yaml'",
      "result=$(oc create -f data-refinery-cr.yaml)",
      "echo $result",

      # check the data-refinery cr status
      "${local.cpd-common-files}/check-cr-status.sh Datarefinery datarefinery-cr ${var.cpd-namespace} datarefineryStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
  ]
}

### Installing db2aaservice service. 
resource "null_resource" "install-db2aaservice" {
  count = local.db2aaservice-condition == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-db2aaservice-files",

      ## Copy the required yaml files for db2aaservice setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-db2aaservice-files",
      "cat > db2aaservice-cr.yaml <<EOL\n${file("../cpd4_module/db2aaservice-cr.yaml")}\nEOL",

      ## Db2asaservice 
      "wget ${local.cpd-repo-url}/${local.db2aaservice-case}",

      # # Install db2aaservice operator using CLI (OLM)
      "cat > install-db2aaservice-operator.sh <<EOL\n${file("../cpd4_module/install-db2aaservice-operator.sh")}\nEOL",
      "sudo chmod +x install-db2aaservice-operator.sh",
      "./install-db2aaservice-operator.sh ${local.db2aaservice-case} ${var.operator-namespace}",

      # Checking if the db2aaservice operator pods are ready and running. 
      # checking status of db2aaservice-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-db2aaservice-cp4d-operator-controller-manager ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Install db2aaservice Customer Resource
      "echo '*** executing **** oc create -f db2aaservice-cr.yaml'",
      "result=$(oc create -f db2aaservice-cr.yaml)",
      "echo $result",

      # check the db2aaservice cr status
      "${local.cpd-common-files}/check-cr-status.sh Db2aaserviceService db2aaservice-cr ${var.cpd-namespace} db2aaserviceStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
  ]
}

### Installing dmc service. 
resource "null_resource" "install-dmc" {
  count = local.dmc-condition == "yes" && var.accept-cpd-license == "accept" ? 1 : 0
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
      "mkdir -p ${local.cpd-installer-home}/ibm-cpd-dmc-files",

      ## Copy the required yaml files for dmc setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-dmc-files",

      # Case package.

      ## DMC Operator 
      "wget ${local.cpd-repo-url}/${local.dmc-case}",

      # # Install dmc operator using CLI (OLM)
      "cat > install-dmc-operator.sh <<EOL\n${file("../cpd4_module/install-dmc-operator.sh")}\nEOL",
      "sudo chmod +x install-dmc-operator.sh",
      "./install-dmc-operator.sh ${local.dmc-case} ${var.operator-namespace} ${local.cpd-storageclass} ${var.cpd-namespace}",

      # Checking if the dmc operator pods are ready and running. 
      # checking status of dmc-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-dmc-controller ${var.operator-namespace}",

      # check the mc cr status
      "${local.cpd-common-files}/check-cr-status.sh dmcaddon dmcaddon-cr ${var.cpd-namespace} dmcAddonStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
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
      # "mkdir -p ${local.cpd-installer-home}/ibm-cpd-wsl-files/offline",

      ## Copy the required yaml files for wsl setup .. 
      "cd ${local.cpd-installer-home}/ibm-cpd-wsl-files",
      "cat > wsl-cr.yaml <<EOL\n${local.wsl-cr-file}\nEOL",

      # ## Download the case package for wsl
      "wget ${local.cpd-repo-url}/${local.wsl-case}",

      # Install wsl operator using CLI (OLM)
      # "cd ${local.cpd-installer-home}/ibm-cpd-wsl-files/offline",
      "cat > install-wsl-operator.sh <<EOL\n${file("../cpd4_module/install-wsl-operator.sh")}\nEOL",
      "sudo chmod +x install-wsl-operator.sh",
      "./install-wsl-operator.sh ${local.wsl-case} ${var.operator-namespace}",

      # Checking if the wsl operator pods are ready and running. 
      # checking status of ibm-cpd-ws-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-ws-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create wsl CR: 
      "cd ${local.cpd-installer-home}/ibm-cpd-wsl-files",
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-wsl-files/wsl-cr.yaml",
      "echo '*** executing **** oc create -f wsl-cr.yaml'",
      "result=$(oc create -f wsl-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "${local.cpd-common-files}/check-cr-status.sh ws ws-cr ${var.cpd-namespace} wsStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,

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

      # Case package. 
      "wget ${local.cpd-repo-url}/${local.wml-case}",

      # # Install wml operator using CLI (OLM)
      "cat > install-wml-operator.sh <<EOL\n${file("../cpd4_module/install-wml-operator.sh")}\nEOL",
      "sudo chmod +x install-wml-operator.sh",
      "./install-wml-operator.sh ${local.wml-case} ${var.operator-namespace}",

      # Checking if the wml operator pods are ready and running. 
      # checking status of ibm-cpd-wml-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-wml-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create wml CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-wml-files/wml-cr.yaml",
      "echo '*** executing **** oc create -f wml-cr.yaml'",
      "result=$(oc create -f wml-cr.yaml)",
      "echo $result",

      # check the WML cr status
      "${local.cpd-common-files}/check-cr-status.sh WmlBase wml-cr ${var.cpd-namespace} wmlStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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

      # Case package. 
      "wget ${local.cpd-repo-url}/${local.aiopenscale-case}",

      # Install OpenScale operator using CLI (OLM)
      "cat > install-openscale-operator.sh <<EOL\n${file("../cpd4_module/install-openscale-operator.sh")}\nEOL",
      "sudo chmod +x install-openscale-operator.sh",
      "./install-openscale-operator.sh ${local.aiopenscale-case} ${var.operator-namespace}",

      # Checking if the openscale operator pods are ready and running. 
      # checking status of ibm-cpd-wos-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-wos-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create openscale CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-aiopenscale-files/openscale-cr.yaml",
      "echo '*** executing **** oc create -f openscale-cr.yaml'",
      "result=$(oc create -f openscale-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "${local.cpd-common-files}/check-cr-status.sh WOService aiopenscale ${var.cpd-namespace} wosStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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

      # Case package. 
      "wget ${local.cpd-repo-url}/${local.spss-case}",

      # # Install spss operator using CLI (OLM)
      "cat > install-spss-operator.sh <<EOL\n${file("../cpd4_module/install-spss-operator.sh")}\nEOL",
      "sudo chmod +x install-spss-operator.sh",
      "./install-spss-operator.sh ${local.spss-case} ${var.operator-namespace}",

      # Checking if the spss operator pods are ready and running. 
      # checking status of ibm-cpd-spss-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-spss-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create spss CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-spss-files/spss-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-spss-files/spss-cr.yaml",
      "echo '*** executing **** oc create -f spss-cr.yaml'",
      "result=$(oc create -f spss-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "${local.cpd-common-files}/check-cr-status.sh spss spss-cr ${var.cpd-namespace} spssmodelerStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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

      # Case package.
      "wget ${local.cpd-repo-url}/${local.cde-case}",

      # # Install cde operator using CLI (OLM)
      "cat > install-cde-operator.sh <<EOL\n${file("../cpd4_module/install-cde-operator.sh")}\nEOL",
      "sudo chmod +x install-cde-operator.sh",
      "./install-cde-operator.sh ${local.cde-case} ${var.operator-namespace}",

      # Checking if the cde operator pods are ready and running. 
      # checking status of ibm-cde-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cde-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create cde CR: 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-cde-files/cde-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-cde-files/cde-cr.yaml",
      "echo '*** executing **** oc create -f cde-cr.yaml'",
      "result=$(oc create -f cde-cr.yaml)",
      "echo $result",

      # check the cde cr status
      "${local.cpd-common-files}/check-cr-status.sh CdeProxyService cde-cr ${var.cpd-namespace} cdeStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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

      # Download the case package for dods
      "wget ${local.cpd-repo-url}/${local.dods-case}",

      # Install dods operator using CLI (OLM)
      "cat > install-dods-operator.sh <<EOL\n${file("../cpd4_module/install-dods-operator.sh")}\nEOL",
      "sudo chmod +x install-dods-operator.sh",
      "./install-dods-operator.sh ${local.dods-case} ${var.operator-namespace}",

      # Checking if the dods operator pods are ready and running. 
      # checking status of ibm-cpd-dods-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-dods-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create dods CR: 
      "cd ${local.cpd-installer-home}/ibm-cpd-dods-files",
      "echo '*** executing **** oc create -f dods-cr.yaml'",
      "result=$(oc create -f dods-cr.yaml)",
      "echo $result",

      # check the CCS cr status
      "${local.cpd-common-files}/check-cr-status.sh DODS dods-cr ${var.cpd-namespace} dodsStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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

      # Case package. 

      "wget ${local.cpd-repo-url}/${local.spark-case}",

      # # Install spark operator using CLI (OLM)
      "cat > install-spark-operator.sh <<EOL\n${file("../cpd4_module/install-spark-operator.sh")}\nEOL",
      "sudo chmod +x install-spark-operator.sh",
      "./install-spark-operator.sh ${local.spark-case} ${var.operator-namespace}",

      # Checking if the spark operator pods are ready and running. 
      # checking status of ibm-cpd-ae-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-ae-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # Create spark CR: 
      "sed -i -e s#REPLACE_SC#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-spark-files/spark-cr.yaml",
      "sed -i -e s#BUILD_NUMBER#4.0.0#g ${local.cpd-installer-home}/ibm-cpd-spark-files/spark-cr.yaml",
      "echo '*** executing **** oc create -f spark-cr.yaml'",
      "result=$(oc create -f spark-cr.yaml)",
      "echo $result",

      # check the spark cr status
      "${local.cpd-common-files}/check-cr-status.sh AnalyticsEngine analyticsengine-cr ${var.cpd-namespace} analyticsengineStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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

      # Case package. 
      ## DV case 
      "wget ${local.cpd-repo-url}/${local.dv-case}",

      # # Install dv operator using CLI (OLM)
      "cat > install-dv-operator.sh <<EOL\n${file("../cpd4_module/install-dv-operator.sh")}\nEOL",
      "sudo chmod +x install-dv-operator.sh",
      "./install-dv-operator.sh ${local.dv-case} ${var.operator-namespace}",

      # Checking if the dv operator pods are ready and running. 
      # checking status of ibm-dv-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-dv-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # # Install dv Customer Resource
      "cat > install-dv-cr.sh <<EOL\n${file("../cpd4_module/install-dv-cr.sh")}\nEOL",
      "sudo chmod +x install-dv-cr.sh",
      "./install-dv-cr.sh ${local.dv-case} ${var.cpd-namespace}",

      # check the dv cr status
      "${local.cpd-common-files}/check-cr-status.sh dvservice dv-service ${var.cpd-namespace} reconcileStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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

      # Case package. 
      ## bigsql case package 
      "wget ${local.cpd-repo-url}/${local.bigsql-case}",

      # # Install bigsql operator using CLI (OLM)
      "cat > install-bigsql-operator.sh <<EOL\n${file("../cpd4_module/install-bigsql-operator.sh")}\nEOL",
      "sudo chmod +x install-bigsql-operator.sh",
      "./install-bigsql-operator.sh ${local.bigsql-case} ${var.operator-namespace}",

      # Checking if the bigsql operator pods are ready and running. 
      # checking status of ibm-bigsql-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-bigsql-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # # Install bigsql Custome Resource
      "cat > install-bigsql-cr.sh <<EOL\n${file("../cpd4_module/install-bigsql-cr.sh")}\nEOL",
      "sudo chmod +x install-bigsql-cr.sh",
      "./install-bigsql-cr.sh ${local.bigsql-case} ${var.cpd-namespace}",

      # check the bigsql cr status
      "${local.cpd-common-files}/check-cr-status.sh bigsqlservice bigsql-service ${var.cpd-namespace} reconcileStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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

      # Case package. 	
      "wget ${local.cpd-repo-url}/${local.ca-case}",

      # Install ca operator using CLI (OLM)	
      "cat > install-ca-operator.sh <<EOL\n${file("../cpd4_module/install-ca-operator.sh")}\nEOL",
      "sudo chmod +x install-ca-operator.sh",
      "./install-ca-operator.sh ${local.ca-case} ${var.operator-namespace}",

      # Checking if the ca operator pods are ready and running. 	
      # checking status of ca-operator	
      "${local.cpd-common-files}/pod-status-check.sh ca-operator ${var.operator-namespace}",

      # switch to zen namespace	
      "oc project ${var.cpd-namespace}",

      # Create ca CR: 	
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-ca-files/ca-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-ca-files/ca-cr.yaml",
      "echo '*** executing **** oc create -f ca-cr.yaml'",
      "result=$(oc create -f ca-cr.yaml)",
      "echo $result",

      # check the CCS cr status	
      "${local.cpd-common-files}/check-cr-status.sh CAService ca-cr ${var.cpd-namespace} caAddonStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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

      # Case package. 	
      "wget ${local.cpd-repo-url}/${local.db2oltp-case}",

      # Install db2oltp operator using CLI (OLM)	
      "cat > install-db2oltp-operator.sh <<EOL\n${file("../cpd4_module/install-db2oltp-operator.sh")}\nEOL",
      "sudo chmod +x install-db2oltp-operator.sh",
      "./install-db2oltp-operator.sh ${local.db2oltp-case} ${var.operator-namespace}",

      # Checking if the db2oltp operator podb2oltp are ready and running. 	
      # checking status of db2oltp-operator	
      "${local.cpd-common-files}/pod-status-check.sh ibm-db2oltp-cp4d-operator ${var.operator-namespace}",

      # switch to zen namespace	
      "oc project ${var.cpd-namespace}",

      # Create db2oltp CR: 	
      "echo '*** executing **** oc create -f db2oltp-cr.yaml'",
      "result=$(oc create -f db2oltp-cr.yaml)",
      "echo $result",

      # check the CCS cr status	
      "${local.cpd-common-files}/check-cr-status.sh Db2oltpService db2oltp-cr ${var.cpd-namespace} db2oltpStatus",


    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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

      # Case package. 	
      "wget ${local.cpd-repo-url}/${local.db2wh-case}",

      # Install db2wh operator using CLI (OLM)	
      "cat > install-db2wh-operator.sh <<EOL\n${file("../cpd4_module/install-db2wh-operator.sh")}\nEOL",
      "sudo chmod +x install-db2wh-operator.sh",
      "./install-db2wh-operator.sh ${local.db2wh-case} ${var.operator-namespace}",

      # Checking if the db2wh operator podb2wh are ready and running. 	
      # checking status of db2wh-operator	
      "${local.cpd-common-files}/pod-status-check.sh ibm-db2wh-cp4d-operator ${var.operator-namespace}",

      # switch to zen namespace	
      "oc project ${var.cpd-namespace}",

      # Create db2wh CR: 	
      "echo '*** executing **** oc create -f db2wh-cr.yaml'",
      "result=$(oc create -f db2wh-cr.yaml)",
      "echo $result",

      # check the CCS cr status	
      "${local.cpd-common-files}/check-cr-status.sh db2whService db2wh-cr ${var.cpd-namespace} db2whStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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
      "cat > wkc-iis-cr.yaml <<EOL\n${local.wkc-iis-cr-file}\nEOL",
      "cat > wkc-ug-cr.yaml <<EOL\n${local.wkc-ug-cr-file}\nEOL",

      # Case package. 
      # ## wkc case package 
      "wget ${local.cpd-repo-url}/${local.wkc-core-case}",

      # ## IIS case package 
      "wget ${local.cpd-repo-url}/${local.wkc-iis-case}",

      # # Install wkc operator using CLI (OLM)
      "cat > install-wkc-operator.sh <<EOL\n${file("../cpd4_module/install-wkc-operator.sh")}\nEOL",
      "sudo chmod +x install-wkc-operator.sh",
      "./install-wkc-operator.sh ${local.wkc-core-case} ${var.operator-namespace}",

      # Checking if the wkc operator pods are ready and running. 
      # checking status of ibm-wkc-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-wkc-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # # Install wkc Customer Resource
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-wkc-files/wkc-cr.yaml",
      "echo '*** executing **** oc create -f wkc-cr.yaml'",
      "result=$(oc create -f wkc-cr.yaml)",
      "echo $result",

      # check the wkc cr status
      "${local.cpd-common-files}/check-cr-status.sh wkc wkc-cr ${var.cpd-namespace} wkcStatus",

      ## IIS cr installation 
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-wkc-files/wkc-iis-scc.yaml",
      "echo '*** executing **** oc create -f wkc-iis-scc.yaml'",
      "result=$(oc create -f wkc-iis-scc.yaml)",
      "echo $result",

      # Install IIS operator using CLI (OLM)
      "cat > install-wkc-iis-operator.sh <<EOL\n${file("../cpd4_module/install-wkc-iis-operator.sh")}\nEOL",
      "sudo chmod +x install-wkc-iis-operator.sh",
      "./install-wkc-iis-operator.sh ${local.wkc-iis-case} ${var.operator-namespace}",

      # Checking if the wkc iis operator pods are ready and running. 
      # checking status of ibm-cpd-iis-operator
      "${local.cpd-common-files}/pod-status-check.sh ibm-cpd-iis-operator ${var.operator-namespace}",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # # Install wkc Customer Resource
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-wkc-files/wkc-iis-cr.yaml",
      "sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g ${local.cpd-installer-home}/ibm-cpd-wkc-files/wkc-iis-cr.yaml",
      "echo '*** executing **** oc create -f wkc-iis-cr.yaml'",
      "result=$(oc create -f wkc-iis-cr.yaml)",
      "echo $result",

      # check the wkc iis cr status
      "${local.cpd-common-files}/check-cr-status.sh iis iis-cr ${var.cpd-namespace} iisStatus",

      # switch to zen namespace
      "oc project ${var.cpd-namespace}",

      # # Install wkc ug cr 
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-wkc-files/wkc-ug-cr.yaml",
      "echo '*** executing **** oc create -f wkc-ug-cr.yaml'",
      "result=$(oc create -f wkc-ug-cr.yaml)",
      "echo $result",

      # check the wkc cr status
      "${local.cpd-common-files}/check-cr-status.sh ug ug-cr ${var.cpd-namespace} ugStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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

      # Case package. 	
      "wget ${local.cpd-repo-url}/${local.ds-case}",

      # Install ds operator using CLI (OLM)	
      "cat > install-ds-operator.sh <<EOL\n${file("../cpd4_module/install-ds-operator.sh")}\nEOL",
      "sudo chmod +x install-ds-operator.sh",
      "./install-ds-operator.sh ${local.ds-case} ${var.operator-namespace}",

      # Checking if the ds operator pods are ready and running. 	
      # checking status of ds-operator	
      "${local.cpd-common-files}/pod-status-check.sh datastage-operator ${var.operator-namespace}",

      # switch to zen namespace	
      "oc project ${var.cpd-namespace}",

      # Create ds CR: 	
      "sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g ${local.cpd-installer-home}/ibm-cpd-ds-files/ds-cr.yaml",
      "echo '*** executing **** oc create -f ds-cr.yaml'",
      "result=$(oc create -f ds-cr.yaml)",
      "echo $result",

      # check the CCS cr status	
      "${local.cpd-common-files}/check-cr-status.sh DataStageService datastage-cr ${var.cpd-namespace} dsStatus",

    ]
  }
  depends_on = [
    null_resource.install-cloudctl,
    null_resource.cpd-setup-pull-secret,
    null_resource.install-cpd-platform-operator,
    null_resource.install-ccs,
    null_resource.install-db2uoperator,
    null_resource.install-data-refinery,
    null_resource.install-db2aaservice,
    null_resource.install-dmc,
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