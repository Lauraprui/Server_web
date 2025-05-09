provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "VPC1" {
  cidr_block = var.VPC_IPS[0] # var para que coja la variable y [0] para que coja el primer elemento de la lista
  tags = {
    Name = "VPC 1 Terraform"
  }
}

resource "aws_vpc" "VPC2" {
  cidr_block = var.VPC_IPS[1]
  tags = {
    Name = "VPC 2 Terraform"
  }
}

# PEERING entre vpc1 y vpc2
resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id        = aws_vpc.VPC1.id
  peer_vpc_id   = aws_vpc.VPC2.id
  auto_accept   = true

  tags = {
    Name = "Peering de VPCs"
  }
}


# Rutas entre VPCs
resource "aws_route" "VPC1_a_VPC2" {
  route_table_id            = aws_vpc.VPC1.main_route_table_id
  destination_cidr_block    = aws_vpc.VPC2.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

resource "aws_route" "VPC2_a_VPC1" {
  route_table_id            = aws_vpc.VPC2.main_route_table_id
  destination_cidr_block    = aws_vpc.VPC1.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}


# Gateway VPC 1
resource "aws_internet_gateway" "gate_vpc_1" {
  vpc_id = aws_vpc.VPC1.id
  tags = {
    Name = "VPC 1 gate"
  }
}

# Gateway VPC 2
resource "aws_internet_gateway" "gate_vpc_2" {
  vpc_id = aws_vpc.VPC2.id
  tags = {
    Name = "VPC 2 gate"
  }
}


# Subnet Vpc1
resource "aws_subnet" "Subred_pub_vpc1" {
  vpc_id                  = aws_vpc.VPC1.id
  cidr_block              = var.Subnet_VPC1
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "Subred VPC 1"
  }
}

# Subredes VPC2
# ··· Subred pública ···
resource "aws_subnet" "Subred_pub_vpc2" {
  vpc_id                  = aws_vpc.VPC2.id
  cidr_block              = var.Subnet_VPC2_pub
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "Subred VPC 2 publica"
  }
}

# ··· Subred privada ···
resource "aws_subnet" "Subred_priv_vpc2" {
  vpc_id                  = aws_vpc.VPC2.id
  cidr_block              = var.Subnet_VPC2_priv
  availability_zone       = "us-east-1a"
  tags = {
    Name = "Subred VPC 2 privada"
  }
}

# Tabla de enrutamiento VPC1
resource "aws_route_table" "t_enru_vpc1" {
  vpc_id = aws_vpc.VPC1.id
  tags = {
    Name = "T_Enrutamiento VPC 1"
  }
}

# Tabla de enrutamiento VPC2
resource "aws_route_table" "t_enru_vpc2" {
  vpc_id = aws_vpc.VPC2.id
  tags = {
    Name = "T_Enrutamiento VPC 2"
  }
}

# Ruta predeterminada vpc1
resource "aws_route" "ruta_preder_vpc1" {
  route_table_id         = aws_route_table.t_enru_vpc1.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gate_vpc_1.id
}

# Ruta predeterminada vpc2
resource "aws_route" "ruta_preder_vpc2" {
  route_table_id         = aws_route_table.t_enru_vpc2.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gate_vpc_2.id
}

# Ruta privada vpc2 (sin internet)
resource "aws_route_table" "ruta_priv_vpc2" {
  vpc_id = aws_vpc.VPC2.id
  tags = {
    Name = "T_Enrutamiento Priv VPC 2"
  }
}

resource "aws_route" "private_route_vpc2_to_vpc1" {
  route_table_id            = aws_route_table.t_enru_vpc2.id
  destination_cidr_block    = var.Subnet_VPC1
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

resource "aws_route" "private_route_to_private_subnet_vpc_2" {
  route_table_id            = aws_route_table.t_enru_vpc1.id
  destination_cidr_block    = var.Subnet_VPC2_priv
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

# Asociación subred pub vpc1
resource "aws_route_table_association" "Subred_pub_asocia1" {
  subnet_id      = aws_subnet.Subred_pub_vpc1.id
  route_table_id = aws_route_table.t_enru_vpc1.id
}

# Asociación subred pub vpc2
resource "aws_route_table_association" "Subred_pub_asocia2" {
  subnet_id      = aws_subnet.Subred_pub_vpc2.id
  route_table_id = aws_route_table.t_enru_vpc2.id
}

# Asociación subred priv vpc2
resource "aws_route_table_association" "Subred_priv_asocia2" {
  subnet_id      = aws_subnet.Subred_priv_vpc2.id
  route_table_id = aws_route_table.t_enru_vpc2.id
}

# Crear una Elastic IP para el NAT Gateway de la VPC 2
resource "aws_eip" "nat_eip_vpc_2" {
  domain = "vpc"
  tags = {
    Name = "NAT EIP VPC 2"
  }
}

# Crear el NAT Gateway asociado con la Elastic IP en la subred pública de la VPC 2
resource "aws_nat_gateway" "nat_gateway_vpc_2" {
  allocation_id = aws_eip.nat_eip_vpc_2.id
  subnet_id     = aws_subnet.Subred_pub_vpc2.id

  tags = {
    Name = "NAT Gateway VPC 2"
  }
  depends_on = [aws_eip.nat_eip_vpc_2] # Asegura que la Elastic IP esté creada antes del NAT Gateway
}

# Configurar una ruta predeterminada en la tabla de enrutamiento privada de la VPC 2 hacia el NAT Gateway
resource "aws_route" "private_route_vpc_2_to_nat" {
  route_table_id         = aws_route_table.ruta_priv_vpc2.id
  destination_cidr_block = "0.0.0.0/0" # Rutas hacia cualquier dirección
  nat_gateway_id         = aws_nat_gateway.nat_gateway_vpc_2.id

  depends_on = [aws_nat_gateway.nat_gateway_vpc_2] # Asegura que el NAT Gateway esté creado antes de agregar la ruta
}

# Crear una Elastic IP adicional para otro NAT Gateway (si es necesario)
resource "aws_eip" "vpc2_nat_eip" {
  domain = "vpc"
}

# Crear un segundo NAT Gateway asociado a la nueva Elastic IP en la subred pública de la VPC 2
resource "aws_nat_gateway" "vpc2_nat_gateway" {
  allocation_id = aws_eip.vpc2_nat_eip.id
  subnet_id     = aws_subnet.Subred_pub_vpc2.id
}
