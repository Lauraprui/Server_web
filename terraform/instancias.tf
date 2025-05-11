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
output "ip_nginx" {
  value = aws_instance.nginx_instancia.public_ip
  description = "IP de Nginx"
}
output "ip_ldap" {
  value = aws_instance.ldap_instancia.private_ip
  description = "IP LDAP"
}

output "ip_apache" {
  value = aws_instance.apache_instancia.public_ip
  description = "IP apache"
}

resource "aws_instance" "ldap_instancia" {
  ami                    = "ami-064519b8c76274859" # Debian 12
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Subred_priv_vpc2.id
  key_name               = data.aws_key_pair.arwen.key_name
  vpc_security_group_ids = [aws_security_group.sg_ldap_instancia.id]
  depends_on             = [aws_nat_gateway.vpc2_nat_gateway]

  user_data = <<-EOF
#!/bin/bash
sleep 30
apt update -y
apt install -y docker.io ldap-utils
systemctl start docker
systemctl enable docker
usermod -aG docker admin

mkdir -p /home/admin/ldap

cat <<-EOT > /home/admin/ldap/Dockerfile

FROM osixia/openldap:1.5.0

# Variables de entorno
ENV LDAP_ORGANISATION="Laura LDAP"
ENV LDAP_DOMAIN="laura.local"
ENV LDAP_ADMIN_PASSWORD="admin"

COPY bootstrap.ldif /container/service/slapd/assets/config/bootstrap/ldif/02-custom-users.ldif
EOT

cat <<-BOOT > /home/admin/ldap/bootstrap.ldif
# Unidad organizativa para usuarios
dn: ou=users,dc=laura,dc=local
objectClass: top
objectClass: organizationalUnit
ou: users

dn: uid=laura,ou=users,dc=laura,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
cn: laura
sn: Bullejos
uid: laura
mail: laura@laura.local
userPassword: laura
uidNumber: 1001
gidNumber: 1001
homeDirectory: /home/ftp/
loginShell: /bin/bash

dn: uid=jose,ou=users,dc=laura,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
cn: jose
sn: Cortes
uid: jose
mail: jose@laura.local
userPassword: jose
uidNumber: 1002
gidNumber: 1002
homeDirectory: /home/ftp/
loginShell: /bin/bash

BOOT

cd /home/admin/ldap
docker build -t mildap .

docker run -d -p 389:389 --name ldap mildap
sleep 10

docker cp bootstrap.ldif ldap:/tmp

docker exec ldap ldapadd -x -D "cn=admin,dc=laura,dc=local" -w admin -f /tmp/bootstrap.ldif

docker exec ldap ldappasswd -x -D "cn=admin,dc=laura,dc=local" -w admin -s "laura" "uid=laura,ou=users,dc=laura,dc=local"
docker exec ldap ldappasswd -x -D "cn=admin,dc=laura,dc=local" -w admin -s "jose" "uid=jose,ou=users,dc=laura,dc=local"

docker stop ldap
docker start ldap

EOF

  tags = {
    Name = "LDAP"
  }
}


resource "aws_instance" "apache_instancia" {
  ami                         = "ami-064519b8c76274859" # Debian 12 (para el host EC2)
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.Subred_pub_vpc2.id
  key_name                    = data.aws_key_pair.arwen.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.apache_sg.id]
  depends_on                  = [aws_instance.ldap_instancia]

  user_data = <<EOF
#!/bin/bash
sleep 50
apt-get update -y
apt-get install -y docker.io

systemctl enable --now docker
usermod -aG docker admin

mkdir -p /opt/apache_host/conf.d /opt/apache_host/html/protected

cat > /opt/apache_host/html/index.html <<INDEX_HTML
<h1>Página principal de Apache (no segura)</h1>
<p>Accede a <a href="/protegido/">/protegido/</a> para autenticarte.</p>
INDEX_HTML

cat > /opt/apache_host/html/protected/index.html <<PROTECTED_HTML
<h1>¡Bienvenido al Area Super Protegida!</h1>
<p>Autenticacion LDAP contra Debian-Apache OK</p>
PROTECTED_HTML

cat > /opt/apache_host/conf.d/ldap.conf <<LDAP_CONF
# ServerName localhost

Alias /protegido /var/www/html/protected/

<Directory "/var/www/html/protected/">
    AuthType Basic
    AuthName "Acceso LDAP Protegido"
    AuthBasicProvider ldap
    AuthLDAPURL "ldap://${aws_instance.ldap_instancia.private_ip}:389/dc=laura,dc=local?uid" NONE
    AuthLDAPBindDN "cn=admin,dc=laura,dc=local"
    AuthLDAPBindPassword "admin"
    Require valid-user
</Directory>
LDAP_CONF

cat > /opt/apache_host/Dockerfile <<DOCKERFILE
FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y apache2  && \
    rm -rf /var/lib/apt/lists/*

RUN a2enmod ldap && \
    a2enmod authnz_ldap

COPY conf.d/ldap.conf /etc/apache2/conf-available/ldap-auth.conf
RUN a2enconf ldap-auth

COPY html/protected/index.html /var/www/html/protected/index.html
COPY html/index.html /var/www/html/index.html

EXPOSE 80

CMD ["apache2ctl", "-D", "FOREGROUND"]
DOCKERFILE

echo "Construyendo la imagen Docker apache..."
cd /opt/apache_host
docker build -t apache .

docker run -d --name apache_server_debian_ldap \
  --restart always \
  -p 80:80 \
  apache
EOF

  tags = {
    Name = "apache"
  }
}




resource "aws_instance" "nginx_instancia" {
  ami           = "ami-064519b8c76274859" # Debian 12
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.Subred_pub_vpc1.id
  key_name      = data.aws_key_pair.arwen.key_name
  vpc_security_group_ids = [aws_security_group.sg_nginx_instancia.id]
  depends_on    = [aws_instance.apache_instancia]

  user_data = templatefile("${path.module}/nginx/user_data_nginx.sh.tftpl", {
    ssl_cert_pem       = var.ssl_cert_pem
    ssl_key_pem        = var.ssl_key_pem
    nginx_conf_content = templatefile("${path.module}/nginx/nginx.conf.tftpl", {
      apache_private_ip = aws_instance.apache_instancia.private_ip
      apache_public_ip = aws_instance.apache_instancia.public_ip
    })
  })
  tags = {
    Name = "nginx"
  }
}