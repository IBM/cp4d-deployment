#provider "aws" {
#  region     = var.region
#  access_key = var.aws_access_key_id
#  secret_key = var.aws_secret_access_key
#}

data "aws_vpc" "cpd_vpc" {
  id = var.vpc_id
}
# maxIO or generalPurpose
resource "aws_efs_file_system" "cpd_efs" {
   creation_token = "cpd_efs"
   performance_mode = "generalPurpose"
   throughput_mode = "provisioned"
   provisioned_throughput_in_mibps = "250"
   encrypted = "true"
   #lifecycle_policy {
   #   transition_to_ia = "AFTER_30_DAYS"
   #}
   tags = {
     Name = var.cluster_name
   }
 }

resource "aws_efs_mount_target" "cpd-efs-mt" {
   count = var.az == "multi_zone" ? 3 : 1
   file_system_id  = aws_efs_file_system.cpd_efs.id
   subnet_id = var.subnet_ids[count.index]
   security_groups = [aws_security_group.efs_sg.id]
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

   tags = {
     Name = var.cluster_name
   }
 }

resource "aws_iam_policy" "efs_policy" {
  name        = "aws_efs_policy"
  description = "EFS policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:DescribeAccessPoints",
        "elasticfilesystem:DescribeFileSystems"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:CreateAccessPoint"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "elasticfilesystem:DeleteAccessPoint",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    }
  ]
}
EOF
}

data "aws_iam_roles" "efs_worker_roles" {
  name_regex = "^${var.cluster_name}.*worker-role$"
}

#data "aws_iam_role" "efs_worker_role" {
##  name = "an_example_role_name"
#}

resource "aws_iam_role_policy_attachment" "efs-policy-attach" {
  role       = tolist(data.aws_iam_roles.efs_worker_roles.names)[0]
  policy_arn = aws_iam_policy.efs_policy.arn
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
echo "Creating EFS CSI deployment"
oc  apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.3"
echo "Waiting for 2mins"
sleep 120
echo "switch to latest controller image"
oc patch deploy efs-csi-controller -n kube-system --patch='{"spec":{"template":{"spec":{"containers":[{"name": "efs-plugin", "image":"amazon/aws-efs-csi-driver:master"}]}}}}'
sleep 60
echo "Creating SC"
oc create -f ${self.triggers.installer_workspace}/efs_sc.yaml
oc create -f ${self.triggers.installer_workspace}/efs_sc_wkc.yaml
echo "Creating test pvc"
oc create -f ${self.triggers.installer_workspace}/efs_test_pvc.yaml
sleep 60
oc get pvc efs-csi-claim -n default
EOF
  }
  depends_on = [
    null_resource.login_cluster
  ]
}

resource "local_file" "efs_test_pvc_yaml" {
  content  = data.template_file.efs_test_pvc.rendered
  filename = "${local.installer_workspace}/efs_test_pvc.yaml"
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

resource "local_file" "efs_sc_wkc_yaml" {
  content  = data.template_file.efs_sc_wkc.rendered
  filename = "${local.installer_workspace}/efs_sc_wkc.yaml"
  depends_on = [
    resource.aws_efs_mount_target.cpd-efs-mt
  ]
}

locals {
  installer_workspace = var.installer_workspace
}
