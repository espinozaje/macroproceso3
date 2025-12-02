terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    # Agregamos este proveedor para generar llaves SSH temporales
    tls = {
      source = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# --- 1. VARIABLES ---
variable "instance_size" { type = string } 
variable "client_id" { type = string }
variable "html_base64" { type = string } # El código gigante

provider "aws" {
  region = "us-east-1"
}

# --- 2. GENERACIÓN DE LLAVE SSH TEMPORAL ---
# Esto crea una llave digital para poder entrar al servidor
resource "tls_private_key" "temp_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key-${var.client_id}-${random_id.suffix.hex}"
  public_key = tls_private_key.temp_key.public_key_openssh
}

# --- 3. SEGURIDAD ---
resource "aws_security_group" "web_sg" {
  name = "secgroup-${var.client_id}-${random_id.suffix.hex}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # El puerto 22 (SSH) es OBLIGATORIO para esta estrategia
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

# --- 4. SERVIDOR (LA NUEVA LÓGICA) ---
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_size == "s-2vcpu-2gb" ? "t3.small" : "t2.micro"
  
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.deployer_key.key_name # Asignamos la llave
  
  tags = { Name = "SaaS-${var.client_id}" }

  # --- A. CONEXIÓN SSH ---
  # Terraform se prepara para entrar al servidor
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.temp_key.private_key_pem
    host        = self.public_ip
  }

  # --- B. INSTALACIÓN DE SOFTWARE ---
  # Primero instalamos Nginx vía comando remoto
  provisioner "remote-exec" {
    inline = [
      "sleep 15", # Esperar a que el sistema arranque bien
      "sudo apt-get update",
      "sudo apt-get install -y nginx coreutils",
      "sudo rm -rf /var/www/html/*"
    ]
  }

  # --- C. SUBIDA DEL CÓDIGO (EL BYPASS DEL LÍMITE) ---
  # Subimos el Base64 a un archivo temporal. Esto NO tiene límite de 16KB.
  provisioner "file" {
    content     = var.html_base64
    destination = "/tmp/website_encoded.txt"
  }

  # --- D. DECODIFICACIÓN Y DESPLIEGUE ---
  # Convertimos el archivo temporal en el HTML final
  provisioner "remote-exec" {
    inline = [
      # Decodificar Base64 y guardar en la carpeta de Nginx
      "base64 -d /tmp/website_encoded.txt | sudo tee /var/www/html/index.html",
      
      # Permisos y reinicio
      "sudo chown -R www-data:www-data /var/www/html",
      "sudo chmod 755 /var/www/html",
      "sudo systemctl restart nginx"
    ]
  }
}

output "server_ip" { value = aws_instance.app_server.public_ip }

# Agrega esto al final de main.tf
output "instance_id" {
  description = "ID de la instancia EC2 creada"
  value       = aws_instance.web_server.id
}