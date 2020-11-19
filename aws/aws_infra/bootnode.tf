//  Create an SSH keypair
resource "aws_key_pair" "keypair" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)

  depends_on = [
      aws_security_group.openshift-public-ssh,
  ]
}

resource "aws_instance" "bootnode" {
  ami                  = data.aws_ami.rhel.id
  instance_type        = var.bootnode-instance-type
  subnet_id            = coalesce(var.subnetid-public1,join("",aws_subnet.public1[*].id))

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

  key_name = aws_key_pair.keypair.key_name

  tags = {
    Name = "bootnode"
  }
}

resource "null_resource" "file_copy" {
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
    source      = "../scripts/efs-backup.sh"
    destination = "/home/${var.admin-username}/efs-backup.sh"
  }
  provisioner "file" {
    source      = "../scripts/delete-efs-backup.sh"
    destination = "/home/${var.admin-username}/delete-efs-backup.sh"
  }
  provisioner "file" {
    source      = "../scripts/update-elb-timeout.sh"
    destination = "/home/${var.admin-username}/update-elb-timeout.sh"
  }
  provisioner "file" {
    source      = "../scripts/delete-elb-outofservice.sh"
    destination = "/home/${var.admin-username}/delete-elb-outofservice.sh"
  }
  provisioner "file" {
    source      = "../cpd_module/install-cpd-operator.sh"
    destination = "/home/${var.admin-username}/install-cpd-operator.sh"
  }
  provisioner "file" {
    source      = "../cpd_module/wait-for-service-install.sh"
    destination = "/home/${var.admin-username}/wait-for-service-install.sh"
  }
  provisioner "file" {
    source      = "../portworx_module/px-storageclasses.sh"
    destination = "/home/${var.admin-username}/px-storageclasses.sh"
  }


  depends_on = [
    aws_instance.bootnode,
  ]
}

resource "null_resource" "destroy_cluster" {
    triggers = {
        bootnode_public_ip      = aws_instance.bootnode.public_ip
        username                = var.admin-username
        private-key-file-path   = var.ssh-private-key-file-path
        directory               = local.ocpdir
    }
    # Destroy OCP Cluster before destroying the bootnode
    provisioner "remote-exec" {
      connection {
          type        = "ssh"
          host        = self.triggers.bootnode_public_ip
          user        = self.triggers.username
          private_key = file(self.triggers.private-key-file-path)
        }
        when = destroy
        inline =[
            "/home/${self.triggers.username}/delete-efs.sh 2> /dev/null",
            "/home/${self.triggers.username}/px-volume-permission.sh 2> /dev/null",
            "/home/${self.triggers.username}/delete-policy.sh 2> /dev/null",
            "/home/${self.triggers.username}/openshift-install destroy cluster --dir=${self.triggers.directory} --log-level=debug",
           ]
        }
        depends_on = [
          aws_instance.bootnode,
      ]
}
