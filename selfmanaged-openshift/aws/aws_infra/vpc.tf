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
        command = "if [ -z ${var.api-key} ] ; then echo \"api-key value missing in variables.tf file\" ; exit 1 ; fi"
    }
    provisioner "local-exec" {
        command = "if [ ${var.storage-type} = 'portworx' ]; then if [ -z ${var.portworx-spec-url} ] ; then echo \"portworx-spec-url value missing in variables.tf file\" ; exit 1 ; fi ; fi"
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

resource "aws_vpc" "cpdvpc" {
  count                = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  instance_tenancy     = var.tenancy

  tags = {
    Name = "ocp-tf-vpc"
  }

  depends_on = [
      null_resource.permission-resource-validation,
  ]
}

locals{
  avzone   = data.aws_availability_zones.azs.names
  vpcid    = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
}

########################
# Public
resource "aws_internet_gateway" "bootnode" {
  count     = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  vpc_id    = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
}
resource "aws_subnet" "public1" {
  count                   = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  vpc_id                  = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block              = var.public-subnet-cidr1
  availability_zone       = coalesce(var.availability-zone1, local.avzone[0])
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.bootnode]

  tags = {
    "Name": join("-",[var.cluster-name,"cpd-public-subnet",coalesce(var.availability-zone1, local.avzone[0])])
  }
}
resource "aws_subnet" "public2" {
  count                   = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc_id                  = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block              = var.public-subnet-cidr2
  availability_zone       = coalesce(var.availability-zone2, local.avzone[1])
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.bootnode]

  tags = {
    "Name": join("-",[var.cluster-name,"cpd-public-subnet",coalesce(var.availability-zone2, local.avzone[1])])
  }
}
resource "aws_subnet" "public3" {
  count                   = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc_id                  = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block              = var.public-subnet-cidr3
  availability_zone       = coalesce(var.availability-zone3, local.avzone[2])
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.bootnode]

  tags = {
    "Name": join("-",[var.cluster-name,"cpd-public-subnet",coalesce(var.availability-zone3, local.avzone[2])])
  }
}
resource "aws_route_table" "public" {
  count  = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  vpc_id = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bootnode[0].id
  }
}
resource "aws_route_table_association" "route1" {
  count          = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  subnet_id      = aws_subnet.public1[0].id
  route_table_id = aws_route_table.public[0].id
}
resource "aws_route_table_association" "route2" {
  count          = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  subnet_id      = aws_subnet.public2[0].id
  route_table_id = aws_route_table.public[0].id
}
resource "aws_route_table_association" "route3" {
  count          = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  subnet_id      = aws_subnet.public3[0].id
  route_table_id = aws_route_table.public[0].id
}
########################
# Private
resource "aws_eip" "eip1" {
  count   = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  vpc     = true
  associate_with_private_ip = "10.0.5.226"
  
  depends_on = [
      aws_vpc.cpdvpc,
  ]
}
resource "aws_eip" "eip2" {
  count   = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc     = true
  associate_with_private_ip = "10.0.16.45"

  depends_on = [
      aws_vpc.cpdvpc,
  ]
}
resource "aws_eip" "eip3" {
  count   = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc     = true
  associate_with_private_ip = "10.0.44.224"

  depends_on = [
      aws_vpc.cpdvpc,
  ]
}
resource "aws_nat_gateway" "nat1" {
  count         = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  allocation_id = aws_eip.eip1[0].id
  subnet_id     = aws_subnet.public1[0].id
}
resource "aws_nat_gateway" "nat2" {
  count         = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  allocation_id = aws_eip.eip2[0].id
  subnet_id     = aws_subnet.public2[0].id
}
resource "aws_nat_gateway" "nat3" {
  count         = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  allocation_id = aws_eip.eip3[0].id
  subnet_id     = aws_subnet.public3[0].id
}
resource "aws_subnet" "private1" {
  count                = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  vpc_id               = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block           = var.private-subnet-cidr1
  availability_zone    = coalesce(var.availability-zone1, local.avzone[0])
  depends_on           = [aws_nat_gateway.nat1]

  tags = {
    "Name": join("-",[var.cluster-name,"cpd-private-subnet",coalesce(var.availability-zone1, local.avzone[0])])
  }
}
resource "aws_subnet" "private2" {
  count                = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc_id               = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block           = var.private-subnet-cidr2
  availability_zone    = coalesce(var.availability-zone2, local.avzone[1])
  depends_on           = [aws_nat_gateway.nat2]

  tags = {
    "Name": join("-",[var.cluster-name,"cpd-private-subnet",coalesce(var.availability-zone2, local.avzone[1])])
  }
}
resource "aws_subnet" "private3" {
  count                = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc_id               = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block           = var.private-subnet-cidr3
  availability_zone    = coalesce(var.availability-zone3, local.avzone[2])
  depends_on           = [aws_nat_gateway.nat3]

  tags = {
    "Name": join("-",[var.cluster-name,"cpd-private-subnet",coalesce(var.availability-zone3, local.avzone[2])])
  }
}
resource "aws_route_table" "private1" {
  count  = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  vpc_id = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat1[0].id
  }
}
resource "aws_route_table" "private2" {
  count  = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc_id = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat2[0].id
  }
}
resource "aws_route_table" "private3" {
  count  = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc_id = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat3[0].id
  }
}
resource "aws_route_table_association" "privateroute1" {
  count          = var.new-or-existing-vpc-subnet == "new" ? 1 : 0
  subnet_id      = aws_subnet.private1[0].id
  route_table_id = aws_route_table.private1[0].id
}
resource "aws_route_table_association" "privateroute2" {
  count          = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  subnet_id      = aws_subnet.private2[0].id
  route_table_id = aws_route_table.private2[0].id
}
resource "aws_route_table_association" "privateroute3" {
  count          = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  subnet_id      = aws_subnet.private3[0].id
  route_table_id = aws_route_table.private3[0].id
}
/*
This security group allows intra-node communication on all ports with all
protocols.
*/
resource "aws_security_group" "openshift-vpc" {
  name        = "openshift-vpc"
  description = "Default security group that allows all instances in the VPC to talk to each other over any port and protocol."
  vpc_id      = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
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
}
//  Security group which allows SSH access to a host. Used for the bastion.
resource "aws_security_group" "openshift-public-ssh" {
  name        = "openshift-public-ssh"
  description = "Security group that allows public ingress over SSH."
  vpc_id      = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
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
}
