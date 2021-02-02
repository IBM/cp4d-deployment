locals {
  vpc-subnets = {
    public-subnets  = chomp(data.local_file.publicsubnet.content)
    private-subnets = chomp(data.local_file.privatesubnet.content)
  }

  bootnodesubnet = element(split(",", chomp(data.local_file.publicsubnet.content)), 0)
  vpcid          = coalesce(var.vpcid-existing, chomp(data.local_file.vpcid.content))
}

data "local_file" "vpcid" {
  filename = "./vpcid"

  depends_on = [
    null_resource.describe-stacks,
    null_resource.empty-resource,
  ]
}
data "local_file" "publicsubnet" {
  filename = "./publicsubnet"

  depends_on = [
    null_resource.describe-stacks,
    null_resource.empty-resource,
  ]
}
data "local_file" "privatesubnet" {
  filename = "./privatesubnet"

  depends_on = [
    null_resource.describe-stacks,
    null_resource.empty-resource,
  ]
}

/*
This security group allows intra-node communication on all ports with all
protocols.
*/
resource "aws_security_group" "openshift-vpc" {
  name        = "openshift-vpc"
  description = "Default security group that allows all instances in the VPC to talk to each other over any port and protocol."
  vpc_id      = local.vpcid
  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }
  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }
  depends_on = [
    null_resource.describe-stacks,
    null_resource.empty-resource,
  ]
}
//  Security group which allows SSH access to a host. Used for the bastion.
resource "aws_security_group" "openshift-public-ssh" {
  name        = "openshift-public-ssh"
  description = "Security group that allows public ingress over SSH."
  vpc_id      = local.vpcid
  //  ingress SSH
  ingress {
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  //  egress SSH
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [
    null_resource.describe-stacks,
    null_resource.empty-resource,
  ]
}

//  Create an SSH keypair
resource "aws_key_pair" "keypair" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)

  depends_on = [
    aws_security_group.openshift-public-ssh,
  ]
}

resource "aws_instance" "bootnode" {
  ami           = data.aws_ami.rhel.id
  instance_type = var.bootnode-instance-type
  subnet_id     = coalesce(var.subnetid-public1, local.bootnodesubnet)

  vpc_security_group_ids = [
    aws_security_group.openshift-vpc.id,
    aws_security_group.openshift-public-ssh.id
  ]

  root_block_device {
    volume_size = 500
    volume_type = "gp2"
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = 80
    volume_type = "gp2"
  }

  key_name                    = aws_key_pair.keypair.key_name
  associate_public_ip_address = true

  tags = {
    Name = "bootnode"
  }

  depends_on = [
    null_resource.describe-stacks,
    null_resource.empty-resource,
    aws_security_group.openshift-vpc,
    aws_security_group.openshift-public-ssh,
    aws_key_pair.keypair,
  ]
}

resource "null_resource" "file_copy" {
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
  provisioner "file" {
    source      = "../scripts/autoscaler-prereq.sh"
    destination = "/home/${var.admin-username}/autoscaler-prereq.sh"
  }
  provisioner "file" {
    source      = "../scripts/delete-policy.sh"
    destination = "/home/${var.admin-username}/delete-policy.sh"
  }
  provisioner "file" {
    source      = "../scripts/px-volume-permission.sh"
    destination = "/home/${var.admin-username}/px-volume-permission.sh"
  }
  provisioner "file" {
    source      = "../scripts/portworx-prereq.sh"
    destination = "/home/${var.admin-username}/portworx-prereq.sh"
  }
  provisioner "file" {
    source      = "../scripts/portworx-install.sh"
    destination = "/home/${var.admin-username}/portworx-install.sh"
  }
  provisioner "file" {
    source      = "../scripts/ocs-prereq.sh"
    destination = "/home/${var.admin-username}/ocs-prereq.sh"
  }
  provisioner "file" {
    source      = "../scripts/delete-noobaa-buckets.sh"
    destination = "/home/${var.admin-username}/delete-noobaa-buckets.sh"
  }
  provisioner "file" {
    source      = "../scripts/create-efs.sh"
    destination = "/home/${var.admin-username}/create-efs.sh"
  }
  provisioner "file" {
    source      = "../scripts/delete-efs.sh"
    destination = "/home/${var.admin-username}/delete-efs.sh"
  }
  provisioner "file" {
    source      = "../scripts/update-elb-timeout.sh"
    destination = "/home/${var.admin-username}/update-elb-timeout.sh"
  }
  provisioner "file" {
    source      = "../scripts/delete-workernode-stack.sh"
    destination = "/home/${var.admin-username}/delete-workernode-stack.sh"
  }
  provisioner "file" {
    source      = "../scripts/delete-classic-lb.sh"
    destination = "/home/${var.admin-username}/delete-classic-lb.sh"
  }
  provisioner "file" {
    source      = "../scripts/delete-route53-record.sh"
    destination = "/home/${var.admin-username}/delete-route53-record.sh"
  }
  provisioner "file" {
    source      = "../scripts/create-vpc-peering.sh"
    destination = "/home/${var.admin-username}/create-vpc-peering.sh"
  }
  provisioner "file" {
    source      = "../scripts/delete-vpc-peering.sh"
    destination = "/home/${var.admin-username}/delete-vpc-peering.sh"
  }
  provisioner "file" {
    source      = "../cpd_module/install-cpd-operator.sh"
    destination = "/home/${var.admin-username}/install-cpd-operator.sh"
  }
  provisioner "file" {
    source      = "../cpd_module/install-cpd-operator-airgap.sh"
    destination = "/home/${var.admin-username}/install-cpd-operator-airgap.sh"
  }
  provisioner "file" {
    source      = "../cpd_module/wait-for-service-install.sh"
    destination = "/home/${var.admin-username}/wait-for-service-install.sh"
  }
  provisioner "file" {
    source      = "../scripts/delete-volumes.sh"
    destination = "/home/${var.admin-username}/delete-volumes.sh"
  }
  provisioner "file" {
    source      = "../portworx_module/px-storageclasses.sh"
    destination = "/home/${var.admin-username}/px-storageclasses.sh"
  }
  provisioner "file" {
    source      = "./vpcid"
    destination = "/home/${var.admin-username}/vpcid"
  }
  provisioner "file" {
    source      = "./publicsubnet"
    destination = "/home/${var.admin-username}/publicsubnet"
  }
  provisioner "file" {
    source      = "./privatesubnet"
    destination = "/home/${var.admin-username}/privatesubnet"
  }
  provisioner "file" {
    source      = "../infra-templates/nlb-template.yaml"
    destination = "/home/${var.admin-username}/nlb-template.yaml"
  }
  provisioner "file" {
    source      = "../infra-templates/sg-role-template.yaml"
    destination = "/home/${var.admin-username}/sg-role-template.yaml"
  }
  provisioner "file" {
    source      = "../infra-templates/bootstrap-template.yaml"
    destination = "/home/${var.admin-username}/bootstrap-template.yaml"
  }
  provisioner "file" {
    source      = "../infra-templates/controlplane-template.yaml"
    destination = "/home/${var.admin-username}/controlplane-template.yaml"
  }
  provisioner "file" {
    source      = "../infra-templates/workernode-template.yaml"
    destination = "/home/${var.admin-username}/workernode-template.yaml"
  }
  provisioner "file" {
    source      = "../portworx_module/versions"
    destination = "/home/${var.admin-username}/versions"
  }
  provisioner "file" {
    source      = "../portworx_module/px-ag-install.sh"
    destination = "/home/${var.admin-username}/px-ag-install.sh"
  }
  provisioner "file" {
    source      = "../scripts/create-portworx-disconnected.sh"
    destination = "/home/${var.admin-username}/create-portworx-disconnected.sh"
  }

  depends_on = [
    aws_instance.bootnode,
  ]
}

resource "null_resource" "destroy_cluster" {
  triggers = {
    bootnode_public_ip    = aws_instance.bootnode.public_ip
    username              = var.admin-username
    private-key-file-path = var.ssh-private-key-file-path
    directory             = local.ocpdir
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = self.triggers.bootnode_public_ip
      user        = self.triggers.username
      private_key = file(self.triggers.private-key-file-path)
    }
    when = destroy
    inline = [
      "python3 get-pip.py --user > /dev/null",
      "export PATH=\"~/.local/bin:$PATH\"",
      "source ~/.bash_profile > /dev/null",
      "pip install awscli --upgrade --user > /dev/null",
      "/home/${self.triggers.username}/delete-efs.sh 2> /dev/null",
      "/home/${self.triggers.username}/px-volume-permission.sh 2> /dev/null",
      "/home/${self.triggers.username}/delete-policy.sh 2> /dev/null",
      "/home/${self.triggers.username}/delete-workernode-stack.sh 2> /dev/null",
      "/home/${self.triggers.username}/delete-vpc-peering.sh 2> /dev/null",
      "aws cloudformation delete-stack --stack-name controlplane-stack",
      "echo 'Destroying Control plane and Worker Nodes!!!!'",
      "sleep 400",
      "aws cloudformation delete-stack --stack-name sg-role-stack",
      "echo 'Destroying Security Groups and Roles!!!!'",
      "sleep 1m",
      "/home/${self.triggers.username}/delete-route53-record.sh 2> /dev/null",
      "aws cloudformation delete-stack --stack-name nlb-stack",
      "echo 'Destroying LoadBalancer!!!!'",
      "sleep 4m",
      "/home/${self.triggers.username}/delete-classic-lb.sh 2> /dev/null",
    ]
  }

  depends_on = [
    aws_instance.bootnode,
  ]
}
