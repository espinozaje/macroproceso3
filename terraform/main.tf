terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# --- NUEVAS VARIABLES ---
variable "client_id" { type = string }
variable "instance_size" { type = string }
variable "welcome_msg" { type = string }
variable "enable_payments" { type = string }
variable "enable_vip" { type = string }
variable "logo_url" { type = string }   # <--- NUEVO
variable "industry" { type = string }   # <--- NUEVO
variable "n8n_chat_url" { type = string; default = "https://dot-mineral-advancement-skirt.trycloudflare.com/webhook-test/bot-chat" } # REEMPLAZA CON TU URL REAL

provider "aws" {
  region = "us-east-1"
}

# 1. Seguridad
resource "aws_security_group" "web_sg" {
  name        = "bot-sg-${var.client_id}-${random_id.sg_suffix.hex}"
  ingress { from_port = 80; to_port = 80; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

resource "random_id" "sg_suffix" { byte_length = 4 }

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter { name = "name"; values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"] }
}

# 2. Servidor
resource "aws_instance" "cliente_bot" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = { Name = "Sistema-${var.client_id}" }

  user_data = <<-EOF
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive
    sleep 20
    apt-get update
    apt-get install -y nginx

    VIP_BADGE=""
    if [ "${var.enable_vip}" = "true" ]; then
      VIP_BADGE='<span class="bg-purple-100 text-purple-700 px-3 py-1 rounded-full text-xs font-bold border border-purple-200">✨ Modo VIP</span>'
    fi

    cat <<HTML > /var/www/html/index.html
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>${var.client_id} - ${var.industry}</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    </head>
    <body class="bg-gray-50 font-sans h-screen flex flex-col">
        <header class="bg-white shadow-sm p-4 flex justify-between items-center">
            <div class="flex items-center gap-3">
                <img src="${var.logo_url}" class="w-10 h-10 rounded-full object-cover border border-gray-200">
                <div class="font-bold text-gray-700 capitalize">${var.client_id}</div>
            </div>
            $VIP_BADGE
        </header>

        <div id="chat-container" class="flex-1 p-4 overflow-y-auto space-y-4">
            <div class="flex items-start gap-2">
                <img src="${var.logo_url}" class="w-8 h-8 rounded-full object-cover">
                <div class="bg-white p-3 rounded-lg shadow-sm text-sm border border-gray-100 max-w-[80%]">
                    ${var.welcome_msg}
                </div>
            </div>
        </div>

        <div class="p-4 bg-white border-t border-gray-200">
            <form id="chat-form" class="flex gap-2">
                <input type="text" id="user-input" placeholder="Escribe sobre ${var.industry}..." class="flex-1 border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:border-blue-500">
                <button type="submit" class="bg-blue-600 text-white px-6 rounded-lg hover:bg-blue-700 transition">
                    <i class="fa-solid fa-paper-plane"></i>
                </button>
            </form>
        </div>

        <script>
            const form = document.getElementById('chat-form');
            const input = document.getElementById('user-input');
            const container = document.getElementById('chat-container');
            const N8N_URL = "${var.n8n_chat_url}";
            
            // CONTEXTO PARA EL CEREBRO N8N
            const CONTEXT = {
                client_id: "${var.client_id}",
                industry: "${var.industry}",  // <-- NUEVO: La industria
                payments_enabled: "${var.enable_payments}",
                vip_enabled: "${var.enable_vip}"
            };

            function addMessage(text, isUser) {
                const div = document.createElement('div');
                div.className = isUser ? 'flex items-start gap-2 justify-end' : 'flex items-start gap-2';
                const bubble = document.createElement('div');
                bubble.className = isUser ? 'bg-blue-600 text-white p-3 rounded-lg shadow-sm text-sm max-w-[80%]' : 'bg-white p-3 rounded-lg shadow-sm text-sm border border-gray-100 max-w-[80%]';
                bubble.innerHTML = text;
                if (isUser) {
                    div.appendChild(bubble);
                } else {
                    const icon = document.createElement('img');
                    icon.src = "${var.logo_url}"; // Logo real
                    icon.className = 'w-8 h-8 rounded-full object-cover';
                    div.appendChild(icon);
                    div.appendChild(bubble);
                }
                container.appendChild(div);
                container.scrollTop = container.scrollHeight;
            }

            form.addEventListener('submit', async (e) => {
                e.preventDefault();
                const msg = input.value.trim();
                if (!msg) return;
                addMessage(msg, true);
                input.value = '';
                const loadingId = 'loading-' + Date.now();
                const loadingDiv = document.createElement('div');
                loadingDiv.id = loadingId;
                loadingDiv.innerHTML = '<div class="flex gap-2 ml-2"><span class="animate-bounce">.</span><span class="animate-bounce delay-100">.</span><span class="animate-bounce delay-200">.</span></div>';
                container.appendChild(loadingDiv);

                try {
                    const response = await fetch(N8N_URL, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ message: msg, context: CONTEXT })
                    });
                    const data = await response.json();
                    document.getElementById(loadingId).remove();
                    addMessage(data.output || data.text || "No entendí", false);
                } catch (err) {
                    console.error(err);
                    document.getElementById(loadingId).remove();
                    addMessage("❌ Error conectando con el cerebro.", false);
                }
            });
        </script>
    </body>
    </html>
    systemctl restart nginx
  EOF
}

output "server_ip" { value = aws_instance.cliente_bot.public_ip }