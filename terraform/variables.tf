variable "VPC_IPS" {
  description = "Lista de rangos CIDR para las dos VPCs"
  type        = list(string)
}

variable "Subnet_VPC1" {
  description = "CIDR block para la subred pública de la VPC1"
  type        = string
}

variable "Subnet_VPC2_pub" {
  description = "CIDR block para la subred pública de la VPC2"
  type        = string
}

variable "Subnet_VPC2_priv" {
  description = "CIDR block para la subred privada de la VPC2"
  type        = string
}

variable "key_name" {
  description = "Nombre de la clave EC2 ya creada en AWS"
  type        = string
}

data "aws_key_pair" "arwen" {
  key_name = var.key_name
}