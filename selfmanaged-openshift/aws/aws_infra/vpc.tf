provider "aws" {
        version    = "~> 2.0"
        region     = var.region
        access_key = var.access_key_id
        secret_key = var.secret_access_key
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
  zonelist ={
    single_zone  = [data.aws_availability_zones.azs.names[0],data.aws_availability_zones.azs.names[0],data.aws_availability_zones.azs.names[0]]
    multi_zone   = data.aws_availability_zones.azs.names
  }

  avzone   = "${local.zonelist[var.azlist]}"
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
  availability_zone       = local.avzone[0]
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.bootnode]

  tags = {
    "Name": join("-",[var.cluster-name,"public-vpc",local.avzone[0]])
  }
}
resource "aws_subnet" "public2" {
  count                   = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc_id                  = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block              = var.public-subnet-cidr2
  availability_zone       = local.avzone[1]
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.bootnode]

  tags = {
    "Name": join("-",[var.cluster-name,"public-vpc",local.avzone[1]])
  }
}
resource "aws_subnet" "public3" {
  count                   = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc_id                  = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block              = var.public-subnet-cidr3
  availability_zone       = local.avzone[2]
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.bootnode]

  tags = {
    "Name": join("-",[var.cluster-name,"public-vpc",local.avzone[2]])
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
  availability_zone    = local.avzone[0]
  depends_on           = [aws_nat_gateway.nat1]

  tags = {
    "Name": join("-",[var.cluster-name,"private-vpc",local.avzone[0]])
  }
}
resource "aws_subnet" "private2" {
  count                = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc_id               = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block           = var.private-subnet-cidr2
  availability_zone    = local.avzone[1]
  depends_on           = [aws_nat_gateway.nat2]

  tags = {
    "Name": join("-",[var.cluster-name,"private-vpc",local.avzone[1]])
  }
}
resource "aws_subnet" "private3" {
  count                = var.new-or-existing-vpc-subnet == "new" && var.azlist == "multi_zone" ? 1 : 0
  vpc_id               = coalesce(var.vpcid-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block           = var.private-subnet-cidr3
  availability_zone    = local.avzone[2]
  depends_on           = [aws_nat_gateway.nat3]

  tags = {
    "Name": join("-",[var.cluster-name,"private-vpc",local.avzone[2]])
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
