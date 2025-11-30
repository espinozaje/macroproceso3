terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# --- 1. VARIABLES ---
variable "instance_size" { type = string } 
variable "client_id" { type = string }
variable "industry" { type = string }
variable "welcome_msg" { type = string }
variable "logo_url" { type = string }
variable "enable_payments" { type = string }
variable "enable_vip" { type = string }

variable "n8n_chat_url" { 
  type = string 
  default = "https://tucorreo.trycloudflare.com/webhook/bot-chat" 
}

provider "aws" {
  region = "us-east-1"
}

# --- 2. SEGURIDAD ---
resource "aws_security_group" "web_sg" {
  name = "secgroup-${var.client_id}-${random_id.suffix.hex}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    protocol    = "-1"
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

# --- 3. SERVIDOR ---
resource "aws_instance" "app_server" {
  ami = data.aws_ami.ubuntu.id
  
  # Selección de servidor (Normal vs VIP)
  instance_type = var.instance_size == "s-2vcpu-2gb" ? "t3.small" : "t2.micro"
  
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = { Name = "SaaS-${var.client_id}" }

  # --- SCRIPT DE CONFIGURACIÓN ---
  user_data = <<-EOF
    #!/bin/bash
    
    # 1. Espera de seguridad
    sleep 30
    
    # 2. Instalación de Nginx
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y nginx jq
    
    # 3. LIMPIEZA
    rm -rf /var/www/html/*
    
    # Variables Bash
    CLIENT="${var.client_id}"
    INDUSTRY="${var.industry}"
    LOGO="${var.logo_url}"
    MSG="${var.welcome_msg}"
    PAYMENTS="${var.enable_payments}" 
    VIP="${var.enable_vip}"           
    CHAT_URL="${var.n8n_chat_url}"

    # 4. Crear el Dashboard
    cat <<HTML > /var/www/html/index.html
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Panel | $CLIENT</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600&display=swap" rel="stylesheet">
        <style>body{font-family:'Inter',sans-serif}</style>
    </head>
    <body class="bg-slate-100 h-screen flex overflow-hidden">
        <aside class="w-64 bg-slate-900 text-white flex flex-col z-20 shadow-xl">
            <div class="h-20 flex items-center gap-3 px-6 border-b border-slate-800">
                <img src="$LOGO" onerror="this.src='https://ui-avatars.com/api/?name=$CLIENT&background=random'" class="w-10 h-10 rounded bg-white p-1">
                <div>
                    <h1 class="font-bold text-sm capitalize truncate w-32">$CLIENT</h1>
                    <span class="text-[10px] text-slate-400 uppercase">$INDUSTRY</span>
                </div>
            </div>
            <nav class="flex-1 px-4 py-6 space-y-2">
                <a href="#" class="flex items-center gap-3 px-4 py-3 bg-blue-600 rounded text-white shadow hover:bg-blue-500 transition"><i class="fa-solid fa-robot"></i> Asistente IA</a>
                <div id="mod-pay" class="hidden"><a href="#" class="flex items-center gap-3 px-4 py-3 text-slate-400 hover:text-white transition"><i class="fa-solid fa-wallet"></i> Finanzas</a></div>
            </nav>
            <div id="mod-vip" class="hidden p-4"><div class="bg-gradient-to-r from-yellow-400 to-yellow-600 text-black p-3 rounded-lg text-xs font-bold text-center shadow-lg">👑 VIP MEMBER</div></div>
        </aside>

        <main class="flex-1 flex flex-col bg-slate-50 relative">
            <header class="h-16 bg-white border-b flex items-center px-8 justify-between">
                <h2 class="font-bold text-slate-700">Dashboard de Control</h2>
                <div class="text-xs text-green-600 font-medium">● Sistema Operativo</div>
            </header>

            <div id="chat-box" class="flex-1 p-8 overflow-y-auto space-y-4">
                <div class="flex gap-4">
                    <div class="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 flex-shrink-0"><i class="fa-solid fa-robot"></i></div>
                    <div class="bg-white p-4 rounded-xl shadow-sm text-sm border border-slate-100">$MSG</div>
                </div>
            </div>

            <div class="p-6 bg-white border-t">
                <form id="chat-form" class="flex gap-2 max-w-4xl mx-auto">
                    <input id="in" type="text" class="flex-1 border border-slate-300 p-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="Escribe tu comando...">
                    <button class="bg-blue-600 hover:bg-blue-700 text-white px-6 rounded-lg font-medium transition">Enviar</button>
                </form>
            </div>
        </main>

        <script>
            // LÓGICA DE CLIENTE
            const cfg = { p: "$PAYMENTS", v: "$VIP", url: "$CHAT_URL" };
            
            if(cfg.p === 'true') document.getElementById('mod-pay').classList.remove('hidden');
            if(cfg.v === 'true') document.getElementById('mod-vip').classList.remove('hidden');

            const box = document.getElementById('chat-box');
            
            document.getElementById('chat-form').addEventListener('submit', async (e) => {
                e.preventDefault();
                const inp = document.getElementById('in');
                const txt = inp.value.trim();
                if(!txt) return;
                
                box.innerHTML += \`<div class="flex gap-4 flex-row-reverse"><div class="bg-blue-600 text-white p-4 rounded-xl text-sm shadow-md">$${txt}</div></div>\`;
                inp.value = '';
                box.scrollTop = box.scrollHeight;
                
                try {
                    const res = await fetch(cfg.url, {
                        method: 'POST',
                        headers: {'Content-Type':'application/json'},
                        body: JSON.stringify({message: txt})
                    });
                    const d = await res.json();
                    
                    const respuesta = d.output || "Comando procesado.";
                    box.innerHTML += \`<div class="flex gap-4 mt-4"><div class="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600"><i class="fa-solid fa-robot"></i></div><div class="bg-white p-4 rounded-xl shadow-sm text-sm border border-slate-100">$${respuesta}</div></div>\`;
                    box.scrollTop = box.scrollHeight;
                } catch(e) { console.error(e); }
            });
        </script>
    </body>
    </html>
HTML

    # --- 5. Permisos y Reinicio final (AHORA SÍ FUERA DEL HTML) ---
    chown -R www-data:www-data /var/www/html
    chmod 755 /var/www/html
    systemctl restart nginx
  EOF
}

output "server_ip" { value = aws_instance.app_server.public_ip }