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

# 1. Seguridad
resource "aws_security_group" "web_sg" {
  name        = "bot-sg-${var.client_id}-${random_id.sg_suffix.hex}"
  ingress {
    from_port   = 80
    to_port     = 80
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

resource "random_id" "sg_suffix" {
  byte_length = 4
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] 
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# 2. Servidor
resource "aws_instance" "cliente_bot" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro" 
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "Sistema-${var.client_id}"
  }

  # --- SCRIPT INDESTRUCTIBLE ---
  # Usamos Nginx (ligero) pero inyectamos el HTML Pro
  user_data = <<-EOF
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive
    
    # 1. Esperar red
    sleep 20
    
    # 2. Instalar solo Nginx (Muy ligero, no falla)
    apt-get update
    apt-get install -y nginx

    # 3. Lógica BASH para definir qué mostrar (Reemplaza a Python)
    PAYMENT_HTML=""
    if [ "${var.enable_payments}" = "true" ]; then
      PAYMENT_HTML='<div class="flex items-start gap-3"><div class="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center"><i class="fa-solid fa-robot text-blue-600"></i></div><div class="bg-green-50 border border-green-100 rounded-2xl rounded-tl-none px-4 py-2 max-w-[80%] text-gray-800 text-sm shadow-sm"><p class="font-bold text-green-800 mb-1">💳 Enlace de Pago Generado</p><p>Aquí tienes tu link seguro.</p><button class="mt-2 bg-green-600 text-white px-3 py-1 rounded text-xs">Pagar $50.00</button></div></div>'
    fi

    VIP_BADGE=""
    if [ "${var.enable_vip}" = "true" ]; then
      VIP_BADGE='<span class="bg-purple-100 text-purple-700 px-3 py-1 rounded-full text-xs font-bold border border-purple-200"><i class="fa-solid fa-crown"></i> IA Análisis Activado</span>'
    fi

    # 4. Inyectar el HTML Profesional
    cat <<HTML > /var/www/html/index.html
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Sistema ${var.client_id}</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    </head>
    <body class="bg-gray-100 font-sans h-screen flex overflow-hidden">
        <aside class="w-64 bg-slate-900 text-white flex flex-col hidden md:flex">
            <div class="p-6 text-xl font-bold tracking-wider">
                <i class="fa-solid fa-robot text-blue-400"></i> BOT MANAGER
            </div>
            <nav class="flex-1 px-2 space-y-2 mt-4">
                <a href="#" class="flex items-center px-4 py-3 bg-blue-600 rounded-lg text-white">
                    <i class="fa-solid fa-comments w-6"></i> Chat Activo
                </a>
            </nav>
            <div class="p-4 bg-slate-950 text-xs text-slate-500">
                ID: ${var.client_id}<br>
                Server: AWS US-East (t2.micro)
            </div>
        </aside>

        <main class="flex-1 flex flex-col">
            <header class="bg-white shadow-sm px-8 py-4 flex justify-between items-center">
                <h2 class="text-xl font-semibold text-gray-800">Panel de Control en Vivo</h2>
                <div class="flex items-center gap-2">
                    <span class="w-3 h-3 bg-green-500 rounded-full animate-pulse"></span>
                    <span class="text-sm text-green-600 font-medium">Sistema Online</span>
                </div>
            </header>

            <div class="flex-1 p-8 overflow-y-auto">
                <div class="max-w-3xl mx-auto bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden flex flex-col h-[500px]">
                    <div class="bg-gray-50 px-6 py-4 border-b border-gray-200 flex justify-between items-center">
                        <span class="font-bold text-gray-700">Vista Previa del Bot</span>
                        $VIP_BADGE
                    </div>
                    
                    <div class="flex-1 p-6 space-y-4 bg-white overflow-y-auto" id="chatbox">
                        <div class="flex items-start gap-3">
                            <div class="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center">
                                <i class="fa-solid fa-robot text-blue-600"></i>
                            </div>
                            <div class="bg-gray-100 rounded-2xl rounded-tl-none px-4 py-2 max-w-[80%] text-gray-800 text-sm shadow-sm">
                                ${var.welcome_msg}
                            </div>
                        </div>
                        $PAYMENT_HTML
                    </div>

                    <div class="p-4 border-t border-gray-100 bg-gray-50 flex gap-2">
                        <input type="text" placeholder="Escribe un mensaje..." class="flex-1 border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:border-blue-500 text-sm">
                        <button class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition">
                            <i class="fa-solid fa-paper-plane"></i>
                        </button>
                    </div>
                </div>
            </div>
        </main>
    </body>
    </html>
    HTML

    # 5. Reiniciar para aplicar
    systemctl restart nginx
  EOF
}

output "server_ip" {
  value = aws_instance.cliente_bot.public_ip
}