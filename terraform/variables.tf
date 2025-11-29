variable "client_id" {
  description = "ID único del cliente (sin espacios)"
  type        = string
}

variable "instance_size" {
  description = "Tamaño del servidor (t2.micro para gratis, t3.medium para VIP)"
  type        = string
  default     = "t2.micro"
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