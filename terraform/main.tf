terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

variable "client_id" { type = string }
variable "instance_size" { type = string }
variable "welcome_msg" { type = string }
variable "enable_payments" { type = string }
variable "enable_vip" { type = string }

provider "aws" {
  region = "us-east-1"
}

# 1. Firewall (Permitir tráfico Web)
resource "aws_security_group" "web_sg" {
  name        = "sec-group-${var.client_id}-${random_id.sg_suffix.hex}"
  description = "Permitir HTTP"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress { # SSH para debug (opcional)
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Random ID para evitar conflictos de nombres si destruyes y creas rápido
resource "random_id" "sg_suffix" {
  byte_length = 4
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# 2. Servidor
resource "aws_instance" "cliente_bot" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro" # Forzamos la barata para asegurar que corra
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "Bot-${var.client_id}"
  }

  # --- SCRIPT ULTRA-ROBUSTO (Sin Docker para asegurar éxito) ---
  user_data = <<-EOF
    #!/bin/bash
    # 1. Evitar ventanas de confirmación que bloquean el script
    export DEBIAN_FRONTEND=noninteractive

    # 2. Esperar a que la red esté lista (truco clave)
    sleep 30

    # 3. Actualizar e instalar Nginx (Servidor Web ligero)
    apt-get update -y
    apt-get install -y nginx

    # 4. Crear la página web personalizada con las variables de n8n
    cat <<HTML > /var/www/html/index.html
    <!DOCTYPE html>
    <html>
    <head>
        <title>Bot de ${var.client_id}</title>
        <style>
            body { font-family: sans-serif; text-align: center; padding: 50px; background: #f0f9ff; }
            h1 { color: #0284c7; }
            .card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); max-width: 500px; margin: auto; }
            .badge { display: inline-block; padding: 5px 10px; border-radius: 15px; font-size: 12px; font-weight: bold; color: white; margin: 5px; }
            .vip { background-color: #7c3aed; }
            .pay { background-color: #059669; }
            .basic { background-color: #64748b; }
        </style>
    </head>
    <body>
        <div class="card">
            <h1>🤖 Bot Activo</h1>
            <p>Cliente ID: <strong>${var.client_id}</strong></p>
            <hr>
            <p>Mensaje de Bienvenida:</p>
            <h3>"${var.welcome_msg}"</h3>
            <hr>
            <p>Módulos Instalados:</p>
            
            $(if [ "${var.enable_vip}" = "true" ]; then echo '<span class="badge vip">⭐ Módulo VIP</span>'; fi)
            $(if [ "${var.enable_payments}" = "true" ]; then echo '<span class="badge pay">💰 Pagos Online</span>'; fi)
            <span class="badge basic">✅ Chatbot Base</span>
        </div>
    </body>
    </html>
    HTML

    # 5. Reiniciar Nginx para asegurar que cargue
    systemctl restart nginx
  EOF
}

output "server_ip" {
  value = aws_instance.cliente_bot.public_ip
}