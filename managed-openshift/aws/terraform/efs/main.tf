provider "aws" {
  region     = var.region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

#data "aws_availability_zones" "available" {}

data "aws_vpc" "cpd_vpc" {
  id = var.vpc_id
}

data "aws_subnet_ids" "cpd_subnets" {
  vpc_id = var.vpc_id
  tags = {
    Name = "*private*"
  }
}

data "aws_subnet" "cpd_subnet" {
  count = "${length(data.aws_subnet_ids.cpd_subnets.ids)}"
  id    = "${tolist(data.aws_subnet_ids.cpd_subnets.ids)[count.index]}"
}

resource "aws_efs_file_system" "cpd_efs" {
   creation_token = "cpd_efs"
   performance_mode = "generalPurpose"
   throughput_mode = "bursting"
   encrypted = "true"
   lifecycle_policy {
      transition_to_ia = "AFTER_30_DAYS"
   }
   tags = {
     Name = var.cluster_name
   }
 }

resource "aws_efs_mount_target" "cpd-efs-mt" {
   count = var.az == "multi_zone" ? 3 : 1
   file_system_id  = aws_efs_file_system.cpd_efs.id
   subnet_id = data.aws_subnet.cpd_subnet[count.index].id
   security_groups = [aws_security_group.efs_sg.id]
  depends_on = [
    data.aws_subnet.cpd_subnet
  ]
 }

resource "aws_security_group" "efs_sg" {
   name = "efs_sg"
   description= "Allos inbound efs traffic from ec2"
   vpc_id = data.aws_vpc.cpd_vpc.id

   ingress {
     cidr_blocks = [data.aws_vpc.cpd_vpc.cidr_block]
     from_port = 2049
     to_port = 2049 
     protocol = "tcp"
   }     
        
   #egress {
   #  cidr_blocks = [data.aws_vpc.cpd_vpc.cidr_block]
   #  from_port = 0
   #  to_port = 0
   #  protocol = "-1"
   #}
   tags = {
     Name = var.cluster_name
   }
 }

resource "null_resource" "login_cluster" {
  triggers = {
    openshift_api       = var.openshift_api
    openshift_username  = var.openshift_username
    openshift_password  = var.openshift_password
    openshift_token     = var.openshift_token
    login_string        = var.login_cmd
  }
  provisioner "local-exec" {
    command = <<EOF
${self.triggers.login_string} || oc login ${self.triggers.openshift_api} -u '${self.triggers.openshift_username}' -p '${self.triggers.openshift_password}' --insecure-skip-tls-verify=true || oc login --server='${self.triggers.openshift_api}' --token='${self.triggers.openshift_token}'
EOF
  }
  depends_on = [
    resource.aws_efs_mount_target.cpd-efs-mt
  ]
}

resource "null_resource" "configure_efs" {
  triggers = {
    installer_workspace = local.installer_workspace
  }
  provisioner "local-exec" {
    command = <<EOF
echo "Creating EFS RBAC"
oc create -f ${self.triggers.installer_workspace}/efs_cm.yaml
echo "Creating efs sa"
oc create serviceaccount efs-provisioner
echo "Creating efs rbac"
oc create -f ${self.triggers.installer_workspace}/efs_rbac.yaml
echo "Creating efs sc"
oc create -f ${self.triggers.installer_workspace}/efs_sc.yaml
echo "Creating efs provisioner"
oc create -f ${self.triggers.installer_workspace}/efs_provisioner.yaml
echo "Sleeping for 2mins"
sleep 120
echo "Creating test pvc"
oc create -f ${self.triggers.installer_workspace}/efs_test_pvc.yaml
sleep 60
oc get pvc efs-claim -n default
EOF
  }
  depends_on = [
    null_resource.login_cluster
  ]
}


resource "local_file" "efs_cm_yaml" {
  content  = data.template_file.efs_cm.rendered
  filename = "${local.installer_workspace}/efs_cm.yaml"
  depends_on = [
    resource.aws_efs_mount_target.cpd-efs-mt
  ]
}

resource "local_file" "efs_provisioner_yaml" {
  content  = data.template_file.efs_provisioner.rendered
  filename = "${local.installer_workspace}/efs_provisioner.yaml"
  depends_on = [
    resource.aws_efs_mount_target.cpd-efs-mt
  ]
}

resource "local_file" "efs_test_pvc_yaml" {
  content  = data.template_file.efs_test_pvc.rendered
  filename = "${local.installer_workspace}/efs_test_pvc.yaml"
  depends_on = [
    resource.aws_efs_mount_target.cpd-efs-mt
  ]
}

resource "local_file" "efs_rbac_yaml" {
  content  = data.template_file.efs_rbac.rendered
  filename = "${local.installer_workspace}/efs_rbac.yaml"
  depends_on = [
    resource.aws_efs_mount_target.cpd-efs-mt
  ]
}

resource "local_file" "efs_sc_yaml" {
  content  = data.template_file.efs_sc.rendered
  filename = "${local.installer_workspace}/efs_sc.yaml"
  depends_on = [
    resource.aws_efs_mount_target.cpd-efs-mt
  ]
}

resource "local_file" "efs_ns_yaml" {
  content  = data.template_file.efs_ns.rendered
  filename = "${local.installer_workspace}/efs_ns.yaml"
  depends_on = [
    resource.aws_efs_mount_target.cpd-efs-mt
  ]
}

locals {
  rootpath            = abspath(path.root)
  installer_workspace = "${local.rootpath}/installer-files"
}
