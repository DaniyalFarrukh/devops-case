terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── Security Group ───────────────────────────────────────────────
resource "aws_security_group" "mern_sg" {
  name        = "mern-k3s-sg"
  description = "Allow HTTP, HTTPS, SSH and K3s traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Backend API"
    from_port   = 5050
    to_port     = 5050
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodePort range for K3s"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mern-k3s-sg"
  }
}

# ─── Key Pair ─────────────────────────────────────────────────────
resource "aws_key_pair" "deployer" {
  key_name   = "mern-deployer-key"
  public_key = var.ssh_public_key
}

# ─── EC2 Instance ─────────────────────────────────────────────────
resource "aws_instance" "mern_server" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"            # ← FIXED
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.mern_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  user_data = templatefile("${path.module}/scripts/bootstrap.sh", {})

  tags = {
    Name        = "mern-k3s-server"
    Environment = "production"
    Project     = "devops-case"
  }
}

# ─── Elastic IP (static public IP) ───────────────────────────────
resource "aws_eip" "mern_eip" {
  instance = aws_instance.mern_server.id
  domain   = "vpc"

  tags = {
    Name = "mern-k3s-eip"
  }
}