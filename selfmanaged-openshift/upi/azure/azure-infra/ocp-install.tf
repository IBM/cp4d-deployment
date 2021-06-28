
locals {
  ocpdir                       = "ocpfourx"
  ocptemplates                 = "ocpfourxtemplates"
  install-config-file          = "install-config.tpl.yaml"
  subscription_id              = var.azure-subscription-id
  client_secret                = var.azure-client-secret
  tenant_id                    = var.azure-tenant-id
  app_url                      = "http://${var.azure-sp-name}"
  public_ip_query              = "[?name=='$INFRA_ID-master-pip'] | [0].ipAddress"
  ssh_key                      = var.ssh-public-key
  schema                       = "\\$schema"
  str                          = "\\\"\\\""
  bootnode_vnet_id             = azurerm_virtual_network.cpdvirtualnetwork.id
  bootnode_resource_group_name = azurerm_resource_group.cpdrg.name
  bootnode_vnet_name           = azurerm_virtual_network.cpdvirtualnetwork.name
  install-config               = var.disconnected-cluster == "yes" ? data.template_file.installconfig-disconnected[0].rendered : data.template_file.installconfig[0].rendered
  machine-health-check-file    = "machine-health-check-${var.single-or-multi-zone}.tpl.yaml"

}

resource "null_resource" "install_openshift_disconnected_pre_req" {
  count = var.disconnected-cluster == "yes" ? 1 : 0
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    directory             = local.ocpdir
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "file" {
    source      = var.certificate-file-path
    destination = "/home/${var.admin-username}/domain.crt"
  }
  provisioner "file" {
    source      = var.pull-secret-json-path
    destination = "/home/${var.admin-username}/pull-secret.json"
  }

  provisioner "remote-exec" {
    inline = [

      ###########################################
      ### Downloading installables ####
      ###########################################
      "wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.ocp-version}/openshift-client-linux.tar.gz",
      "sudo tar -xvf openshift-client-linux.tar.gz -C /usr/bin",
      "sudo chmod +x /usr/bin/oc",
      "sudo chmod +x /usr/bin/kubectl",
      "export GODEBUG=x509ignoreCN=0",
      "sudo cp domain.crt /etc/pki/ca-trust/source/anchors/",
      "sudo update-ca-trust",
      "oc adm -a ./pull-secret.json release extract --command=openshift-install ${var.local-registry-repository}/${var.local-repository}:${var.ocp-version}-${var.architecture} --insecure",
      "sudo chmod u+x /home/${var.admin-username}/openshift-install",
      "./openshift-install version"

    ]
  }
  depends_on = [
    azurerm_virtual_machine.bootnode,
  ]

}

resource "null_resource" "install_openshift_connected_pre_req" {
  count = var.disconnected-cluster == "no" ? 1 : 0
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    directory             = local.ocpdir
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [

      ###########################################
      ### Downloading installables ####
      ###########################################
      "wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.ocp-version}/openshift-install-linux.tar.gz",
      "wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.ocp-version}/openshift-client-linux.tar.gz",
      "tar -xvf openshift-install-linux.tar.gz",
      "sudo tar -xvf openshift-client-linux.tar.gz -C /usr/bin",
      "sudo chmod +x /usr/bin/oc",
      "sudo chmod +x /usr/bin/kubectl",
      "sudo chmod u+x /home/${var.admin-username}/openshift-install",
      "./openshift-install version"

    ]
  }
  depends_on = [
    azurerm_virtual_machine.bootnode,
  ]

}

resource "null_resource" "vnet_creation" {
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    directory             = local.ocpdir
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "file" {
    source      = "../scripts/storage_blob_copy_status.sh"
    destination = "/home/${var.admin-username}/storage_blob_copy_status.sh"
  }
  provisioner "remote-exec" {
    inline = [

      ###############################################
      ### Creating Directories and installing cli ####
      ###############################################
      "mkdir -p ${local.ocpdir}",
      "mkdir -p ${local.ocptemplates}",
      "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc",
      "cat > ${local.ocptemplates}/azure-cli.repo <<EOL\n${file("../openshift_module/azure-cli.repo")}\nEOL",
      "sudo mv ${local.ocptemplates}/azure-cli.repo /etc/yum.repos.d/azure-cli.repo",
      "sudo yum update -y --disablerepo=* --enablerepo=\"*microsoft*\"",
      "sudo yum install azure-cli -y",

      ###################################################
      #### az login with service principal ####
      ###################################################
      "az login --service-principal -u ${local.app_url} -p ${local.client_secret} --tenant ${local.tenant_id}",
      "az account set -s ${local.subscription_id}",

      ####################################################################
      ## Installing required libraries and copying the templates ##
      ####################################################################
      "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O jq",
      "sudo mv jq /usr/local/bin",
      "sudo chmod +x /usr/local/bin/jq",
      "sudo pip3 install yq",
      "cat > ${local.ocpdir}/install-config.yaml <<EOL\n${local.install-config}\nEOL",
      "cp ${local.ocpdir}/install-config.yaml ${local.ocpdir}/install-config-backup.yaml",
      "mkdir -p /home/${var.admin-username}/.azure",
      "cat > /home/${var.admin-username}/.azure/osServicePrincipal.json <<EOL\n${data.template_file.azurecreds.rendered}\nEOL",
      "cat > ${local.ocpdir}/01_vnet.json <<EOL\n${data.template_file.vnet.rendered}\nEOL",
      "cat > ${local.ocpdir}/02_storage.json <<EOL\n${data.template_file.storage.rendered}\nEOL",
      "cat > ${local.ocpdir}/03_infra.json <<EOL\n${data.template_file.infra.rendered}\nEOL",
      "cat > ${local.ocpdir}/04_bootstrap.json <<EOL\n${data.template_file.bootstrap.rendered}\nEOL",
      "cat > ${local.ocpdir}/05_masters.json <<EOL\n${data.template_file.masters.rendered}\nEOL",
      "cat > ${local.ocpdir}/06_workers.json <<EOL\n${data.template_file.workers.rendered}\nEOL",
      "schema=\\\"${local.schema}\\\"",
      "echo 'printing vars'",
      "echo $schema",
      "echo ${local.str}",
      "sed -i s/${local.str}/$schema/g ${local.ocpdir}/01_vnet.json",
      "sed -i s/${local.str}/$schema/g ${local.ocpdir}/02_storage.json",
      "sed -i s/${local.str}/$schema/g ${local.ocpdir}/03_infra.json",
      "sed -i s/${local.str}/$schema/g ${local.ocpdir}/04_bootstrap.json",
      "sed -i s/${local.str}/$schema/g ${local.ocpdir}/05_masters.json",
      "sed -i s/${local.str}/$schema/g ${local.ocpdir}/06_workers.json",
      "SSH_KEY=`yq -r .sshKey ${local.ocpdir}/install-config.yaml | xargs`",

      ###########################
      ### Creating manifests ###
      ###########################
      "./openshift-install create manifests --dir=${local.ocpdir}",
      "rm -f ${local.ocpdir}/manifests/cluster-dns-02-config.yml",
      "cat > ${local.ocpdir}/manifests/cluster-dns-02-config.yml <<EOL\n${data.template_file.dnsconfig.rendered}\nEOL",
      "INFRA_ID=`yq -r .status.infrastructureName ${local.ocpdir}/manifests/cluster-infrastructure-02-config.yml | xargs`",
      "rm -f ${local.ocpdir}/openshift/99_openshift-cluster-api_master-machines-*.yaml",
      "rm -f ${local.ocpdir}/openshift/99_openshift-cluster-api_worker-machineset-*.yaml",
      "sed -i s/true/false/g ${local.ocpdir}/manifests/cluster-scheduler-02-config.yml",

      ###############################
      ### Creating ignition files ###
      ###############################

      "./openshift-install create ignition-configs --dir=${local.ocpdir} --log-level=debug",

      #######################################
      ### Creating identity and adding role###
      #######################################
      "RESOURCE_GROUP=$INFRA_ID-rg",
      "az group create --name $RESOURCE_GROUP --location ${var.region}",
      "az identity create -g $RESOURCE_GROUP -n $INFRA_ID-identity",
      "sleep 1m", ## Sleep for a minute for identity to get created completely. otherwise it throws some errors during execution. 
      "PRINCIPAL_ID=`az identity show -g $RESOURCE_GROUP -n $INFRA_ID-identity --query principalId --out tsv`",
      "RESOURCE_GROUP_ID=`az group show -g $RESOURCE_GROUP --query id --out tsv`",
      "az role assignment create --assignee-object-id $PRINCIPAL_ID --role 'Contributor' --scope $RESOURCE_GROUP_ID",

      ####################################
      ### Creating storage container ###
      ####################################

      "az storage account create -g $RESOURCE_GROUP --location ${var.region} --name ${var.cluster-name}sa --kind Storage --sku Standard_LRS",
      "ACCOUNT_KEY=`az storage account keys list -g $RESOURCE_GROUP --account-name ${var.cluster-name}sa --query '[0].value' -o tsv`",
      "VHD_URL=`curl -s https://raw.githubusercontent.com/openshift/installer/release-4.6/data/data/rhcos.json | jq -r .azure.url`",
      "echo --------$VHD_URL",
      "az storage container create --name vhd --account-name ${var.cluster-name}sa --account-key $ACCOUNT_KEY",
      "az storage blob copy start --account-name ${var.cluster-name}sa --account-key $ACCOUNT_KEY --destination-blob 'rhcos.vhd' --destination-container vhd --source-uri $VHD_URL",
      "chmod 777 /home/${var.admin-username}/storage_blob_copy_status.sh",
      "/home/${var.admin-username}/storage_blob_copy_status.sh ${var.cluster-name}sa $ACCOUNT_KEY ",
      # "sleep 6m",
      "az storage container create --name files --account-name ${var.cluster-name}sa --account-key $ACCOUNT_KEY --public-access blob",
      "az storage blob upload --account-name ${var.cluster-name}sa --account-key $ACCOUNT_KEY -c 'files' -f '${local.ocpdir}/bootstrap.ign' -n 'bootstrap.ign'",
      "az network private-dns zone create -g $RESOURCE_GROUP -n ${var.cluster-name}.${var.dnszone}",

      ##########################
      ### 01.Vnet creation ###
      ###########################

      "az deployment group create -g $RESOURCE_GROUP --template-file '${local.ocpdir}/01_vnet.json' --parameters baseName=$INFRA_ID",
      "az network private-dns link vnet create -g $RESOURCE_GROUP -z ${var.cluster-name}.${var.dnszone} -n $INFRA_ID-network-link -v $INFRA_ID-vnet -e false",

      #####################################################
      ## Vnet peering  bootnode vnet to cluster id vnet ##
      #####################################################

      ## cluster vnet to bootnode vnet 
      "az network vnet peering create -g $RESOURCE_GROUP -n $INFRA_ID-vnet2bootnodevnet --vnet-name $INFRA_ID-vnet --remote-vnet ${local.bootnode_vnet_id} --allow-vnet-access --allow-forwarded-traffic",
      "az network vnet peering create -g ${local.bootnode_resource_group_name} -n bootnodevnet2$INFRA_ID-vnet --vnet-name ${local.bootnode_vnet_name} --remote-vnet /subscriptions/${local.subscription_id}/resourceGroups/$INFRA_ID-rg/providers/Microsoft.Network/virtualNetworks/$INFRA_ID-vnet --allow-vnet-access --allow-forwarded-traffic",

    ]
  }
  depends_on = [
    azurerm_virtual_machine.bootnode,
    null_resource.install_openshift_disconnected_pre_req,
    null_resource.install_openshift_connected_pre_req
  ]
}

resource "null_resource" "vnet_peering" {
  count = var.disconnected-cluster == "yes" ? 1 : 0
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    directory             = local.ocpdir
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "file" {
    source      = "../scripts/storage_blob_copy_status.sh"
    destination = "/home/${var.admin-username}/storage_blob_copy_status.sh"
  }
  provisioner "remote-exec" {
    inline = [

      ###################################################
      #### az login with service principal ####
      ###################################################
      "az login --service-principal -u ${local.app_url} -p ${local.client_secret} --tenant ${local.tenant_id}",
      "az account set -s ${local.subscription_id}",

      #######################################
      ### variables ###
      #######################################

      # expor the Infra id
      "export INFRA_ID=`jq -r .infraID ${local.ocpdir}/metadata.json`",
      "RESOURCE_GROUP=$INFRA_ID-rg",

      #####################
      ## Vnet peering ##
      #####################

      ## cluster vnet to mirror registry vnet 
      "az network vnet peering create -g $RESOURCE_GROUP -n $INFRA_ID-vnet2mirrornodevnet --vnet-name $INFRA_ID-vnet --remote-vnet ${var.mirror-node-vnet-id} --allow-vnet-access --allow-forwarded-traffic",
      "az network vnet peering create -g ${var.mirror-node-resource-group} -n mirrornodevnet2$INFRA_ID-vnet --vnet-name ${var.mirror-node-vnet-name} --remote-vnet /subscriptions/${local.subscription_id}/resourceGroups/$INFRA_ID-rg/providers/Microsoft.Network/virtualNetworks/$INFRA_ID-vnet --allow-vnet-access --allow-forwarded-traffic",

    ]
  }
  depends_on = [
    azurerm_virtual_machine.bootnode,
    null_resource.install_openshift_disconnected_pre_req,
    null_resource.install_openshift_connected_pre_req,
    null_resource.vnet_creation
  ]
}

resource "null_resource" "install_openshift" {
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    directory             = local.ocpdir
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "file" {
    source      = "../scripts/storage_blob_copy_status.sh"
    destination = "/home/${var.admin-username}/storage_blob_copy_status.sh"
  }
  provisioner "remote-exec" {
    inline = [

      ###################################################
      #### az login with service principal ####
      ###################################################
      "az login --service-principal -u ${local.app_url} -p ${local.client_secret} --tenant ${local.tenant_id}",
      "az account set -s ${local.subscription_id}",

      #######################################
      ### Setting up variables ###
      #######################################

      ## export infra id 
      "export INFRA_ID=`jq -r .infraID ${local.ocpdir}/metadata.json`",
      "RESOURCE_GROUP=$INFRA_ID-rg",
      "ACCOUNT_KEY=`az storage account keys list -g $RESOURCE_GROUP --account-name ${var.cluster-name}sa --query '[0].value' -o tsv`",
      "VHD_URL=`curl -s https://raw.githubusercontent.com/openshift/installer/release-4.6/data/data/rhcos.json | jq -r .azure.url`",
      "echo --------$VHD_URL",

      #####################
      ## VHD Blob url  ##
      #####################

      "VHD_BLOB_URL=`az storage blob url --account-name ${var.cluster-name}sa --account-key $ACCOUNT_KEY -c vhd -n 'rhcos.vhd' -o tsv`",

      ##########################
      ### 02.storage creation ###
      ###########################
      "az deployment group create -g $RESOURCE_GROUP --template-file '${local.ocpdir}/02_storage.json' --parameters vhdBlobURL=$VHD_BLOB_URL --parameters baseName=$INFRA_ID",

      ##########################
      ### 03.infra creation ###
      ###########################

      "az deployment group create -g $RESOURCE_GROUP --template-file '${local.ocpdir}/03_infra.json' --parameters privateDNSZoneName='${var.cluster-name}.${var.dnszone}' --parameters baseName=$INFRA_ID",
      "PUBLIC_IP=`az network public-ip list -g $RESOURCE_GROUP --query \"${local.public_ip_query}\" -o tsv`",
      "az network dns record-set a add-record -g ${var.dnszone-resource-group} -z ${var.dnszone} -n api.${var.cluster-name} -a $PUBLIC_IP --ttl 60",

      #############################
      ### 04.bootstrap ignition ###
      ##############################

      "BOOTSTRAP_URL=`az storage blob url --account-name ${var.cluster-name}sa --account-key $ACCOUNT_KEY -c 'files' -n 'bootstrap.ign' -o tsv`",
      "BOOTSTRAP_IGNITION=`jq -rcnM --arg v \"3.1.0\" --arg url $BOOTSTRAP_URL '{ignition:{version:$v,config:{replace:{source:$url}}}}' | base64 | tr -d '\n'`",
      "az deployment group create -g $RESOURCE_GROUP --template-file '${local.ocpdir}/04_bootstrap.json' --parameters bootstrapIgnition=$BOOTSTRAP_IGNITION --parameters sshKeyData=\"${local.ssh_key}\" --parameters baseName=$INFRA_ID",

      #############################
      ### 05.master ignition ###
      ##############################

      "MASTER_IGNITION=`cat ${local.ocpdir}/master.ign | base64 | tr -d '\n'`",
      "az deployment group create -g $RESOURCE_GROUP --template-file '${local.ocpdir}/05_masters.json' --parameters masterIgnition=$MASTER_IGNITION --parameters sshKeyData=\"${local.ssh_key}\" --parameters privateDNSZoneName='${var.cluster-name}.${var.dnszone}' --parameters baseName=$INFRA_ID",
      "./openshift-install wait-for bootstrap-complete --dir=${local.ocpdir} --log-level debug",

      ##############################
      ### bootsrap node deletion ###
      ##############################

      "az network nsg rule delete -g $RESOURCE_GROUP --nsg-name $INFRA_ID-nsg --name bootstrap_ssh_in",
      "az vm stop -g $RESOURCE_GROUP --name $INFRA_ID-bootstrap",
      "az vm deallocate -g $RESOURCE_GROUP  --name $INFRA_ID-bootstrap",
      "az vm delete -g $RESOURCE_GROUP --name $INFRA_ID-bootstrap --yes",
      "az disk delete -g $RESOURCE_GROUP --name $INFRA_ID-bootstrap_OSDisk --no-wait --yes",
      "az network nic delete -g $RESOURCE_GROUP --name $INFRA_ID-bootstrap-nic --no-wait",
      "az storage blob delete --account-key $ACCOUNT_KEY --account-name ${var.cluster-name}sa --container-name files --name bootstrap.ign",
      "az network public-ip delete -g $RESOURCE_GROUP --name $INFRA_ID-bootstrap-ssh-pip",

      #############################
      ### 06.worker ignition ###
      ##############################

      "WORKER_IGNITION=`cat ${local.ocpdir}/worker.ign | base64 | tr -d '\n'`",
      "az deployment group create -g $RESOURCE_GROUP --template-file '${local.ocpdir}/06_workers.json' --parameters workerIgnition=$WORKER_IGNITION --parameters sshKeyData=\"${local.ssh_key}\" --parameters baseName=$INFRA_ID",

      #############################
      ### CSR approvals  ###
      ##############################

      # Approving CSRs. Sometimes it is taking time to get the csr generated so repeating this step few times. 
      "export KUBECONFIG=${local.ocpdir}/auth/kubeconfig",
      "echo 'approving CSRs'",
      "oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{\"\\n\"}}{{end}}{{end}}' | xargs oc adm certificate approve",
      "sleep 30",
      "echo 'approving CSRs'",
      "oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{\"\\n\"}}{{end}}{{end}}' | xargs oc adm certificate approve",
      "sleep 30",
      "oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{\"\\n\"}}{{end}}{{end}}' | xargs oc adm certificate approve",
      "sleep 2m",
      "echo 'oc get csr -o go-template={{range .items}}{{if not .status}}{{.metadata.name}}{{\"\\n\"}}{{end}}{{end}}'",
      "CSR=$(oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{\"\\n\"}}{{end}}{{end}}')",
      "echo $CSR",
      "echo $CSR | xargs oc adm certificate approve",
      "sleep 30",
      "PUBLIC_IP_ROUTER=`oc -n openshift-ingress get service router-default --no-headers | awk '{print $4}'`",
      "az network dns record-set a add-record -g ${var.dnszone-resource-group} -z ${var.dnszone} -n *.apps.${var.cluster-name} -a $PUBLIC_IP_ROUTER --ttl 300",
      "az network private-dns record-set a create -g $RESOURCE_GROUP -z ${var.cluster-name}.${var.dnszone} -n *.apps --ttl 300",
      "az network private-dns record-set a add-record -g $RESOURCE_GROUP -z ${var.cluster-name}.${var.dnszone} -n *.apps -a $PUBLIC_IP_ROUTER",

      ####################################
      ### Openshift install completion ###
      ####################################

      "./openshift-install --dir=${local.ocpdir} wait-for install-complete --log-level=debug",
      "CSR=$(oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{\"\\n\"}}{{end}}{{end}}')",
      "echo $CSR | xargs oc adm certificate approve",
      "oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{\"\\n\"}}{{end}}{{end}}' | xargs oc adm certificate approve",
      "sleep 30",
      "sudo yum install -y httpd-tools",
      "mkdir -p /home/${var.admin-username}/.kube",
      "cp /home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig /home/${var.admin-username}/.kube/config",
      "cat > /home/${var.admin-username}/.ssh/id_rsa <<EOL\n${file(var.ssh-private-key-file-path)}\nEOL",
      "sudo chmod 0600 /home/${var.admin-username}/.ssh/id_rsa",
      "oc login -u kubeadmin -p $(cat ${local.ocpdir}/auth/kubeadmin-password) -n openshift-machine-api"
    ]
  }

  # Destroy OCP Cluster before destroying the bootnode
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = self.triggers.bootnode_ip_address
      user        = self.triggers.username
      private_key = file(self.triggers.private_key_file_path)
    }
    when = destroy
    inline = [
      "/home/${self.triggers.username}/openshift-install destroy cluster --dir=${self.triggers.directory} --log-level=debug",
      "sleep 300"
    ]
  }
  depends_on = [
    azurerm_virtual_machine.bootnode,
    null_resource.install_openshift_disconnected_pre_req,
    null_resource.install_openshift_connected_pre_req,
    null_resource.vnet_creation,
    null_resource.vnet_peering
  ]
}

resource "null_resource" "openshift_post_install" {
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
  }
  connection {
    type        = "ssh"
    host        = azurerm_public_ip.bootnode.ip_address
    user        = var.admin-username
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

      # expor the clsuter id

      "export CLUSTER_ID=`jq -r .infraID ${local.ocpdir}/metadata.json`",

      # For now commenting cluster autoscaler in UPI method. 
      # "cat > ${local.ocptemplates}/cluster-autoscaler.yaml <<EOL\n${data.template_file.clusterautoscaler.rendered}\nEOL",
      "cat > ${local.ocptemplates}/machine-health-check-${var.single-or-multi-zone}.yaml <<EOL\n${data.template_file.machine-health-check.rendered}\nEOL",
      "sed -i s/${random_id.randomId.hex}/$CLUSTERID/g /home/${var.admin-username}/ocpfourxtemplates/machine-health-check-${var.single-or-multi-zone}.yaml",
      "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
      #"oc create -f ${local.ocptemplates}/cluster-autoscaler.yaml",
      "oc create -f ${local.ocptemplates}/machine-health-check-${var.single-or-multi-zone}.yaml",

      # Create Registry Route
      "oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{\"spec\":{\"defaultRoute\":true, \"replicas\":${var.worker-node-count}}}'",
      "sleep 100",
      "sudo oc login https://api.${var.cluster-name}.${var.dnszone}:6443 -u '${var.openshift-username}' -p '${var.openshift-password}' --insecure-skip-tls-verify=true"
    ]
  }
  depends_on = [
    azurerm_virtual_machine.bootnode,
    null_resource.install_openshift_disconnected_pre_req,
    null_resource.install_openshift_connected_pre_req,
    null_resource.vnet_creation,
    null_resource.vnet_peering,
    null_resource.install_openshift
  ]
}

resource "null_resource" "create_network_related_artifacts" {
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    directory             = local.ocpdir
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [

      # expor the clsuter id
      "export CLUSTER_ID=`jq -r .infraID ${local.ocpdir}/metadata.json`",

      # az login 
      "az login --service-principal -u ${local.app_url} -p ${local.client_secret} --tenant ${local.tenant_id}",
      "az account set -s ${local.subscription_id}",

      ### Adding security rules to the group 

      # Cluster id nsg - rule ssh  
      "az network nsg rule create -g $CLUSTER_ID-rg --nsg-name $CLUSTER_ID-nsg -n sshBootnode2Mastersubnet --priority 110 --direction Inbound --access Allow --protocol Tcp --source-port-ranges '*' --destination-port-ranges 22 --source-address-prefixes '${var.bootnode-subnet-cidr}' --destination-address-prefixes '${var.master-subnet-cidr}'",
      "az network nsg rule create -g $CLUSTER_ID-rg --nsg-name $CLUSTER_ID-nsg -n sshBootnode2workersubnet --priority 111 --direction Inbound --access Allow --protocol Tcp --source-port-ranges '*' --destination-port-ranges 22 --source-address-prefixes '${var.bootnode-subnet-cidr}' --destination-address-prefixes '${var.worker-subnet-cidr}'",

    ]
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install
  ]


}
resource "null_resource" "create_nfs_related_artifacts" {
  count = var.storage == "nfs" ? 1 : 0
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    directory             = local.ocpdir
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [

      # expor the clsuter id
      "export CLUSTER_ID=`jq -r .infraID ${local.ocpdir}/metadata.json`",

      # az login 
      "az login --service-principal -u ${local.app_url} -p ${local.client_secret} --tenant ${local.tenant_id}",
      "az account set -s ${local.subscription_id}",

      ## Creating nfs nic 
      "az network nic create -g $CLUSTER_ID-rg --vnet-name $CLUSTER_ID-vnet --subnet $CLUSTER_ID-worker-subnet -n $CLUSTER_ID-nfs-nic",

      ### Adding security rules to the group 
      # cluster id nsg - rule nfsin 
      "az network nsg rule create -g $CLUSTER_ID-rg --nsg-name $CLUSTER_ID-nsg -n nfsin --priority 700 --direction Inbound --access Allow --protocol '*' --source-port-ranges '*' --destination-port-ranges 2049 --source-address-prefixes '*' --destination-address-prefixes '*'",

    ]

  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    null_resource.create_network_related_artifacts
  ]

}

resource "null_resource" "provision_nfs_server" {
  count = var.storage == "nfs" ? 1 : 0
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
    directory             = local.ocpdir
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [

      # export the clsuter id
      "export CLUSTER_ID=`jq -r .infraID ${local.ocpdir}/metadata.json`",
      "echo $CLUSTER_ID ",
      # az login 
      "az login --service-principal -u ${local.app_url} -p ${local.client_secret} --tenant ${local.tenant_id}",
      "az account set -s ${local.subscription_id}",
      ## Provision nfs serveer 
      "az vm create --name $CLUSTER_ID-nfs --resource-group $CLUSTER_ID-rg --location ${var.region} --nics \"/subscriptions/${var.azure-subscription-id}/resourceGroups/$CLUSTER_ID-rg/providers/Microsoft.Network/networkInterfaces/$CLUSTER_ID-nfs-nic\" --size Standard_D8s_v3 --os-disk-name $CLUSTER_ID-nfs-OsDisk --os-disk-caching ReadWrite --data-disk-sizes-gb ${var.storage-disk-size} --data-disk-caching ReadWrite --computer-name nfsnode --admin-username core --image RedHat:RHEL:7-RAW:latest --authentication-type ssh --ssh-dest-key-path '/home/${var.admin-username}/.ssh/authorized_keys' --ssh-key-values '${var.ssh-public-key}'",

    ]
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    null_resource.create_network_related_artifacts,
    null_resource.create_nfs_related_artifacts
  ]

}

resource "null_resource" "install-nfs-server" {
  count = var.storage == "nfs" ? 1 : 0
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [
      # export the clsuter id
      "export CLUSTER_ID=`jq -r .infraID ${local.ocpdir}/metadata.json`",
      "echo $CLUSTER_ID ",
      # az login 
      "az login --service-principal -u ${local.app_url} -p ${local.client_secret} --tenant ${local.tenant_id}",
      "az account set -s ${local.subscription_id}",
      # get the ip address of the nfs server 
      "nfs_ip_address=`az vm show -d -g $CLUSTER_ID-rg -n $CLUSTER_ID-nfs --query 'privateIps' -o tsv`",
      "echo $nfs_ip_address ",
      "cat > ${local.ocptemplates}/setup-nfs.sh <<EOL\n${file("../nfs_module/setup-nfs.sh")}\nEOL",
      "scp -o \"StrictHostKeyChecking=no\" ${local.ocptemplates}/setup-nfs.sh ${var.admin-username}@$nfs_ip_address:/home/${var.admin-username}/setup-nfs.sh",
      "ssh -o \"StrictHostKeyChecking=no\" ${var.admin-username}@$nfs_ip_address sudo sh /home/${var.admin-username}/setup-nfs.sh"
    ]
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    null_resource.create_network_related_artifacts,
    null_resource.create_nfs_related_artifacts,
    null_resource.provision_nfs_server
  ]
}

resource "null_resource" "install_nfs_client" {
  count = var.storage == "nfs" ? 1 : 0
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [
      # export the clsuter id
      "export CLUSTER_ID=`jq -r .infraID ${local.ocpdir}/metadata.json`",
      "echo $CLUSTER_ID ",
      # az login 
      "az login --service-principal -u ${local.app_url} -p ${local.client_secret} --tenant ${local.tenant_id}",
      "az account set -s ${local.subscription_id}",
      # get the ip address of the nfs server 
      "nfs_ip_address=`az vm show -d -g $CLUSTER_ID-rg -n $CLUSTER_ID-nfs --query 'privateIps' -o tsv`",
      "echo $nfs_ip_address ",
      # oc login 
      "oc login -u kubeadmin -p $(cat ${local.ocpdir}/auth/kubeadmin-password) -n openshift-machine-api",
      "echo add_policy_start",
      "oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:kube-system:nfs-client-provisioner",
      "echo add_policy_complete",
      "cat > ${local.ocptemplates}/nfs-template.yaml <<EOL\n${data.template_file.nfs-template[count.index].rendered}\nEOL",
      "echo template_copy_completed",
      "sed -i -e s#nfs_server_private_ip_will_be_replaced#$nfs_ip_address#g ${local.ocptemplates}/nfs-template.yaml",
      "echo template_replace",
      "oc process -f ${local.ocptemplates}/nfs-template.yaml | oc create -n kube-system -f -",
    ]
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    null_resource.create_network_related_artifacts,
    null_resource.create_nfs_related_artifacts,
    null_resource.provision_nfs_server,
    null_resource.install-nfs-server
  ]
}

resource "null_resource" "install_portworx_disconnected" {
  count = var.storage == "portworx" && var.disconnected-cluster == "yes" ? 1 : 0
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "file" {
    source      = "../scripts/create-portworx-disconnected.sh"
    destination = "/home/${var.admin-username}/create-portworx-disconnected.sh"
  }

  provisioner "file" {
    source      = "../portworx_module/px-ag-install.sh"
    destination = "/home/${var.admin-username}/px-ag-install.sh"
  }

  provisioner "file" {
    source      = "../portworx_module/versions"
    destination = "/home/${var.admin-username}/versions"
  }
  provisioner "remote-exec" {
    inline = [
      "cat > ${local.ocptemplates}/px-operator-disconnected.yaml <<EOL\n${file("../portworx_module/px-operator-disconnected.yaml")}\nEOL",
      "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
      "sudo chmod +x /home/${var.admin-username}/px-ag-install.sh ",
      "sudo chmod +x /home/${var.admin-username}/create-portworx-disconnected.sh",
      "./create-portworx-disconnected.sh",
      "result=$(oc apply -f \"${var.portworx-spec-url}\")",
      "echo $result",
      "sleep 6m"
    ]
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    null_resource.create_network_related_artifacts,
  ]
}
resource "null_resource" "install_portworx" {
  count = var.storage == "portworx" && var.disconnected-cluster == "no" ? 1 : 0
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [
      "cat > ${local.ocptemplates}/px-install.yaml <<EOL\n${data.template_file.px-install.rendered}\nEOL",
      "result=$(oc create -f ${local.ocptemplates}/px-install.yaml)",
      "sleep 60",
      "echo $result",
      "result=$(oc apply -f \"${var.portworx-spec-url}\")",
      "echo $result",
      "echo 'Sleeping for 5 mins to get portworx storage cluster up' ",
      "sleep 5m"
    ]
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    null_resource.create_network_related_artifacts,
  ]
}

resource "null_resource" "setup_sc_with_pwx_encryption" {
  count = var.storage == "portworx" && var.portworx-encryption == "yes" && var.portworx-encryption-key != "" ? 1 : 0
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [
      # Creating a cluster wide secret key and using it for portworx encryption
      "oc -n kube-system create secret generic px-vol-encryption --from-literal=cluster-wide-secret-key=${var.portworx-encryption-key}",
      "PX_POD=$(oc get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')",
      "echo $PX_POD",
      "result=$(oc exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl secrets set-cluster-key --secret cluster-wide-secret-key)",
      "echo $result",
      # Create storageclasse with secure flag as true. 
      "cat > ${local.ocptemplates}/px-storageclasses-secure.yaml <<EOL\n${data.template_file.px-storageclasses-secure.rendered}\nEOL",
      "result=$(oc create -f ${local.ocptemplates}/px-storageclasses-secure.yaml)",
      "echo $result"
    ]
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    null_resource.create_network_related_artifacts,
    null_resource.install_portworx,
    null_resource.install_portworx_disconnected
  ]
}


resource "null_resource" "setup_sc_without_pwx_encryption" {
  count = var.storage == "portworx" && var.portworx-encryption == "no" ? 1 : 0
  triggers = {
    bootnode_ip_address   = azurerm_public_ip.bootnode.ip_address
    username              = var.admin-username
    private_key_file_path = var.ssh-private-key-file-path
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_ip_address
    user        = self.triggers.username
    private_key = file(self.triggers.private_key_file_path)
  }
  provisioner "remote-exec" {
    inline = [
      "cat > ${local.ocptemplates}/px-storageclasses.yaml <<EOL\n${data.template_file.px-storageclasses.rendered}\nEOL",
      "result=$(oc create -f ${local.ocptemplates}/px-storageclasses.yaml)",
      "echo $result"
    ]
  }
  depends_on = [
    null_resource.install_openshift,
    null_resource.openshift_post_install,
    null_resource.create_network_related_artifacts,
    null_resource.install_portworx,
    null_resource.install_portworx_disconnected,
  ]
}