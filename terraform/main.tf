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

# Create the VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Create public subnets
resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true
}

# Create private subnets
resource "aws_subnet" "private_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, count.index + 2)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
}

# Create security group for EC2 instance
resource "aws_security_group" "maingroub" {
  vpc_id = aws_vpc.my_vpc.id  # Ensure it's in the same VPC

  egress = [
    {
      cidr_blocks = ["0.0.0.0/0"]
      description = ""
      from_port   = 0
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      protocol    = "-1"
      security_groups = []
      self        = false
      to_port     = 0
    }
  ]

  ingress = [
    {
      cidr_blocks = ["0.0.0.0/0"]
      description = ""
      from_port   = 22
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      protocol    = "tcp"
      security_groups = []
      self        = false
      to_port     = 22
    },
    {
      cidr_blocks = ["0.0.0.0/0"]
      description = ""
      from_port   = 80
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      protocol    = "tcp"
      security_groups = []
      self        = false
      to_port     = 80
    }
  ]
}

# Create EC2 instance
resource "aws_instance" "ec2" {
  ami                   = "ami-08b5b3a93ed654d19"
  instance_type         = "t2.micro"
  key_name              = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.maingroub.id]
  subnet_id             = element(aws_subnet.public_subnet.*.id, 0)  # First public subnet

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

# Create an IAM instance profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = "ec2-ecr-auth"
}

# Create SSH key pair for EC2
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = var.public_key
}

# Output instance public IP address
output "instance_public_ip" {
  value     = aws_instance.ec2.public_ip
  sensitive = true
}

