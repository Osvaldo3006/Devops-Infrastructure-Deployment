terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Aqui puedes cambiar la region a la que sea mas de tu conveniencia
}

# 1. Crear el Security Group (Firewall) con los puertos que necesitamos para Ansible, Flask y Kubernetes
resource "aws_security_group" "monitor_sg" {
  name        = "monitor-project-sg"
  description = "Firewall para el proyecto de monitoreo DevOps"

  # Puerto para Ansible (SSH)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Aqui depende si quieres que sea abierto a todo el mundo o solo a tu IP, puedes cambiarlo a tu IP para mayor seguridad
  }

  # Puerto para la API de Flask
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto exterior para el servicio de Kubernetes (NodePort)
  ingress {
    from_port   = 32000
    to_port     = 32000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regla de salida: Permitir que el servidor descargue Docker y pings a internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. Crear la Instancia EC2 dentro de la Capa Gratuita
resource "aws_instance" "monitor_server" {
  ami           = "ami-0866a3c8686eaeeba" # ID de Ubuntu 22.04 LTS en us-east-1 (Free Tier)
  instance_type = "t2.micro"             # Capa gratuita de AWS (1GB RAM)
  
  # Le pegamos el firewall que creamos arriba
  vpc_security_group_ids = [aws_security_group.monitor_sg.id]
  
  key_name = "mi-llave-aws" # El nombre de tu llave .pem en AWS

  tags = {
    Name = "servidor-monitor-devops"
    Environment = "Production"
  }
}

# 3. Output: Al terminar, Terraform te pintará en la pantalla la IP para Ansible
output "instancia_ip_publica" {
  value       = aws_instance.monitor_server.public_ip
  description = "Copia esta IP y pégala en tu archivo inventory.ini de Ansible"
}
