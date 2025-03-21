terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    key = "aws/ec2-deploy/terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
}

# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"  # Ensure the CIDR block accommodates all your subnets
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, count.index)  # Dynamically generate subnet CIDR blocks
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true  # Ensure the instance gets a public IP
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, count.index + 2)  # Different range for private subnets
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
}

# EC2 Instance
resource "aws_instance" "ec2" {
  ami                   = "ami-08b5b3a93ed654d19"
  instance_type         = "t2.micro"
  key_name              = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.maingroub.id]
  
  # Select a subnet from the public subnets created above using element
  subnet_id             = element(aws_subnet.public_subnet.*.id, 0)  # Select the first public subnet (index 0)

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = var.private_key
    timeout     = "4m"
  }

  tags = {
    "name" = "DeployVM"
  }
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = "ec2-ecr-auth"
}

# Security Group
resource "aws_security_group" "maingroub" {
  egress = [
    {
      cidr_blocks       = ["0.0.0.0/0"]
      description       = ""
      from_port         = 0
      ipv6_cidr_blocks = []
      prefix_list_ids   = []
      protocol         = "-1"
      security_groups  = []
      self              = false
      to_port           = 0
    }
  ]
  ingress = [
    {
      cidr_blocks       = ["0.0.0.0/0"]
      description       = ""
      from_port         = 22
      ipv6_cidr_blocks = []
      prefix_list_ids   = []
      protocol         = "tcp"
      security_groups  = []
      self              = false
      to_port           = 22
    },
    {
      cidr_blocks       = ["0.0.0.0/0"]
      description       = ""
      from_port         = 80
      ipv6_cidr_blocks = []
      prefix_list_ids   = []
      protocol         = "tcp"
      security_groups  = []
      self              = false
      to_port           = 80
    }
  ]
}

# SSH Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = var.public_key
}

# Output EC2 Public IP
output "instance_public_ip" {
  value     = aws_instance.ec2.public_ip
  sensitive = true
}
