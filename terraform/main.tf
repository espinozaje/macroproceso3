terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# --- SOLO ESTAS 3 VARIABLES SON NECESARIAS AHORA ---
variable "instance_size" { type = string } 
variable "client_id" { type = string }
variable "html_base64" { type = string } # <--- Esta recibe el diseño de Gemini

provider "aws" {
  region = "us-east-1"
}

# --- SEGURIDAD ---
resource "aws_security_group" "web_sg" {
  name = "secgroup-${var.client_id}-${random_id.suffix.hex}"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_id" "suffix" { byte_length = 4 }

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] 
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# --- SERVIDOR ---
resource "aws_instance" "app_server" {
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_size == "s-2vcpu-2gb" ? "t3.small" : "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = { Name = "SaaS-${var.client_id}" }

  # --- DESPLIEGUE MÁGICO ---
  user_data = <<-EOF
    #!/bin/bash
    sleep 30
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y nginx coreutils
    
    rm -rf /var/www/html/*
    
    # Aquí Terraform pega el Base64 y Linux lo convierte en archivo HTML
    echo "${var.html_base64}" | base64 -d > /var/www/html/index.html

    chown -R www-data:www-data /var/www/html
    chmod 755 /var/www/html
    systemctl restart nginx
  EOF
}

output "server_ip" { value = aws_instance.app_server.public_ip }