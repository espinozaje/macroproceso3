terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# --- VARIABLES ---
variable "client_id" { type = string }
variable "instance_size" { type = string }
variable "welcome_msg" { type = string }
variable "enable_payments" { type = string }
variable "enable_vip" { type = string }
variable "logo_url" { type = string }
variable "industry" { type = string }
variable "n8n_chat_url" { 
  type = string 
  default = "https://dot-mineral-advancement-skirt.trycloudflare.com/webhook-test/bot-chat" 
} 

provider "aws" {
  region = "us-east-1"
}

# 1. Seguridad
resource "aws_security_group" "web_sg" {
  name = "bot-sg-${var.client_id}-${random_id.sg_suffix.hex}"

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

resource "random_id" "sg_suffix" { byte_length = 4 }

# 2. AMI (Corregido)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# 3. Servidor con Interfaz Profesional
resource "aws_instance" "cliente_bot" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = { Name = "SaaS-${var.client_id}" }

  user_data = <<-EOF
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive
    sleep 20
    apt-get update
    apt-get install -y nginx

    # --- LOGICA DINAMICA DE MODULOS ---
    
    # 1. Menú Lateral (Sidebar)
    MENU_ITEMS='<a href="#" class="flex items-center gap-3 px-4 py-3 bg-slate-800 text-blue-400 border-r-4 border-blue-500"><i class="fa-solid fa-comments w-5"></i> <span class="font-medium">Asistente IA</span></a>'
    
    if [ "${var.enable_payments}" = "true" ]; then
      MENU_ITEMS+='<a href="#" class="flex items-center gap-3 px-4 py-3 text-slate-400 hover:bg-slate-800 hover:text-white transition"><i class="fa-solid fa-credit-card w-5"></i> <span class="font-medium">Pagos y Facturas</span></a>'
    fi

    if [ "${var.enable_vip}" = "true" ]; then
      MENU_ITEMS+='<a href="#" class="flex items-center gap-3 px-4 py-3 text-amber-400 hover:bg-slate-800 hover:text-amber-300 transition"><i class="fa-solid fa-crown w-5"></i> <span class="font-medium">Zona VIP</span></a>'
    fi

    MENU_ITEMS+='<div class="mt-auto p-4 border-t border-slate-700"><div class="flex items-center gap-3"><div class="w-8 h-8 rounded-full bg-slate-600 flex items-center justify-center text-xs">US</div><div class="text-xs text-slate-400">Usuario Invitado</div></div></div>'

    # 2. Header Badges
    HEADER_BADGES=""
    if [ "${var.enable_vip}" = "true" ]; then
        HEADER_BADGES='<span class="bg-gradient-to-r from-amber-200 to-yellow-400 text-amber-900 px-3 py-1 rounded-full text-xs font-bold shadow-sm flex items-center gap-1"><i class="fa-solid fa-star"></i> Cliente Premium</span>'
    fi

    # --- GENERAR HTML ---
    cat <<HTML > /var/www/html/index.html
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Panel ${var.client_id}</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
        <style>
            /* Scrollbar personalizada */
            ::-webkit-scrollbar { width: 6px; }
            ::-webkit-scrollbar-track { background: #f1f5f9; }
            ::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 4px; }
            ::-webkit-scrollbar-thumb:hover { background: #94a3b8; }
            .typing-dot { animation: typing 1.4s infinite ease-in-out both; }
            .typing-dot:nth-child(1) { animation-delay: -0.32s; }
            .typing-dot:nth-child(2) { animation-delay: -0.16s; }
            @keyframes typing { 0%, 80%, 100% { transform: scale(0); } 40% { transform: scale(1); } }
        </style>
    </head>
    <body class="bg-slate-100 font-sans h-screen flex overflow-hidden text-slate-800">

        <aside class="w-64 bg-slate-900 text-white flex flex-col shadow-xl z-10 hidden md:flex">
            <div class="p-6 border-b border-slate-800 flex items-center gap-3">
                <img src="${var.logo_url}" 
                     onerror="this.onerror=null; this.src='https://ui-avatars.com/api/?name=${var.client_id}&background=3b82f6&color=fff&size=128'"
                     class="w-10 h-10 rounded-lg object-cover bg-slate-800">
                <div>
                    <h1 class="font-bold text-lg leading-tight capitalize">${var.client_id}</h1>
                    <p class="text-xs text-slate-500 uppercase tracking-wider">${var.industry}</p>
                </div>
            </div>
            
            <nav class="flex-1 py-4 flex flex-col gap-1">
                $MENU_ITEMS
            </nav>
        </aside>

        <main class="flex-1 flex flex-col relative">
            
            <header class="bg-white h-16 border-b border-slate-200 flex justify-between items-center px-6 shadow-sm z-10">
                <div class="flex items-center gap-2 text-slate-700">
                    <i class="fa-solid fa-robot text-blue-500"></i>
                    <span class="font-semibold">Asistente Virtual</span>
                </div>
                <div class="flex items-center gap-4">
                    $HEADER_BADGES
                    <button class="text-slate-400 hover:text-slate-600"><i class="fa-solid fa-bell"></i></button>
                    <button class="md:hidden text-slate-600"><i class="fa-solid fa-bars"></i></button>
                </div>
            </header>

            <div id="chat-container" class="flex-1 overflow-y-auto p-6 space-y-6 bg-slate-50">
                
                <div class="flex items-start gap-4 max-w-3xl mx-auto">
                    <img src="${var.logo_url}" 
                         onerror="this.onerror=null; this.src='https://ui-avatars.com/api/?name=${var.client_id}&background=3b82f6&color=fff'"
                         class="w-10 h-10 rounded-full object-cover shadow-sm border-2 border-white">
                    <div class="flex flex-col gap-1">
                        <span class="text-xs text-slate-400 ml-1 font-medium capitalize">${var.client_id} Bot</span>
                        <div class="bg-white p-4 rounded-2xl rounded-tl-none shadow-sm border border-slate-100 text-slate-700 leading-relaxed">
                            ${var.welcome_msg}
                        </div>
                    </div>
                </div>

            </div>

            <div class="bg-white p-4 border-t border-slate-200">
                <div class="max-w-3xl mx-auto">
                    <form id="chat-form" class="relative flex items-center gap-2">
                        <input type="text" id="user-input" 
                               placeholder="Escribe tu consulta sobre ${var.industry}..." 
                               class="w-full bg-slate-100 border-0 rounded-xl px-5 py-4 pr-12 text-slate-700 focus:ring-2 focus:ring-blue-500 focus:bg-white transition-all shadow-inner"
                               autocomplete="off">
                        <button type="submit" 
                                class="absolute right-2 bg-blue-600 text-white w-10 h-10 rounded-lg hover:bg-blue-700 transition flex items-center justify-center shadow-lg hover:shadow-blue-500/30">
                            <i class="fa-solid fa-paper-plane text-sm"></i>
                        </button>
                    </form>
                    <div class="text-center mt-2">
                        <p class="text-[10px] text-slate-400">Impulsado por AI & n8n • ${var.client_id} Solutions</p>
                    </div>
                </div>
            </div>

        </main>

        <script>
            const form = document.getElementById('chat-form');
            const input = document.getElementById('user-input');
            const container = document.getElementById('chat-container');
            const N8N_URL = "${var.n8n_chat_url}";
            
            // Imagen por defecto si falla la carga
            const LOGO_SRC = "${var.logo_url}"; 
            const FALLBACK_SRC = "https://ui-avatars.com/api/?name=${var.client_id}&background=3b82f6&color=fff";

            const CONTEXT = {
                client_id: "${var.client_id}",
                industry: "${var.industry}", 
                payments_enabled: "${var.enable_payments}",
                vip_enabled: "${var.enable_vip}"
            };

            function scrollToBottom() {
                container.scrollTo({ top: container.scrollHeight, behavior: 'smooth' });
            }

            function addMessage(text, isUser) {
                const div = document.createElement('div');
                div.className = isUser ? 'flex items-start gap-4 justify-end max-w-3xl mx-auto' : 'flex items-start gap-4 max-w-3xl mx-auto';
                
                // Avatar Logic
                let avatarHTML = '';
                if (!isUser) {
                    avatarHTML = \`<img src="\${LOGO_SRC}" onerror="this.onerror=null; this.src='\${FALLBACK_SRC}'" class="w-10 h-10 rounded-full object-cover shadow-sm border-2 border-white">\`;
                }

                // Bubble Styling
                const bubbleClass = isUser 
                    ? 'bg-blue-600 text-white p-4 rounded-2xl rounded-tr-none shadow-md shadow-blue-500/10' 
                    : 'bg-white text-slate-700 p-4 rounded-2xl rounded-tl-none shadow-sm border border-slate-100';

                div.innerHTML = isUser 
                    ? \`<div class="\${bubbleClass}">\${text}</div>\` 
                    : \`\${avatarHTML}<div class="flex flex-col gap-1"><span class="text-xs text-slate-400 ml-1 font-medium capitalize">IA</span><div class="\${bubbleClass}">\${text}</div></div>\`;

                container.appendChild(div);
                scrollToBottom();
            }

            function showLoading() {
                const id = 'loading-' + Date.now();
                const div = document.createElement('div');
                div.id = id;
                div.className = 'flex items-start gap-4 max-w-3xl mx-auto';
                div.innerHTML = \`
                    <img src="\${LOGO_SRC}" onerror="this.onerror=null; this.src='\${FALLBACK_SRC}'" class="w-10 h-10 rounded-full object-cover shadow-sm border-2 border-white">
                    <div class="bg-white p-4 rounded-2xl rounded-tl-none shadow-sm border border-slate-100 flex gap-2 items-center h-14">
                        <div class="w-2 h-2 bg-slate-400 rounded-full typing-dot"></div>
                        <div class="w-2 h-2 bg-slate-400 rounded-full typing-dot"></div>
                        <div class="w-2 h-2 bg-slate-400 rounded-full typing-dot"></div>
                    </div>
                \`;
                container.appendChild(div);
                scrollToBottom();
                return id;
            }

            form.addEventListener('submit', async (e) => {
                e.preventDefault();
                const msg = input.value.trim();
                if (!msg) return;
                
                addMessage(msg, true);
                input.value = '';
                
                const loadingId = showLoading();

                try {
                    const response = await fetch(N8N_URL, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ message: msg, context: CONTEXT })
                    });
                    const data = await response.json();
                    document.getElementById(loadingId).remove();
                    addMessage(data.output || data.text || "No entendí, pero estoy aquí para ayudar.", false);
                } catch (err) {
                    console.error(err);
                    document.getElementById(loadingId).remove();
                    addMessage("❌ Error conectando con el sistema central.", false);
                }
            });
        </script>
    </body>
    </html>
    systemctl restart nginx
  EOF
}

output "server_ip" { value = aws_instance.cliente_bot.public_ip }