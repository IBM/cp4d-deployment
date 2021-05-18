locals {
  #General
  installerhome = "/home/${var.admin-username}/ibm"

  # Operator
  operator = "/home/${var.admin-username}/operator"

  # Override
  override-value = var.storage == "nfs" ? "\"\"" : var.storage
  #Storage Classes
  cp-storageclass      = lookup(var.cp-storageclass, var.storage)
  streams-storageclass = lookup(var.streams-storageclass, var.storage)
  bigsql-storageclass  = lookup(var.bigsql-storageclass, var.storage)

  //watson-asst-storageclass = var.storage == "portworx" ? "portworx-assistant" : "managed-premium"
  //watson-discovery-storageclass = var.storage == "portworx" ? "portworx-db-gp3" : "managed-premium"
}

resource "null_resource" "bedrock_zen_operator" {
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
      "sleep 5m",
      # Setup global_pull secret 

      "cat > setup-global-pull-secret-bedrock.sh <<EOL\n${file("../cpd4_module/setup-global-pull-secret-bedrock.sh")}\nEOL",
      "sudo chmod +x setup-global-pull-secret-bedrock.sh",
      "./setup-global-pull-secret-bedrock.sh ${var.artifactory-username} ${var.artifactory-apikey}",

      # create bedrock catalog source 

      "echo '*** executing **** oc create -f bedrock-catalog-source.yaml'",
      "result=$(oc create -f bedrock-catalog-source.yaml)",
      "echo $result",
      "sleep 1m",

      # Creating the ibm-common-services namespace: 

      "oc new-project ibm-common-services",
      "oc project ibm-common-services",

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

      # checking status of ibm-namespace-scope-operator

      "cat > pod-status-check.sh <<EOL\n${file("../cpd4_module/pod-status-check.sh")}\nEOL",
      "sudo chmod +x pod-status-check.sh",
      "./pod-status-check.sh ibm-namespace-scope-operator ibm-common-services",

      # checking status of operand-deployment-lifecycle-manager

      "./pod-status-check.sh operand-deployment-lifecycle-manager ibm-common-services",

      # checking status of ibm-common-service-operator

      "./pod-status-check.sh ibm-common-service-operator ibm-common-services",

      # Creating zen catalog source 

      "echo '*** executing **** oc create -f zen-catalog-source.yaml'",
      "result=$(oc create -f zen-catalog-source.yaml)",
      "echo $result",
      "sleep 1m",

      # (Important) Edit operand registry *** 

      "oc get operandregistry -n ibm-common-services -o yaml > operandregistry.yaml",
      "cp operandregistry.yaml operandregistry.yaml_original",
      "sed -i '/\\s\\s\\s\\s\\s\\spackageName: ibm-zen-operator/{n;n;s/.*/      sourceName: ibm-zen-operator-catalog/}' operandregistry.yaml ",
      "sed -zEi 's/    - channel: v3([^\\n]*\\n[^\\n]*name: ibm-zen-operator)/    - channel: stable-v1\\1/' operandregistry.yaml",

      "echo '*** executing **** oc create -f operandregistry.yaml'",
      "result=$(oc apply -f operandregistry.yaml)",
      "echo $result",

      # Create zen namespace

      "oc new-project zen",
      "oc project zen",

      # Create the zen operator 

      "echo '*** executing **** oc create -f zen-operandrequest.yaml'",
      "result=$(oc create -f zen-operandrequest.yaml)",
      "echo $result",
      "sleep 5m",

      # check if the zen operator pod is up and running.

      "./pod-status-check.sh ibm-zen-operator ibm-common-services",
      "./pod-status-check.sh ibm-cert-manager-operator ibm-common-services",

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
      "./check-cr-status.sh zenservice lite-cr zen zenStatus",
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