resource "aws_security_group" "efs" {
  name        = var.efs_name
  description = "EFS security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.efs_name
  }
}

resource "aws_efs_file_system" "efs" {
  creation_token = var.efs_name
  performance_mode = var.performance_mode
  encrypted = var.encrypted
  throughput_mode = "bursting"
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = {
    Name = var.efs_name
  }
}

resource "aws_efs_mount_target" "efs" {
  count = length(var.subnets)
  file_system_id = aws_efs_file_system.efs.id
  security_groups = [ aws_security_group.efs.id ]
  subnet_id = var.subnets[count.index]
}

locals {
  dns_name = "${aws_efs_file_system.efs.id}.efs.${var.region}.amazonaws.com"
}

resource "local_file" "efs_namespace_yaml" {
  content = data.template_file.efs_namespace.rendered
  filename = "${var.installer_workspace}/efs_namespace.yaml"
}

resource "local_file" "efs_configmap_yaml" {
  content = data.template_file.efs_configmap.rendered
  filename = "${var.installer_workspace}/efs_configmap.yaml"
}

resource "local_file" "service_account_yaml" {
  content = data.template_file.service_account.rendered
  filename = "${var.installer_workspace}/service_account.yaml"
}

resource "local_file" "efs_roles_yaml" {
  content = data.template_file.efs_roles.rendered
  filename = "${var.installer_workspace}/efs_roles.yaml"
}

resource "local_file" "efs_provisioner_yaml" {
  content = data.template_file.efs_provisioner.rendered
  filename = "${var.installer_workspace}/efs_provisioner.yaml"
}

resource "local_file" "efs_storageclass_yaml" {
  content = data.template_file.efs_storageclass.rendered
  filename = "${var.installer_workspace}/efs_storageclass.yaml"
}

resource "null_resource" "install_efs" {
  triggers = {
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    installer_workspace = var.installer_workspace
  }
  provisioner "local-exec" {
    when = create
    command = <<EOF
echo "Logging in.."
oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server=${self.triggers.openshift_api} --token='${self.triggers.openshift_token}'
oc create -f ${self.triggers.installer_workspace}/efs_namespace.yaml
oc create -f ${self.triggers.installer_workspace}/efs_storageclass.yaml
sleep 2
oc create -f ${self.triggers.installer_workspace}/service_account.yaml
sleep 2
oc create -f ${self.triggers.installer_workspace}/efs_configmap.yaml
sleep 2
oc create -f ${self.triggers.installer_workspace}/efs_roles.yaml
sleep 2
oc create -f ${self.triggers.installer_workspace}/efs_provisioner.yaml
echo "Sleeping 1min"
sleep 60
EOF
  }

  depends_on = [
    local_file.efs_configmap_yaml,
    local_file.efs_namespace_yaml,
    local_file.efs_provisioner_yaml,
    local_file.efs_roles_yaml,
    local_file.efs_storageclass_yaml
  ]
}