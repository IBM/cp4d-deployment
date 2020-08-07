provider "aws" {
        version = "~> 2.0"
        region  = var.region
        access_key = var.access_key_id
        secret_key = var.secret_access_key
}
resource "aws_vpc" "cpdvpc" {
  count                = var.new-or-existing == "new" ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  instance_tenancy     = var.tenancy

  tags = {
    Name = "ocp-tf-vpc"
  }
}

locals{
  zonelist ={
    single_zone      = [data.aws_availability_zones.azs.names[0],data.aws_availability_zones.azs.names[0],data.aws_availability_zones.azs.names[0]]
    multi_zone       = data.aws_availability_zones.azs.names
  }

  avzone             = "${local.zonelist[var.azlist]}"
}

########################
# Public
resource "aws_internet_gateway" "bootnode" {
  vpc_id                  = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
}
resource "aws_subnet" "public1" {
  vpc_id                  = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block              = var.subnet-cidr1
  availability_zone       = local.avzone[0]
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.bootnode]

  tags = {
    "Name": join("-",[var.cluster-name,"public-vpc",local.avzone[0]])
  }
}
resource "aws_subnet" "public2" {
  vpc_id                  = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block              = var.subnet-cidr2
  availability_zone       = local.avzone[1]
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.bootnode]

  tags = {
    "Name": join("-",[var.cluster-name,"public-vpc",local.avzone[1]])
  }
}
resource "aws_subnet" "public3" {
  vpc_id                  = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block              = var.subnet-cidr3
  availability_zone       = local.avzone[2]
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.bootnode]

  tags = {
    "Name": join("-",[var.cluster-name,"public-vpc",local.avzone[2]])
  }
}
resource "aws_route_table" "public" {
  vpc_id = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bootnode.id
  }
}
resource "aws_route_table_association" "route1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "route2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "route3" {
  subnet_id      = aws_subnet.public3.id
  route_table_id = aws_route_table.public.id
}
########################
# Private
resource "aws_eip" "eip1" {
  vpc                       = true
  associate_with_private_ip = "10.0.5.226"
}
resource "aws_eip" "eip2" {
  vpc                       = true
  associate_with_private_ip = "10.0.16.45"
}
resource "aws_eip" "eip3" {
  vpc                       = true
  associate_with_private_ip = "10.0.44.224"
}
resource "aws_nat_gateway" "nat1" {
  allocation_id = aws_eip.eip1.id
  subnet_id     = aws_subnet.public1.id
}
resource "aws_nat_gateway" "nat2" {
  allocation_id = aws_eip.eip2.id
  subnet_id     = aws_subnet.public2.id
}
resource "aws_nat_gateway" "nat3" {
  allocation_id = aws_eip.eip3.id
  subnet_id     = aws_subnet.public3.id
}
resource "aws_subnet" "private1" {
  vpc_id                  = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block              = var.subnet-cidr4
  availability_zone       = local.avzone[0]
  depends_on              = [aws_nat_gateway.nat1]

  tags = {
    "Name": join("-",[var.cluster-name,"private-vpc",local.avzone[0]])
  }
}
resource "aws_subnet" "private2" {
  vpc_id                  = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block              = var.subnet-cidr5
  availability_zone       = local.avzone[1]
  depends_on              = [aws_nat_gateway.nat2]

  tags = {
    "Name": join("-",[var.cluster-name,"private-vpc",local.avzone[1]])
  }
}
resource "aws_subnet" "private3" {
  vpc_id                  = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
  cidr_block              = var.subnet-cidr6
  availability_zone       = local.avzone[2]
  depends_on              = [aws_nat_gateway.nat3]

  tags = {
    "Name": join("-",[var.cluster-name,"private-vpc",local.avzone[2]])
  }
}
resource "aws_route_table" "private1" {
  vpc_id = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat1.id
  }
}
resource "aws_route_table" "private2" {
  vpc_id = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat2.id
  }
}
resource "aws_route_table" "private3" {
  vpc_id = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat3.id
  }
}
resource "aws_route_table_association" "privateroute1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private1.id
}
resource "aws_route_table_association" "privateroute2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private2.id
}
resource "aws_route_table_association" "privateroute3" {
  subnet_id      = aws_subnet.private3.id
  route_table_id = aws_route_table.private3.id
}
/*
This security group allows intra-node communication on all ports with all
protocols.
*/
resource "aws_security_group" "openshift-vpc" {
  name        = "openshift-vpc"
  description = "Default security group that allows all instances in the VPC to talk to each other over any port and protocol."
  vpc_id      = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
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
  vpc_id      = coalesce(var.vpc-existing, join("",aws_vpc.cpdvpc[*].id))
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
