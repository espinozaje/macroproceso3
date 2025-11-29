
resource "aws_security_group" "permitir_web" {
  name        = "reglas-chatbot-${var.client_id}"
  description = "Permitir trafico web para el bot"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Permitir a todo el mundo
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Permitir salir a internet (para descargar Docker)
    cidr_blocks = ["0.0.0.0/0"]
  }
}


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # ID oficial de Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# --- 3. Crear el Servidor (Instancia EC2) ---
resource "aws_instance" "cliente_bot" {
  ami           = data.aws_ami.ubuntu.id
  # Si pagó VIP usamos t3.medium, si no t2.micro (que es GRATIS en la capa gratuita)
  instance_type = var.enable_vip == "true" ? "t3.medium" : "t2.micro"
  
  # Asignamos el firewall que creamos arriba
  vpc_security_group_ids = [aws_security_group.permitir_web.id]

  tags = {
    Name = "Bot-${var.client_id}"
  }

  # Script de inicio (Instalar Docker y Correr Bot)
  user_data = <<-EOF
    #!/bin/bash
    # Actualizar e instalar Docker (AWS Linux no siempre trae Docker por defecto)
    apt-get update
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker

    # Crear carpeta y archivos del bot
    mkdir -p /app
    
    # Crear app.py
    cat <<EOT >> /app/app.py
import os
from flask import Flask
app = Flask(__name__)

MSG = os.getenv('WELCOME_MESSAGE', 'Hola AWS')
PAGOS = os.getenv('ENABLE_PAYMENTS') == 'true'
VIP = os.getenv('ENABLE_VIP') == 'true'

@app.route('/')
def hello():
    color = "orange" # Naranja por AWS
    html = f"<h1 style='color:{color}'>Bot AWS de {var.client_id}</h1><p>Mensaje: {MSG}</p>"
    if PAGOS: html += "<p>✅ Pagos Activos</p>"
    if VIP: html += "<p>⭐ Módulo VIP Activo</p>"
    return html

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOT

    # Crear Dockerfile
    echo "FROM python:3.9-slim" > /app/Dockerfile
    echo "RUN pip install flask" >> /app/Dockerfile
    echo "COPY app.py /app.py" >> /app/Dockerfile
    echo "CMD [\"python\", \"/app.py\"]" >> /app/Dockerfile

    # Construir y correr
    cd /app
    docker build -t mi-bot .
    docker run -d -p 80:80 \
      -e WELCOME_MESSAGE="${var.welcome_msg}" \
      -e ENABLE_PAYMENTS="${var.enable_payments}" \
      -e ENABLE_VIP="${var.enable_vip}" \
      mi-bot
  EOF
}

# Output: Devolver la IP Pública de AWS
output "server_ip" {
  value = aws_instance.cliente_bot.public_ip
}