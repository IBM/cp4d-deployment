provider "aws" {
  version    = "~> 2.0"
  region     = var.region
  access_key = var.access_key_id
  secret_key = var.secret_access_key
}

resource "null_resource" "variables-validation" {
  provisioner "local-exec" {
    command = "if [ -z ${var.access_key_id} ] ; then echo \"access_key_id value missing in variables.tf file\" ; exit 1 ; fi"
  }
  provisioner "local-exec" {
    command = "if [ -z ${var.secret_access_key} ] ; then echo \"secret_access_key value missing in variables.tf file\" ; exit 1 ; fi"
  }
  provisioner "local-exec" {
    command = "if [ -z ${var.pull-secret-file-path} ] ; then echo \"pull-secret-file-path value missing in variables.tf file\" ; exit 1 ; fi"
  }
  provisioner "local-exec" {
    command = "if [ -z ${var.public_key_path} ] ; then echo \"public_key_path value missing in variables.tf file\" ; exit 1 ; fi"
  }
  provisioner "local-exec" {
    command = "if [ -z ${var.ssh-public-key} ] ; then echo \"ssh-public-key value missing in variables.tf file\" ; exit 1 ; fi"
  }
  provisioner "local-exec" {
    command = "if [ -z ${var.ssh-private-key-file-path} ] ; then echo \"ssh-private-key-file-path value missing in variables.tf file\" ; exit 1 ; fi"
  }
  provisioner "local-exec" {
    command = "if [ -z ${var.dnszone} ] ; then echo \"dnszone value missing in variables.tf file\" ; exit 1 ; fi"
  }
  provisioner "local-exec" {
    command = "if [ -z ${var.hosted-zoneid} ] ; then echo \"hosted-zoneid value missing in variables.tf file\" ; exit 1 ; fi"
  }
  provisioner "local-exec" {
    command = "if [ -z ${var.api-key} ] ; then echo \"api-key value missing in variables.tf file\" ; exit 1 ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.storage-type} = 'portworx' ]; then if [ -z ${var.portworx-spec-url} ] ; then echo \"portworx-spec-url value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.redhat-username} ] ; then echo \"redhat-username value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.redhat-password} ] ; then echo \"redhat-password value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.certificate-file-path} ] ; then echo \"certificate-file-path value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.local-registry-repository} ] ; then echo \"local-registry-repository value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.local-registry} ] ; then echo \"local-registry value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.local-registry-username} ] ; then echo \"local-registry-username value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.local-registry-pwd} ] ; then echo \"local-registry-pwd value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.mirror-region} ] ; then echo \"mirror-region value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.mirror-vpcid} ] ; then echo \"mirror-vpcid value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.mirror-vpccidr} ] ; then echo \"mirror-vpccidr value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.mirror-sgid} ] ; then echo \"mirror-sgid value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.mirror-routetable-id} ] ; then echo \"mirror-routetable-id value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
  provisioner "local-exec" {
    command = "if [ ${var.disconnected-cluster} = 'yes' ]; then if [ -z ${var.imageContentSourcePolicy-path} ] ; then echo \"imageContentSourcePolicy-path value missing in variables.tf file\" ; exit 1 ; fi ; fi"
  }
}

resource "null_resource" "permission-resource-validation" {
  provisioner "local-exec" {
    command = "mkdir -p $HOME/.aws"
  }
  provisioner "local-exec" {
    command = "cat > $HOME/.aws/credentials <<EOL\n${data.template_file.awscreds.rendered}\nEOL"
  }
  provisioner "local-exec" {
    command = "cat > $HOME/.aws/config <<EOL\n${data.template_file.awsregion.rendered}\nEOL"
  }
  provisioner "local-exec" {
    command = "chmod +x ./*.sh ./*.py"
  }
  provisioner "local-exec" {
    command = "./aws_permission_validation.sh ; if [ $? -ne 0 ] ; then echo \"Permission Verification Failed\" ; exit 1 ; fi"
  }
  provisioner "local-exec" {
    command = "echo file | ./aws_resource_quota_validation.sh ; if [ $? -ne 0 ] ; then echo \"Resource Quota Validation Failed\" ; exit 1 ; fi"
  }

  depends_on = [
    null_resource.variables-validation,
  ]
}

locals {
  avzone = data.aws_availability_zones.azs.names
}

resource "null_resource" "vpc-subnet" {
  count = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  provisioner "local-exec" {
    command = "cat > ./vpc-parameter.json <<EOL\n${data.template_file.vpc-subnet.rendered}\nEOL"
  }
  provisioner "local-exec" {
    command = "cat > ./vpc-template.yaml <<EOL\n${file("../infra-templates/vpc-template.yaml")}\nEOL"
  }
  provisioner "local-exec" {
    command = "aws cloudformation create-stack --stack-name vpc-stack --template-body file://vpc-template.yaml --parameters file://vpc-parameter.json"
  }
  provisioner "local-exec" {
    command = "sleep 240"
  }

  depends_on = [
    null_resource.permission-resource-validation,
  ]
}

resource "null_resource" "describe-stacks" {
  count = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  provisioner "local-exec" {
    command = <<EOT
        aws cloudformation describe-stacks --stack-name vpc-stack --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" --output text > ./vpcid;
        aws cloudformation describe-stacks --stack-name vpc-stack --query "Stacks[0].Outputs[?OutputKey=='PublicSubnetIds'].OutputValue" --output text > ./publicsubnet;
        aws cloudformation describe-stacks --stack-name vpc-stack --query "Stacks[0].Outputs[?OutputKey=='PrivateSubnetIds'].OutputValue" --output text > ./privatesubnet;
      EOT
  }
  depends_on = [
    null_resource.vpc-subnet,
  ]
}

resource "null_resource" "empty-resource" {
  count = var.new-or-existing-vpc-subnet == "exist" ? 1 : 0
  provisioner "local-exec" {
    command = <<EOT
        echo "" > ./vpcid;
        echo "" > ./publicsubnet;
        echo "" > ./privatesubnet;
      EOT
  }
}
