terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_region" {
  description = "AWS region where the monitor server will be created."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for the monitor server."
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Short name used for AWS resource names and tags."
  type        = string
  default     = "monitor-project"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name)) && length(var.project_name) >= 3
    error_message = "project_name must contain at least 3 lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment used in AWS tags."
  type        = string
  default     = "Production"

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment must not be empty."
  }
}

variable "key_name" {
  description = "Existing AWS EC2 key pair name used for SSH access."
  type        = string

  validation {
    condition     = length(trimspace(var.key_name)) > 0
    error_message = "key_name must reference an existing AWS EC2 key pair."
  }
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to connect to SSH. Keep this limited to trusted admin IPs."
  type        = set(string)

  validation {
    condition     = length(var.ssh_cidr_blocks) > 0 && alltrue([for cidr in var.ssh_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "ssh_cidr_blocks must contain at least one valid CIDR block."
  }
}

variable "nodeport_cidr_blocks" {
  description = "CIDR blocks allowed to reach the Kubernetes NodePort. Empty disables public NodePort access."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.nodeport_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "nodeport_cidr_blocks must contain only valid CIDR blocks."
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# 1. Create a security group with restricted inbound access.
resource "aws_security_group" "monitor_sg" {
  name        = "${var.project_name}-sg"
  description = "Firewall for the DevOps monitoring project"

  # SSH is limited to the administrator-provided CIDR blocks.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  # NodePort access is optional and restricted when enabled.
  dynamic "ingress" {
    for_each = length(var.nodeport_cidr_blocks) > 0 ? [true] : []
    content {
      from_port   = 32000
      to_port     = 32000
      protocol    = "tcp"
      cidr_blocks = var.nodeport_cidr_blocks
    }
  }

  # HTTPS is required for package downloads and the Docker installation script.
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS is required for hostname resolution.
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMP is required by Monitor.py for ping checks.
  egress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. Create the EC2 instance.
resource "aws_instance" "monitor_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.monitor_sg.id]

  tags = {
    Name        = "${var.project_name}-server"
    Environment = var.environment
  }
}

# 3. Output the public IP for Ansible.
output "instancia_ip_publica" {
  value       = aws_instance.monitor_server.public_ip
  description = "Public IP to add to the Ansible inventory"
}
