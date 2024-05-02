terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region_location

  default_tags {
    tags = {
      Environment = "Learning"
      Project     = "LTF"
    }
  }
}

# VPC
resource "aws_vpc" "My-VPC" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "My-VPC"
  }
}

# Subnets
resource "aws_subnet" "Public-Subnet" {
  vpc_id                  = aws_vpc.My-VPC.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${local.My_Region}a"
  tags = {
    Name = "Public-Subnet"
  }
}

resource "aws_subnet" "Private-Subnet" {
  vpc_id                  = aws_vpc.My-VPC.id
  cidr_block              = var.private_subnet_cidr
  map_public_ip_on_launch = false
  availability_zone       = "${local.My_Region}b"
  tags = {
    Name = "Private-Subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "My-IGW" {
  vpc_id = aws_vpc.My-VPC.id
  tags = {
    Name = "My-IGW"
  }
}

# NAT Gateway with Elastic IP Address
resource "aws_eip" "My-NGW-EIP" {
}

resource "aws_nat_gateway" "My-NGW" {
  allocation_id = aws_eip.My-NGW-EIP.id
  subnet_id     = aws_subnet.Public-Subnet.id
  tags = {
    Name = "My-NGW"
  }
}

# Route table for Public Subnets
resource "aws_route_table" "Public-rt" {
  vpc_id = aws_vpc.My-VPC.id
  tags = {
    Name = "Public-rt"
  }
}

resource "aws_route_table_association" "Public-rt-association" {
  subnet_id      = aws_subnet.Public-Subnet.id
  route_table_id = aws_route_table.Public-rt.id
}

resource "aws_route" "Default_route_to_My-IGW" {
  route_table_id         = aws_route_table.Public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.My-IGW.id
  depends_on = [
    aws_internet_gateway.My-IGW
  ]
}

# Route table for Public Subnets
resource "aws_route_table" "Private-rt" {
  vpc_id = aws_vpc.My-VPC.id
  tags = {
    Name = "Private-rt"
  }
}

resource "aws_route_table_association" "Private-rt-association" {
  subnet_id      = aws_subnet.Private-Subnet.id
  route_table_id = aws_route_table.Private-rt.id
}

resource "aws_route" "Default_route_to_My-NGW" {
  route_table_id         = aws_route_table.Private-rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.My-NGW.id
  depends_on = [
    aws_nat_gateway.My-NGW
  ]
}

# Security Group
resource "aws_security_group" "sg1" {
  name        = "sg1"
  description = "allow all traffic"
  vpc_id      = aws_vpc.My-VPC.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg1"

  }
}

# Generates a secure private key and encodes it as PEM
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Create the Key Pair
resource "aws_key_pair" "key_pair" {
  key_name   = "my-key-pair"
  public_key = tls_private_key.key_pair.public_key_openssh
}
# Save file
resource "local_file" "ssh_key" {
  filename = "${aws_key_pair.key_pair.key_name}.pem"
  content  = tls_private_key.key_pair.private_key_pem
}

# Filter to get the latest Amazon Linux AMI ID
data "aws_ami" "latest_amz_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn-ami-*"]
  }
}

# EC2 Instances in Public Subnet
resource "aws_instance" "Public_EC2" {
  ami                    = data.aws_ami.latest_amz_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Public-Subnet.id
  vpc_security_group_ids = [aws_security_group.sg1.id]
  key_name               = aws_key_pair.key_pair.key_name
  lifecycle {
    ignore_changes = [ami, associate_public_ip_address]
    #prevent_destroy = true
  }
  tags = {
    Name = "Public"
  }
}

# EC2 Instances in Private Subnet
resource "aws_instance" "Private_EC2" {
  ami                    = data.aws_ami.latest_amz_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Private-Subnet.id
  vpc_security_group_ids = [aws_security_group.sg1.id]
  key_name               = aws_key_pair.key_pair.key_name
  lifecycle {
    ignore_changes = [ami]
    #prevent_destroy = true
  }
  tags = {
    Name = "Private"
  }
}
