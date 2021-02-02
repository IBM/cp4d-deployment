locals {
  ocpdir       = "ocpfourx"
  ocptemplates = "ocpfourxtemplates"

  azspub = {
    single_zone = [chomp(data.local_file.publicsubnet.content), chomp(data.local_file.publicsubnet.content), chomp(data.local_file.publicsubnet.content)]
    multi_zone  = [element(split(",", chomp(data.local_file.publicsubnet.content)), 0), element(split(",", chomp(data.local_file.publicsubnet.content)), 1), element(split(",", chomp(data.local_file.publicsubnet.content)), 2)]
  }
  subnetspub = local.azspub[var.azlist]

  azspri = {
    single_zone = [chomp(data.local_file.privatesubnet.content), chomp(data.local_file.privatesubnet.content), chomp(data.local_file.privatesubnet.content)]
    multi_zone  = [element(split(",", chomp(data.local_file.privatesubnet.content)), 0), element(split(",", chomp(data.local_file.privatesubnet.content)), 1), element(split(",", chomp(data.local_file.privatesubnet.content)), 2)]
  }
  subnetspri = local.azspri[var.azlist]

  public-subnet-exist  = join(",", [var.subnetid-public1, var.subnetid-public2, var.subnetid-public3])
  private-subnet-exist = join(",", [var.subnetid-private1, var.subnetid-private2, var.subnetid-private3])

  private-subnet-exist-lst = [var.subnetid-private1, var.subnetid-private2, var.subnetid-private3]

  machine-healthcheck = var.azlist == "multi_zone" ? data.template_file.machinehealthcheck[0].rendered : data.template_file.machinehealthcheck-1AZ[0].rendered

  install-config = var.disconnected-cluster == "yes" ? data.template_file.installconfig-disconnected[0].rendered : data.template_file.installconfig[0].rendered
}

resource "null_resource" "create_upi_resources" {
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

      ######## install awscli on bootnode ########
      "sed -i -e s/\r$// *.sh",
      "sudo yum -y install python3",
      "sudo yum -y install wget",
      "sudo yum -y install bind-utils",
      "curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null",
      "python3 get-pip.py --user > /dev/null",
      "export PATH=\"~/.local/bin:$PATH\"",
      "source ~/.bash_profile > /dev/null",
      "pip install awscli --upgrade --user > /dev/null",
      "sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm",
      "sudo yum install jq -y",
      "sudo yum install -y httpd-tools",


      ######## Get OpenShift Installer ########
      "chmod +x /home/${self.triggers.username}/*.sh",
      "mkdir -p ${local.ocpdir}",
      "mkdir -p ${local.ocptemplates}",

      "wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.ocp-version}/openshift-install-linux.tar.gz",
      "wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.ocp-version}/openshift-client-linux.tar.gz",
      "tar -xvf openshift-install-linux.tar.gz",
      "sudo tar -xvf openshift-client-linux.tar.gz -C /usr/local/bin",
      "mkdir -p /home/${var.admin-username}/.aws",
      "cat > /home/${var.admin-username}/.aws/credentials <<EOL\n${data.template_file.awscreds.rendered}\nEOL",
      "cat > /home/${var.admin-username}/.aws/config <<EOL\n${data.template_file.awsregion.rendered}\nEOL",

      "chmod +x openshift-install",
      "sudo chmod +x /usr/local/bin/oc",
      "sudo chmod +x /usr/local/bin/kubectl",


      ######## Creating the Kubernetes manifest and Ignition config files ########
      "echo '#############################################################'",
      "echo 'Creating the Kubernetes manifest and Ignition config files!!!'",
      "echo '#############################################################'",

      "cat > ${local.ocpdir}/install-config.yaml <<EOL\n${local.install-config}\nEOL",
      "./openshift-install create manifests --dir=${local.ocpdir}",
      "rm -f ${local.ocpdir}/openshift/99_openshift-cluster-api_master-machines-*.yaml",
      "rm -f ${local.ocpdir}/openshift/99_openshift-cluster-api_worker-machineset-*.yaml",
      "sed -i s/true/false/g ${local.ocpdir}/manifests/cluster-scheduler-02-config.yml",

      "./openshift-install create ignition-configs --dir=${local.ocpdir}",
      "sleep 20",

      "cat > /home/${var.admin-username}/.ssh/id_rsa <<EOL\n${file(var.ssh-private-key-file-path)}\nEOL",
      "sudo chmod 0600 /home/${var.admin-username}/.ssh/id_rsa",
      "mkdir -p /home/${var.admin-username}/.kube",
      "cp /home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig /home/${var.admin-username}/.kube/config",
      "mv /home/${var.admin-username}/*.yaml ${local.ocptemplates}",


      ######## Creating networking and load balancing components ########
      "echo '####################################################'",
      "echo 'Creating Networking and Load Balancing Components!!!'",
      "echo '####################################################'",

      "INFRANAME=`jq -r .infraID ${local.ocpdir}/metadata.json`",
      "cat > ${local.ocptemplates}/nlb-parameter.json <<EOL\n${data.template_file.nlb.rendered}\nEOL",
      "sed -i -e s#INFRANAME#$INFRANAME#g ${local.ocptemplates}/nlb-parameter.json",

      "aws cloudformation create-stack --stack-name nlb-stack --template-body file://${local.ocptemplates}/nlb-template.yaml --parameters file://${local.ocptemplates}/nlb-parameter.json --capabilities CAPABILITY_NAMED_IAM",


      ######## Creating security group and roles ########
      "echo '####################################'",
      "echo 'Creating Security Group and Roles!!!'",
      "echo '####################################'",

      "cat > ${local.ocptemplates}/sg-role-parameter.json <<EOL\n${data.template_file.sg-role.rendered}\nEOL",
      "sed -i -e s#INFRANAME#$INFRANAME#g ${local.ocptemplates}/sg-role-parameter.json",

      "aws cloudformation create-stack --stack-name sg-role-stack --template-body file://${local.ocptemplates}/sg-role-template.yaml --parameters file://${local.ocptemplates}/sg-role-parameter.json --capabilities CAPABILITY_NAMED_IAM",
      "sleep 6m",


      ######## Creating the bootstrap node ########
      "echo '##############################'",
      "echo 'Creating the BootStrap Node!!!'",
      "echo '##############################'",

      "aws s3 mb s3://${var.cluster-name}-infra",
      "aws s3 cp ${local.ocpdir}/bootstrap.ign s3://${var.cluster-name}-infra/bootstrap.ign",
      "sleep 30",

      "cat > ${local.ocptemplates}/bootstrap-parameter.json <<EOL\n${data.template_file.bootstrap.rendered}\nEOL",
      "MASTERSECGROUPID=$(aws cloudformation describe-stacks --stack-name sg-role-stack --query Stacks[0].Outputs[?OutputKey==\\'MasterSecurityGroupId\\'].OutputValue --output text)",
      "REGNLBTGTLMDARN=$(aws cloudformation describe-stacks --stack-name nlb-stack --query Stacks[0].Outputs[?OutputKey==\\'RegisterNlbIpTargetsLambda\\'].OutputValue --output text)",
      "EXTAPITGTGRPARN=$(aws cloudformation describe-stacks --stack-name nlb-stack --query Stacks[0].Outputs[?OutputKey==\\'ExternalApiTargetGroupArn\\'].OutputValue --output text)",
      "INTAPITGTGRPARN=$(aws cloudformation describe-stacks --stack-name nlb-stack --query Stacks[0].Outputs[?OutputKey==\\'InternalApiTargetGroupArn\\'].OutputValue --output text)",
      "INTSVCTGTGRPARN=$(aws cloudformation describe-stacks --stack-name nlb-stack --query Stacks[0].Outputs[?OutputKey==\\'InternalServiceTargetGroupArn\\'].OutputValue --output text)",

      "sed -i -e s#INFRANAME#$INFRANAME#g ${local.ocptemplates}/bootstrap-parameter.json",
      "sed -i -e s#MASTER-SEC-GROUPID#$MASTERSECGROUPID#g ${local.ocptemplates}/bootstrap-parameter.json",
      "sed -i -e s#REG-NLB-TGT-LMDARN#$REGNLBTGTLMDARN#g ${local.ocptemplates}/bootstrap-parameter.json",
      "sed -i -e s#EXT-API-TGT-GRPARN#$EXTAPITGTGRPARN#g ${local.ocptemplates}/bootstrap-parameter.json",
      "sed -i -e s#INT-API-TGT-GRPARN#$INTAPITGTGRPARN#g ${local.ocptemplates}/bootstrap-parameter.json",
      "sed -i -e s#INT-SVC-TGT-GRPARN#$INTSVCTGTGRPARN#g ${local.ocptemplates}/bootstrap-parameter.json",

      "aws cloudformation create-stack --stack-name bootstrap-stack --template-body file://${local.ocptemplates}/bootstrap-template.yaml --parameters file://${local.ocptemplates}/bootstrap-parameter.json --capabilities CAPABILITY_NAMED_IAM",


      ######## Creating the control plane machines ########
      "echo '######################################'",
      "echo 'Creating the Control Plane Machines!!!'",
      "echo '######################################'",

      "cat > ${local.ocptemplates}/controlplane-parameter.json <<EOL\n${data.template_file.controlplane.rendered}\nEOL",
      "CERTAUTHORITIES=$(cat ${local.ocpdir}/master.ign | sed -e 's/.*data\\(.*\\)==.*/\\1/')",
      "PVTHOSTEDZONEID=$(aws cloudformation describe-stacks --stack-name nlb-stack --query Stacks[0].Outputs[?OutputKey==\\'PrivateHostedZoneId\\'].OutputValue --output text)",
      "MASTERINSTPRFLNAME=$(aws cloudformation describe-stacks --stack-name sg-role-stack --query Stacks[0].Outputs[?OutputKey==\\'MasterInstanceProfile\\'].OutputValue --output text)",

      "sed -i -e s#INFRANAME#$INFRANAME#g ${local.ocptemplates}/controlplane-parameter.json",
      "sed -i -e s#PVT-HOSTED-ZONE-ID#$PVTHOSTEDZONEID#g ${local.ocptemplates}/controlplane-parameter.json",
      "sed -i -e s#MASTER-SEC-GROUPID#$MASTERSECGROUPID#g ${local.ocptemplates}/controlplane-parameter.json",
      "sed -i -e s#CERT-AUTHORITIES#$CERTAUTHORITIES#g ${local.ocptemplates}/controlplane-parameter.json",
      "sed -i -e s#MASTER-INST-PRFL-NAME#$MASTERINSTPRFLNAME#g ${local.ocptemplates}/controlplane-parameter.json",
      "sed -i -e s#REG-NLB-TGT-LMDARN#$REGNLBTGTLMDARN#g ${local.ocptemplates}/controlplane-parameter.json",
      "sed -i -e s#EXT-API-TGT-GRPARN#$EXTAPITGTGRPARN#g ${local.ocptemplates}/controlplane-parameter.json",
      "sed -i -e s#INT-API-TGT-GRPARN#$INTAPITGTGRPARN#g ${local.ocptemplates}/controlplane-parameter.json",
      "sed -i -e s#INT-SVC-TGT-GRPARN#$INTSVCTGTGRPARN#g ${local.ocptemplates}/controlplane-parameter.json",

      "aws cloudformation create-stack --stack-name controlplane-stack --template-body file://${local.ocptemplates}/controlplane-template.yaml --parameters file://${local.ocptemplates}/controlplane-parameter.json",
    ]
  }
  depends_on = [
    aws_instance.bootnode,
    null_resource.file_copy,
  ]
}

######## Creating the worker nodes ########
resource "null_resource" "create_worker_node" {
  count = var.worker_replica_count
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
    psubnet               = coalesce(element(split(",", chomp(data.local_file.privatesubnet.content)), (count.index + 1) % length(chomp(data.local_file.privatesubnet.content))), local.private-subnet-exist-lst[(count.index + 1) % length(local.private-subnet-exist-lst)])
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_public_ip
    user        = self.triggers.username
    private_key = file(self.triggers.private-key-file-path)
  }
  provisioner "remote-exec" {
    inline = [
      "python3 get-pip.py --user 2> /dev/null",
      "export PATH=\"~/.local/bin:$PATH\" 2> /dev/null",
      "source ~/.bash_profile 2> /dev/null",
      "pip install awscli --upgrade --user 2> /dev/null",

      "cat > ${local.ocptemplates}/workernode-parameter-${count.index}.json <<EOL\n${data.template_file.workernode.rendered}\nEOL",
      "INFRANAME=`jq -r .infraID ${local.ocpdir}/metadata.json`",
      "CERTAUTHORITIES=$(cat ${local.ocpdir}/worker.ign | sed -e 's/.*data\\(.*\\)==.*/\\1/')",
      "WORKERSECGROUPID=$(aws cloudformation describe-stacks --stack-name sg-role-stack --query Stacks[0].Outputs[?OutputKey==\\'WorkerSecurityGroupId\\'].OutputValue --output text)",
      "WORKERINSTPRFLNAME=$(aws cloudformation describe-stacks --stack-name sg-role-stack --query Stacks[0].Outputs[?OutputKey==\\'WorkerInstanceProfile\\'].OutputValue --output text)",

      "sed -i -e s#INFRANAME#$INFRANAME#g ${local.ocptemplates}/workernode-parameter-${count.index}.json",
      "sed -i -e s#PRIVATESUBNET#${self.triggers.psubnet}#g ${local.ocptemplates}/workernode-parameter-${count.index}.json",
      "sed -i -e s#CERT-AUTHORITIES#$CERTAUTHORITIES#g ${local.ocptemplates}/workernode-parameter-${count.index}.json",
      "sed -i -e s#WORKER-SEC-GROUPID#$WORKERSECGROUPID#g ${local.ocptemplates}/workernode-parameter-${count.index}.json",
      "sed -i -e s#WORKER-INST-PRFL-NAME#$WORKERINSTPRFLNAME#g ${local.ocptemplates}/workernode-parameter-${count.index}.json",

      "aws cloudformation create-stack --stack-name workernode-stack-${count.index} --template-body file://${local.ocptemplates}/workernode-template.yaml --parameters file://${local.ocptemplates}/workernode-parameter-${count.index}.json",
      "sleep 6m",
    ]
  }
  depends_on = [
    aws_instance.bootnode,
    null_resource.file_copy,
    null_resource.create_upi_resources,
  ]
}

resource "null_resource" "vpc_peering" {
  count = var.disconnected-cluster == "yes" ? 1 : 0
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
    sg-id                 = aws_security_group.openshift-public-ssh.id
  }
  connection {
    type        = "ssh"
    host        = self.triggers.bootnode_public_ip
    user        = self.triggers.username
    private_key = file(self.triggers.private-key-file-path)
  }
  provisioner "remote-exec" {
    inline = [
      ######## Creating the vpc peering ########
      "echo '################################'",
      "echo 'Creating the VPC Peering!!!'",
      "echo '################################'",
      "./create-vpc-peering.sh ${var.mirror-vpcid} ${local.vpcid} ${var.mirror-vpccidr} ${var.vpc_cidr} ${var.mirror-region} ${var.region} ${self.triggers.sg-id} ${var.mirror-sgid} ${var.mirror-routetable-id}",
      "sleep 3m",
    ]
  }
  depends_on = [
    aws_instance.bootnode,
    null_resource.file_copy,
    null_resource.create_upi_resources,
    null_resource.create_worker_node,
  ]
}

resource "null_resource" "finish_OCP_installation" {
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
      "python3 get-pip.py --user > /dev/null",
      "export PATH=\"~/.local/bin:$PATH\"",
      "source ~/.bash_profile > /dev/null",
      "pip install awscli --upgrade --user > /dev/null",

      ######## Initializing the bootstrap node ########
      "echo '###############'",
      "echo 'Bootstraping!!!'",
      "echo '###############'",

      "./openshift-install wait-for bootstrap-complete --dir=${local.ocpdir} --log-level=debug",

      ######## Destroying the bootstrap node after initialization ########
      "echo '#####################################################'",
      "echo 'Destroying the BootStrap Node after Initialization!!!'",
      "echo '#####################################################'",

      "aws cloudformation delete-stack --stack-name bootstrap-stack",
      "aws s3 rb s3://${var.cluster-name}-infra --force",
      "sleep 5m",

      ######## Finishing the OpenShift Installation ########
      "echo '#######################################'",
      "echo 'Finishing the OpenShift Installation!!!'",
      "echo '#######################################'",

      "echo 'oc get csr -o go-template={{range .items}}{{if not .status}}{{.metadata.name}}{{\"\\n\"}}{{end}}{{end}}'",
      "CSR=$(oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{\"\\n\"}}{{end}}{{end}}')",
      "echo $CSR",
      "echo $CSR | xargs oc adm certificate approve",
      "sleep 30",

      "./openshift-install --dir=${local.ocpdir} wait-for install-complete --log-level=debug",
      "CSR=$(oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{\"\\n\"}}{{end}}{{end}}')",
      "echo $CSR | xargs oc adm certificate approve",
    ]
  }
  depends_on = [
    aws_instance.bootnode,
    null_resource.file_copy,
    null_resource.create_upi_resources,
    null_resource.create_worker_node,
    null_resource.vpc_peering,
  ]
}

resource "null_resource" "cluster_prereq" {
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
      #Create identity provider.
      "htpasswd -c -B -b /tmp/.htpasswd '${var.openshift-username}' '${var.openshift-password}'",
      "sleep 30",
      "oc create secret generic htpass-secret --from-file=htpasswd=/tmp/.htpasswd -n openshift-config",
      "cat > ${local.ocptemplates}/auth-htpasswd.yaml <<EOL\n${file("../openshift_module/auth-htpasswd.yaml")}\nEOL",
      "oc apply -f ${local.ocptemplates}/auth-htpasswd.yaml",
      "oc adm policy add-cluster-role-to-user cluster-admin '${var.openshift-username}'",

      "cat > ${local.ocptemplates}/cluster-autoscaler.yaml <<EOL\n${data.template_file.clusterautoscaler.rendered}\nEOL",
      "cat > ${local.ocptemplates}/machine-health-check.yaml <<EOL\n${local.machine-healthcheck}\nEOL",
      "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
      "oc create -f ${local.ocptemplates}/cluster-autoscaler.yaml",
      "oc create -f ${local.ocptemplates}/machine-health-check.yaml",

      "oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{\"spec\":{\"defaultRoute\":true,\"replicas\":${lookup(var.image-replica, var.azlist)}}}' -n openshift-image-registry",
    ]
  }
  depends_on = [
    aws_instance.bootnode,
    null_resource.file_copy,
    null_resource.create_upi_resources,
    null_resource.create_worker_node,
    null_resource.vpc_peering,
    null_resource.finish_OCP_installation,
  ]
}


#Install OCS as storage type disconnected config.
resource "null_resource" "install_ocs_disconnected" {
  count = var.storage-type == "ocs" && var.disconnected-cluster == "yes" ? 1 : 0
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
      "cat > ${local.ocptemplates}/redhat-operator-catalogsource.yaml <<EOL\n${data.template_file.redhat-operator.rendered}\nEOL",
      "cat > ${local.ocptemplates}/imageContentSourcePolicy.yaml <<EOL\n${file(var.imageContentSourcePolicy-path)}\nEOL",
      "cat > ${local.ocptemplates}/toolbox.yaml <<EOL\n${file("../ocs_module/toolbox.yaml")}\nEOL",
      "sed -i s/\"namespace: rook-ceph\"/\"namespace: openshift-storage\"/g ${local.ocptemplates}/toolbox.yaml",
      "cat > ${local.ocptemplates}/deploy-with-olm.yaml <<EOL\n${file("../ocs_module/deploy-with-olm.yaml")}\nEOL",
      "cat > ${local.ocptemplates}/ocs-storagecluster.yaml <<EOL\n${file("../ocs_module/ocs-storagecluster.yaml")}\nEOL",
      "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",

      "oc patch OperatorHub cluster --type json -p '[{\"op\": \"add\", \"path\": \"/spec/disableAllDefaultSources\", \"value\": true}]'",
      "oc create -f ${local.ocptemplates}/imageContentSourcePolicy.yaml",
      "echo 'Sleeping for 10mins while MachineConfigs apply and the cluster restarts' ",
      "sleep 12m",
      "oc apply -f ${local.ocptemplates}/redhat-operator-catalogsource.yaml",
      "sleep 3m",

      "./ocs-prereq.sh",
      "oc create -f ${local.ocptemplates}/deploy-with-olm.yaml",
      "sleep 5m",
      "oc apply -f ${local.ocptemplates}/ocs-storagecluster.yaml",
      "sleep 10m",
      "oc apply -f ${local.ocptemplates}/toolbox.yaml",
      "sleep 1m",
      "./delete-noobaa-buckets.sh 2> /dev/null",
    ]
  }
  depends_on = [
    aws_instance.bootnode,
    null_resource.file_copy,
    null_resource.create_upi_resources,
    null_resource.create_worker_node,
    null_resource.vpc_peering,
    null_resource.finish_OCP_installation,
    null_resource.cluster_prereq,
  ]
}

#Install OCS as storage type.
resource "null_resource" "install_ocs" {
  count = var.storage-type == "ocs" && var.disconnected-cluster == "no" ? 1 : 0
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
      "cat > ${local.ocptemplates}/toolbox.yaml <<EOL\n${file("../ocs_module/toolbox.yaml")}\nEOL",
      "sed -i s/\"namespace: rook-ceph\"/\"namespace: openshift-storage\"/g ${local.ocptemplates}/toolbox.yaml",
      "cat > ${local.ocptemplates}/deploy-with-olm.yaml <<EOL\n${file("../ocs_module/deploy-with-olm.yaml")}\nEOL",
      "cat > ${local.ocptemplates}/ocs-storagecluster.yaml <<EOL\n${file("../ocs_module/ocs-storagecluster.yaml")}\nEOL",
      "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",

      "./ocs-prereq.sh",
      "oc create -f ${local.ocptemplates}/deploy-with-olm.yaml",
      "sleep 5m",
      "oc apply -f ${local.ocptemplates}/ocs-storagecluster.yaml",
      "sleep 10m",
      "oc apply -f ${local.ocptemplates}/toolbox.yaml",
      "sleep 1m",
      "./delete-noobaa-buckets.sh 2> /dev/null",
    ]
  }
  depends_on = [
    aws_instance.bootnode,
    null_resource.file_copy,
    null_resource.create_upi_resources,
    null_resource.create_worker_node,
    null_resource.vpc_peering,
    null_resource.finish_OCP_installation,
    null_resource.cluster_prereq,
  ]
}


#Install Portoworx as storage type disconnected config.
resource "null_resource" "install_portworx_disconnected" {
  count = var.storage-type == "portworx" && var.disconnected-cluster == "yes" ? 1 : 0
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
      "cat > ${local.ocptemplates}/px-operator-disconnected.yaml <<EOL\n${file("../portworx_module/px-operator-disconnected.yaml")}\nEOL",
      "cat > /home/${var.admin-username}/policy.json <<EOL\n${file("../portworx_module/policy.json")}\nEOL",
      "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",
      "./create-portworx-disconnected.sh \"${var.portworx-spec-url}\" ${var.redhat-username} ${var.redhat-password}",
      "sleep 6m",
      "./px-storageclasses.sh",
    ]
  }
  depends_on = [
    aws_instance.bootnode,
    null_resource.file_copy,
    null_resource.create_upi_resources,
    null_resource.create_worker_node,
    null_resource.vpc_peering,
    null_resource.finish_OCP_installation,
    null_resource.cluster_prereq,
  ]
}

#Install Portoworx as storage type.
resource "null_resource" "install_portworx" {
  count = var.storage-type == "portworx" && var.disconnected-cluster == "no" ? 1 : 0
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
      "cat > ${local.ocptemplates}/px-install.yaml <<EOL\n${file("../portworx_module/px-install.yaml")}\nEOL",
      "cat > /home/${var.admin-username}/policy.json <<EOL\n${file("../portworx_module/policy.json")}\nEOL",
      "export KUBECONFIG=/home/${var.admin-username}/${local.ocpdir}/auth/kubeconfig",

      "./portworx-prereq.sh",
      "./portworx-install.sh",
      "oc create -f ${local.ocptemplates}/px-install.yaml",
      "sleep 3m",
      "oc apply -f \"${var.portworx-spec-url}\"",
      "sleep 6m",
      "./px-storageclasses.sh",
    ]
  }
  depends_on = [
    aws_instance.bootnode,
    null_resource.file_copy,
    null_resource.create_upi_resources,
    null_resource.create_worker_node,
    null_resource.vpc_peering,
    null_resource.finish_OCP_installation,
    null_resource.cluster_prereq,
  ]
}


#Install EFS as storage type.
resource "null_resource" "install_efs" {
  count = var.storage-type == "efs" ? 1 : 0
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
      "python3 get-pip.py --user > /dev/null",
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

      "./create-efs.sh ${var.region} ${var.vpc_cidr} ${local.vpcid} ${var.efs-performance-mode} ${var.private-subnet-tag-name} ${var.private-subnet-tag-value}",
      "sleep 3m",
      "FILESYSTEMID=$(aws efs describe-file-systems --query FileSystems[?Name==\\'cp4d-openshift-efs\\'].FileSystemId --output text)",
      "DNSNAME=$FILESYSTEMID.efs.${var.region}.amazonaws.com",

      "sed -i s/FILESYSTEMID/$FILESYSTEMID/g ${local.ocptemplates}/efs-configmap.yaml",
      "sed -i s/DNSNAME/$DNSNAME/g ${local.ocptemplates}/efs-configmap.yaml",
      "sed -i s/DNSNAME/$DNSNAME/g ${local.ocptemplates}/efs-provisioner.yaml",

      "oc create -f ${local.ocptemplates}/efs-configmap.yaml",
      "oc create serviceaccount efs-provisioner",
      "oc create -f ${local.ocptemplates}/efs-roles.yaml",
      "oc create -f ${local.ocptemplates}/efs-storageclass.yaml",
      "oc create -f ${local.ocptemplates}/efs-provisioner.yaml",
      "sleep 1m",
      "oc create -f ${local.ocptemplates}/efs-namespace.yaml",
    ]
  }
  depends_on = [
    aws_instance.bootnode,
    null_resource.file_copy,
    null_resource.create_upi_resources,
    null_resource.create_worker_node,
    null_resource.vpc_peering,
    null_resource.finish_OCP_installation,
    null_resource.cluster_prereq,
  ]
}
