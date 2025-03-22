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

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create public subnets
resource "aws_subnet" "public_subnet" {
  count                   = 1
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a"], count.index)
  map_public_ip_on_launch = true
}

# Create a Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id
}

# Add a default route for public internet access
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = element(aws_subnet.public_subnet.*.id, 0)
  route_table_id = aws_route_table.public_rt.id
}

# Create security group for EC2 instance
resource "aws_security_group" "maingroub" {
  vpc_id = aws_vpc.my_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create EC2 instance
resource "aws_instance" "ec2" {
  ami                   = "ami-08b5b3a93ed654d19"
  instance_type         = "t2.micro"
  key_name              = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.maingroub.id]
  subnet_id             = element(aws_subnet.public_subnet.*.id, 0)
  associate_public_ip_address = true

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

# Create an ECR repository
resource "aws_ecr_repository" "devops_repo" {
  name = "devops-pro1"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Output instance public IP address
output "instance_public_ip" {
  value     = aws_instance.ec2.public_ip
}
