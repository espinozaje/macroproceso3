terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# --- VARIABLES DINÁMICAS (Vienen de n8n) ---
variable "client_id" { type = string }
variable "instance_size" { type = string }
variable "welcome_msg" { type = string }
variable "enable_payments" { type = string } # "true" o "false"
variable "enable_vip" { type = string }      # "true" o "false"
variable "logo_url" { type = string }
variable "industry" { type = string }        # Ej: "Dental", "Ecommerce", "Consultora"
variable "n8n_chat_url" { 
  type = string 
  default = "https://dot-mineral-advancement-skirt.trycloudflare.com/webhook-test/bot-chat" 
} 

provider "aws" {
  region = "us-east-1"
}

# 1. Seguridad (Puertos abiertos para web)
resource "aws_security_group" "web_sg" {
  name = "bot-sg-${var.client_id}-${random_id.sg_suffix.hex}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
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

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# 2. Servidor con Despliegue de UI Profesional
resource "aws_instance" "cliente_bot" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro" # Podría ser var.instance_size si tienes mapeo
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = { Name = "Sistema-${var.client_id}" }

  user_data = <<-EOF
    #!/bin/bash
    
    # 1. Preparación del entorno
    export DEBIAN_FRONTEND=noninteractive
    apt-get update && apt-get install -y nginx jq

    # 2. Captura de variables de Terraform a Bash para evitar errores de sintaxis
    CLIENT_NAME="${var.client_id}"
    INDUSTRY="${var.industry}"
    LOGO_URL="${var.logo_url}"
    WELCOME_MSG="${var.welcome_msg}"
    ENABLE_PAYMENTS="${var.enable_payments}"
    ENABLE_VIP="${var.enable_vip}"
    N8N_URL="${var.n8n_chat_url}"

    # 3. Construcción del HTML Profesional
    cat <<HTML > /var/www/html/index.html
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>$CLIENT_NAME | Sistema Inteligente</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
        
        <style>
            body { font-family: 'Inter', sans-serif; }
            /* Scrollbar personalizada */
            ::-webkit-scrollbar { width: 6px; }
            ::-webkit-scrollbar-track { background: #f1f1f1; }
            ::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 4px; }
            ::-webkit-scrollbar-thumb:hover { background: #94a3b8; }
            
            .msg-bubble { animation: fadeIn 0.3s ease-in-out; }
            @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
        </style>
    </head>
    <body class="bg-gray-100 h-screen flex overflow-hidden">

        <aside class="w-64 bg-slate-900 text-white flex flex-col hidden md:flex shadow-xl">
            <div class="p-6 border-b border-slate-700 flex items-center gap-3">
                <div class="relative">
                    <img src="$LOGO_URL" onerror="this.src='https://ui-avatars.com/api/?name=$CLIENT_NAME&background=random'" class="w-10 h-10 rounded-lg bg-white object-contain p-1">
                    <div class="absolute -bottom-1 -right-1 w-3 h-3 bg-green-500 rounded-full border-2 border-slate-900"></div>
                </div>
                <div>
                    <h2 class="font-bold text-sm truncate w-32 capitalize">$CLIENT_NAME</h2>
                    <p class="text-xs text-slate-400 capitalize">$INDUSTRY</p>
                </div>
            </div>

            <nav class="flex-1 p-4 space-y-2">
                <p class="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Principal</p>
                
                <a href="#" class="flex items-center gap-3 p-3 bg-blue-600 rounded-lg text-white shadow-lg shadow-blue-900/50 transition-all">
                    <i class="fa-solid fa-robot w-5"></i>
                    <span class="text-sm font-medium">Asistente IA</span>
                </a>

                <a href="#" class="flex items-center gap-3 p-3 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors">
                    <i class="fa-solid fa-chart-line w-5"></i>
                    <span class="text-sm font-medium">Dashboard</span>
                </a>

                <div id="module-payments" class="hidden">
                    <p class="text-xs font-semibold text-slate-500 uppercase tracking-wider mt-6 mb-2">Finanzas</p>
                    <a href="#" class="flex items-center gap-3 p-3 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors">
                        <i class="fa-solid fa-credit-card w-5"></i>
                        <span class="text-sm font-medium">Transacciones</span>
                    </a>
                </div>

                <div id="module-vip" class="hidden mt-4">
                     <div class="bg-gradient-to-r from-purple-600 to-indigo-600 p-4 rounded-xl shadow-lg">
                        <div class="flex items-center gap-2 text-white mb-1">
                            <i class="fa-solid fa-crown text-yellow-300"></i>
                            <span class="text-xs font-bold uppercase">Cliente VIP</span>
                        </div>
                        <p class="text-[10px] text-purple-100">Soporte prioritario activo y análisis predictivo habilitado.</p>
                     </div>
                </div>
            </nav>

            <div class="p-4 border-t border-slate-800">
                <div class="flex items-center gap-3">
                    <div class="w-8 h-8 rounded-full bg-slate-700 flex items-center justify-center text-xs">
                        <i class="fa-solid fa-user"></i>
                    </div>
                    <div class="flex-1">
                        <div class="text-xs font-medium">Admin</div>
                        <div class="text-[10px] text-green-400">● Sistema Online</div>
                    </div>
                </div>
            </div>
        </aside>

        <main class="flex-1 flex flex-col relative">
            
            <header class="bg-white h-16 border-b border-gray-200 flex items-center justify-between px-6 shadow-sm z-10">
                <div class="flex items-center gap-2 md:hidden">
                    <img src="$LOGO_URL" onerror="this.src='https://ui-avatars.com/api/?name=$CLIENT_NAME'" class="w-8 h-8 rounded">
                    <span class="font-bold text-gray-700">$CLIENT_NAME</span>
                </div>
                <div class="hidden md:block">
                    <h1 class="text-lg font-semibold text-gray-800">Centro de Control <span id="industry-label" class="text-gray-400 text-sm font-normal ml-2"></span></h1>
                </div>
                
                <div class="flex items-center gap-4">
                    <button class="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center text-gray-500 hover:bg-gray-200 transition">
                        <i class="fa-regular fa-bell"></i>
                    </button>
                    <div class="h-8 w-[1px] bg-gray-300"></div>
                    <span class="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded border border-gray-200">v2.4.0 (Stable)</span>
                </div>
            </header>

            <div id="chat-container" class="flex-1 p-6 overflow-y-auto space-y-6 bg-slate-50">
                <div class="flex items-start gap-4 max-w-3xl mx-auto">
                    <div class="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center border border-blue-200 flex-shrink-0">
                         <i class="fa-solid fa-robot text-blue-600"></i>
                    </div>
                    <div class="bg-white p-6 rounded-2xl rounded-tl-none shadow-sm border border-gray-100 text-gray-700 leading-relaxed">
                        <h3 class="font-bold text-gray-900 mb-2">¡Hola! Sistema iniciado.</h3>
                        <p>$WELCOME_MSG</p>
                    </div>
                </div>
            </div>

            <div class="p-4 bg-white border-t border-gray-200">
                <div class="max-w-3xl mx-auto relative">
                    <form id="chat-form" class="flex gap-4">
                        <input type="text" id="user-input" 
                            placeholder="Escribe tu consulta o comando para $CLIENT_NAME..." 
                            class="flex-1 bg-gray-50 border border-gray-200 text-gray-800 text-sm rounded-xl focus:ring-blue-500 focus:border-blue-500 block w-full p-4 shadow-inner outline-none transition-all">
                        <button type="submit" 
                            class="bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-xl text-sm px-6 py-2 transition-all shadow-lg shadow-blue-200 flex items-center gap-2">
                            <span>Enviar</span>
                            <i class="fa-solid fa-paper-plane"></i>
                        </button>
                    </form>
                    <p class="text-center text-[10px] text-gray-400 mt-2">Potenciado por IA & n8n Automation</p>
                </div>
            </div>
        </main>

        <script>
            // --- CONFIGURACIÓN DINÁMICA ---
            const CONFIG = {
                payments: "$ENABLE_PAYMENTS",
                vip: "$ENABLE_VIP",
                industry: "$INDUSTRY",
                logo: "$LOGO_URL",
                n8nUrl: "$N8N_URL",
                client: "$CLIENT_NAME"
            };

            // 1. Lógica de UI (Módulos)
            document.addEventListener('DOMContentLoaded', () => {
                // Activar módulo de pagos si corresponde
                if (CONFIG.payments === 'true') {
                    document.getElementById('module-payments').classList.remove('hidden');
                }
                
                // Activar módulo VIP si corresponde
                if (CONFIG.vip === 'true') {
                    document.getElementById('module-vip').classList.remove('hidden');
                }

                // Icono según industria
                const industryIcons = {
                    'Dental': '<i class="fa-solid fa-tooth"></i> Clínica',
                    'Tienda Online': '<i class="fa-solid fa-shop"></i> E-commerce',
                    'Consultora': '<i class="fa-solid fa-briefcase"></i> Servicios',
                    'default': '<i class="fa-solid fa-building"></i> Empresa'
                };
                
                const iconHtml = industryIcons[CONFIG.industry] || industryIcons['default'];
                document.getElementById('industry-label').innerHTML = iconHtml;
            });

            // 2. Lógica del Chat
            const form = document.getElementById('chat-form');
            const input = document.getElementById('user-input');
            const container = document.getElementById('chat-container');

            function addMessage(text, isUser) {
                const div = document.createElement('div');
                div.className = \`flex items-start gap-4 max-w-3xl mx-auto msg-bubble \${isUser ? 'flex-row-reverse' : ''}\`;
                
                // Avatar
                let avatarHtml = '';
                if (isUser) {
                    avatarHtml = \`<div class="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center text-gray-500 flex-shrink-0"><i class="fa-solid fa-user"></i></div>\`;
                } else {
                    avatarHtml = \`<div class="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 border border-blue-200 flex-shrink-0"><i class="fa-solid fa-robot"></i></div>\`;
                }

                // Burbuja
                const bubbleClass = isUser 
                    ? 'bg-blue-600 text-white rounded-tr-none shadow-md shadow-blue-100' 
                    : 'bg-white text-gray-700 border border-gray-100 rounded-tl-none shadow-sm';

                div.innerHTML = \`
                    \${avatarHtml}
                    <div class="\${bubbleClass} p-4 rounded-2xl text-sm leading-relaxed max-w-[80%]">
                        \${text}
                    </div>
                \`;
                
                container.appendChild(div);
                container.scrollTop = container.scrollHeight;
            }

            form.addEventListener('submit', async (e) => {
                e.preventDefault();
                const msg = input.value.trim();
                if (!msg) return;

                addMessage(msg, true);
                input.value = '';

                // Loader simulado pero elegante
                const loadingId = 'loading-' + Date.now();
                const loadingDiv = document.createElement('div');
                loadingDiv.id = loadingId;
                loadingDiv.className = "flex items-start gap-4 max-w-3xl mx-auto mt-4";
                loadingDiv.innerHTML = \`
                    <div class="w-10 h-10 rounded-full bg-blue-50 flex items-center justify-center border border-blue-100"><i class="fa-solid fa-circle-notch fa-spin text-blue-400"></i></div>
                    <div class="text-xs text-gray-400 py-3">Procesando en n8n...</div>
                \`;
                container.appendChild(loadingDiv);
                container.scrollTop = container.scrollHeight;

                try {
                    const response = await fetch(CONFIG.n8nUrl, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ 
                            message: msg, 
                            client: CONFIG.client,
                            industry: CONFIG.industry,
                            vip: CONFIG.vip
                        })
                    });
                    const data = await response.json();
                    document.getElementById(loadingId).remove();
                    addMessage(data.output || data.text || "Respuesta recibida.", false);
                } catch (err) {
                    console.error(err);
                    document.getElementById(loadingId).remove();
                    addMessage("⚠️ Error de conexión con el servidor central.", false);
                }
            });
        </script>
    </body>
    </html>
HTML

    # Reiniciar Nginx para servir el nuevo sitio
    systemctl restart nginx
  EOF
}

output "server_ip" { value = aws_instance.cliente_bot.public_ip }