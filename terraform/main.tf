terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# --- 1. VARIABLES QUE RECIBIMOS DE GITHUB ACTIONS (Vienen de tu n8n) ---
variable "client_id" { type = string }       # ej: clinica-dental-123
variable "industry" { type = string }        # ej: Dental
variable "welcome_msg" { type = string }     # ej: "Bienvenido doctor..."
variable "logo_url" { type = string }        # URL de Supabase
variable "enable_payments" { type = string } # "true" o "false"
variable "enable_vip" { type = string }      # "true" o "false" (Mapear desde ENABLE_VIP_SCORING)
variable "n8n_chat_url" { 
  type = string 
  # Pon aquí tu Webhook de n8n para el chat (No el de despliegue)
  default = "https://TU-URL-N8N.trycloudflare.com/webhook/chat-bot" 
}

provider "aws" {
  region = "us-east-1"
}

# --- 2. SEGURIDAD (Abrimos puerto 80 para ver la web) ---
resource "aws_security_group" "web_sg" {
  name = "sg-${var.client_id}-${random_id.suffix.hex}"

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

# --- 3. EL SERVIDOR (LA FÁBRICA DEL SISTEMA) ---
# 3. EL SERVIDOR (LA FÁBRICA DEL SISTEMA)
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro" 
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = { Name = "SaaS-${var.client_id}" }

  # --- CORRECCIÓN APLICADA: Variables JS escapadas con $$ ---
  user_data = <<-EOF
    #!/bin/bash
    
    # Instalar servidor web
    apt-get update && apt-get install -y nginx

    # 1. Terraform inyecta valores aquí (Un solo $):
    CLIENT="${var.client_id}"
    INDUSTRY="${var.industry}"
    LOGO="${var.logo_url}"
    MSG="${var.welcome_msg}"
    PAYMENTS="${var.enable_payments}" 
    VIP="${var.enable_vip}"           
    CHAT_URL="${var.n8n_chat_url}"

    # 2. Generamos el HTML (Usamos variables de Bash $CLIENT, etc)
    cat <<HTML > /var/www/html/index.html
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Panel de Control | $CLIENT</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
        <style>
            body { font-family: 'Inter', sans-serif; }
            .glass { background: rgba(255, 255, 255, 0.95); backdrop-filter: blur(10px); }
            .message-appear { animation: slideUp 0.3s ease-out; }
            @keyframes slideUp { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
        </style>
    </head>
    <body class="bg-slate-100 h-screen flex overflow-hidden">

        <aside class="w-64 bg-slate-900 text-white flex flex-col shadow-2xl z-20">
            <div class="h-20 flex items-center gap-3 px-6 border-b border-slate-800">
                <img src="$LOGO" 
                     onerror="this.src='https://ui-avatars.com/api/?name=$CLIENT&background=3b82f6&color=fff&bold=true'" 
                     class="w-10 h-10 rounded-lg bg-white object-contain p-1">
                <div>
                    <h1 class="font-bold text-sm tracking-wide capitalize truncate w-32">$CLIENT</h1>
                    <span class="text-[10px] text-slate-400 uppercase tracking-wider">$INDUSTRY</span>
                </div>
            </div>

            <nav class="flex-1 px-4 py-6 space-y-2">
                <a href="#" class="flex items-center gap-3 px-4 py-3 bg-blue-600 rounded-xl text-white shadow-lg shadow-blue-900/50 transition-transform hover:scale-[1.02]">
                    <i class="fa-solid fa-robot w-5"></i>
                    <span class="font-medium text-sm">Asistente IA</span>
                </a>
                
                <a href="#" class="flex items-center gap-3 px-4 py-3 text-slate-400 hover:text-white hover:bg-slate-800 rounded-xl transition-colors">
                    <i class="fa-solid fa-chart-pie w-5"></i>
                    <span class="font-medium text-sm">Estadísticas</span>
                </a>

                <div id="menu-payments" class="hidden">
                    <p class="mt-6 mb-2 px-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest">Finanzas</p>
                    <a href="#" class="flex items-center gap-3 px-4 py-3 text-slate-400 hover:text-white hover:bg-slate-800 rounded-xl transition-colors">
                        <i class="fa-solid fa-wallet w-5"></i>
                        <span class="font-medium text-sm">Transacciones</span>
                    </a>
                </div>
            </nav>

            <div id="badge-vip" class="hidden p-4">
                <div class="bg-gradient-to-r from-amber-200 to-yellow-500 rounded-xl p-4 text-slate-900 shadow-lg">
                    <div class="flex items-center gap-2 mb-1">
                        <i class="fa-solid fa-crown text-slate-900"></i>
                        <span class="font-bold text-xs uppercase">Cuenta VIP</span>
                    </div>
                    <p class="text-[10px] font-medium opacity-80 leading-tight">Soporte prioritario activo.</p>
                </div>
            </div>

            <div class="p-4 border-t border-slate-800">
                <div class="flex items-center gap-3">
                    <div class="w-8 h-8 rounded-full bg-slate-700 flex items-center justify-center text-xs">AD</div>
                    <div class="flex-col flex">
                        <span class="text-xs font-semibold">Admin User</span>
                        <span class="text-[10px] text-green-500">● Sistema Online</span>
                    </div>
                </div>
            </div>
        </aside>

        <main class="flex-1 flex flex-col relative">
            <header class="h-20 bg-white border-b border-slate-200 flex items-center justify-between px-8">
                <h2 class="text-xl font-bold text-slate-800">Centro de Comando</h2>
                <div class="flex gap-4">
                    <button class="w-10 h-10 rounded-full bg-slate-50 border border-slate-200 text-slate-500 hover:bg-slate-100">
                        <i class="fa-regular fa-bell"></i>
                    </button>
                </div>
            </header>

            <div id="chat-box" class="flex-1 overflow-y-auto p-8 space-y-6 bg-slate-50">
                <div class="flex gap-4 max-w-3xl mx-auto">
                    <div class="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 flex-shrink-0 border border-blue-200">
                        <i class="fa-solid fa-robot"></i>
                    </div>
                    <div class="bg-white p-6 rounded-2xl rounded-tl-none shadow-sm border border-slate-100 text-slate-600 text-sm leading-relaxed">
                        <p class="font-bold text-slate-900 mb-2 block">Sistema Iniciado</p>
                        $MSG
                    </div>
                </div>
            </div>

            <div class="p-6 bg-white border-t border-slate-200">
                <form id="chat-form" class="max-w-3xl mx-auto relative flex gap-4">
                    <input type="text" id="user-input" placeholder="Escribe tu consulta o comando..." 
                        class="flex-1 bg-slate-50 border border-slate-200 rounded-xl px-5 py-4 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition-all shadow-inner">
                    <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white px-8 rounded-xl font-medium transition-colors shadow-lg shadow-blue-200">
                        <i class="fa-solid fa-paper-plane"></i>
                    </button>
                </form>
            </div>
        </main>

        <script>
            // CONFIGURACIÓN DINÁMICA
            const config = {
                payments: "$PAYMENTS",
                vip: "$VIP",
                n8n: "$CHAT_URL"
            };

            if (config.payments === 'true') {
                document.getElementById('menu-payments').classList.remove('hidden');
            }
            if (config.vip === 'true') {
                document.getElementById('badge-vip').classList.remove('hidden');
            }

            const form = document.getElementById('chat-form');
            const input = document.getElementById('user-input');
            const box = document.getElementById('chat-box');

            function addMsg(text, isUser) {
                const div = document.createElement('div');
                // NOTA: Aquí usamos doble $$ para que Terraform NO intente interpretarlo
                // y se escriba como un template literal de JS en el archivo final.
                div.className = `flex gap-4 max-w-3xl mx-auto message-appear $${isUser ? 'flex-row-reverse' : ''}`;
                
                const avatar = isUser 
                    ? '<div class="w-10 h-10 rounded-full bg-slate-200 flex items-center justify-center text-slate-500 flex-shrink-0"><i class="fa-solid fa-user"></i></div>'
                    : '<div class="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 flex-shrink-0 border border-blue-200"><i class="fa-solid fa-robot"></i></div>';

                const bubble = isUser
                    ? 'bg-blue-600 text-white rounded-tr-none shadow-md shadow-blue-100'
                    : 'bg-white text-slate-600 border border-slate-100 rounded-tl-none shadow-sm';

                div.innerHTML = `
                    $${avatar}
                    <div class="$${bubble} p-5 rounded-2xl text-sm leading-relaxed max-w-[80%]">
                        $${text}
                    </div>
                `;
                box.appendChild(div);
                box.scrollTop = box.scrollHeight;
            }

            form.addEventListener('submit', async (e) => {
                e.preventDefault();
                const text = input.value.trim();
                if(!text) return;

                addMsg(text, true);
                input.value = '';

                const loadId = 'load-' + Date.now();
                const loader = document.createElement('div');
                loader.id = loadId;
                loader.className = 'flex gap-4 max-w-3xl mx-auto mt-4';
                loader.innerHTML = '<div class="w-10 h-10"></div><div class="text-xs text-slate-400 italic">Procesando...</div>';
                box.appendChild(loader);

                try {
                    const res = await fetch(config.n8n, {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({ message: text })
                    });
                    const data = await res.json();
                    document.getElementById(loadId).remove();
                    addMsg(data.output || "Comando recibido.", false);
                } catch(err) {
                    document.getElementById(loadId).remove();
                    addMsg("Error de conexión con el núcleo.", false);
                }
            });
        </script>
    </body>
    </html>
HTML
    systemctl restart nginx
  EOF
}

output "ip_sistema" { value = aws_instance.app_server.public_ip }