# IP Elastica
#resource "aws_eip" "ip_elastica_nginx" {
 # instance = aws_instance.nginx_instancia.id

 # tags = {
 #   Name = "EIP nginx"
 # }
#}

# Asociar IP Elastica
#resource "aws_eip_association" "asociar_ip_elastica" {
 # instance_id   = aws_instance.nginx_instancia.id
 # allocation_id = aws_eip.ip_elastica_nginx.id
#}

# Grupo seguridad apache
resource "aws_security_group" "apache_sg" {
  name   = "apache_sg"
  vpc_id = aws_vpc.VPC2.id

   # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  # SSH
  ingress {
    description      = "Allow SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Grupo seguridad para Apache"
  }
}

resource "aws_security_group" "sg_nginx_instancia" {
  vpc_id = aws_vpc.VPC1.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Trafico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Grupo de seguridad para Nginx"
  }
}

resource "aws_security_group" "sg_ldap_instancia" {
  vpc_id = aws_vpc.VPC2.id

  # Ldap
  ingress {
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Trafico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Grupo de seguridad para LDAP"
  }
}

# Que salga la ip elástica de nginx
#output "ip_elastica_nginx" {
 # value = aws_eip.ip_elastica_nginx.public_ip
 # description = "IP Elastica del nginx"
#}

output "ip_nginx" {
  value = aws_instance.nginx_instancia.public_ip
  description = "IP de Nginx"
}
# Que salga la ip elástica de LDAP
output "ip_ldap" {
  value = aws_instance.ldap_instancia.private_ip
  description = "IP LDAP"
}

output "ip_apache" {
  value = aws_instance.apache_instancia.public_ip
  description = "IP apache"
}


resource "aws_instance" "apache_instancia" {
  ami                    = "ami-064519b8c76274859"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Subred_pub_vpc2.id
  #key_name               = "laura-terraform"
  key_name = data.aws_key_pair.arwen.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.apache_sg.id]

  user_data = <<-EOF
#!/bin/bash
apt update -y
  EOF

  tags = {
    Name = "apache"
  }
}


# AMI nginx y docker
resource "aws_instance" "nginx_instancia" {
  ami           = "ami-064519b8c76274859" # Debian 12
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.Subred_pub_vpc1.id
  #key_name      = "laura-terraform"
  key_name = data.aws_key_pair.arwen.key_name


  depends_on = [ aws_instance.ldap_instancia ]
  vpc_security_group_ids = [aws_security_group.sg_nginx_instancia.id]

  tags = {
    Name = "nginx"
  }

}


resource "aws_instance" "ldap_instancia" {
  ami           = "ami-064519b8c76274859" # Debian 12
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.Subred_priv_vpc2.id
  #key_name      = "laura-terraform"
  key_name = data.aws_key_pair.arwen.key_name

  depends_on = [aws_nat_gateway.vpc2_nat_gateway]
  vpc_security_group_ids = [aws_security_group.sg_ldap_instancia.id]
  user_data = <<-EOF
#!/bin/bash
apt update -y
  EOF
  tags = {
    Name = "LDAP"
  }

}