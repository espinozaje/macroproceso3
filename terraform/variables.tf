variable "client_id" {
  description = "ID único del cliente (sin espacios)"
  type        = string
}

variable "instance_size" {
  description = "Tamaño del servidor (t3.micro o s-1vcpu-1gb)"
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "welcome_msg" {
  type = string
}

variable "enable_payments" {
  type = string
}

variable "enable_vip" {
  type = string
}