# Crear el Servidor (Droplet)
resource "digitalocean_droplet" "cliente_bot" {
  image  = "docker-20-04" # Imagen de Ubuntu que ya trae Docker instalado
  name   = "bot-${var.client_id}"
  region = "nyc1"
  size   = var.instance_size # Dinámico según si pagó VIP o no

  # Script de inicio (Cloud-Init): Esto corre dentro del servidor al nacer
  user_data = <<-EOF
    #!/bin/bash
    mkdir -p /app
    
    # Aquí creamos el código del bot "al vuelo" para este ejemplo.
    # En producción, harías 'docker pull tu-usuario/tu-imagen:latest'
    
    cat <<EOT >> /app/app.py
import os
from flask import Flask
app = Flask(__name__)

MSG = os.getenv('WELCOME_MESSAGE', 'Hola')
PAGOS = os.getenv('ENABLE_PAYMENTS') == 'true'
VIP = os.getenv('ENABLE_VIP') == 'true'

@app.route('/')
def hello():
    features = []
    if PAGOS: features.append("💰 Pagos Activos")
    if VIP: features.append("⭐ IA VIP Activa")
    
    return f"""
    <h1>Bot de ${var.client_id}</h1>
    <p>Mensaje: {MSG}</p>
    <p>Módulos: {", ".join(features) if features else "Básico"}</p>
    """

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

# Output para que n8n sepa dónde quedó el bot
output "server_ip" {
  value = digitalocean_droplet.cliente_bot.ipv4_address
}