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

resource "aws_instance" "ldap_instancia" {
  ami                    = "ami-064519b8c76274859" # Debian 12
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Subred_priv_vpc2.id
  key_name               = data.aws_key_pair.arwen.key_name
  vpc_security_group_ids = [aws_security_group.sg_ldap_instancia.id]
  depends_on             = [aws_nat_gateway.vpc2_nat_gateway]

  user_data = <<-EOF
#!/bin/bash
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
ENV LDAP_ADMIN_PASSWORD="laura1234"
ENV LDAP_READONLY_USER="true"
ENV LDAP_READONLY_USER_USERNAME="reader"
ENV LDAP_READONLY_USER_PASSWORD="reader_password"

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

docker exec ldap ldapadd -x -D "cn=admin,dc=laura,dc=local" -w laura1234 -f /tmp/bootstrap.ldif

docker exec ldap ldappasswd -x -D "cn=admin,dc=laura,dc=local" -w laura1234 -s "laura" "uid=laura,ou=users,dc=laura,dc=local"
docker exec ldap ldappasswd -x -D "cn=admin,dc=laura,dc=local" -w laura1234 -s "jose" "uid=jose,ou=users,dc=laura,dc=local"

docker stop ldap
docker start ldap

EOF

  tags = {
    Name = "LDAP"
  }
}


resource "aws_instance" "apache_instancia" {
  ami                         = "ami-064519b8c76274859" # Debian 12
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.Subred_pub_vpc2.id
  key_name                    = data.aws_key_pair.arwen.key_name
  associate_public_ip_address = true # Necesario para que Nginx pueda accederlo por IP pública si no están en la misma VPC o si el SG lo requiere
  vpc_security_group_ids      = [aws_security_group.apache_sg.id]
  depends_on                  = [aws_instance.ldap_instancia]

  user_data = <<-EOF
#!/bin/bash
sleep 50
apt update -y
apt install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker admin

# 2. Crear directorios y configuración para Apache
mkdir -p /opt/apache/conf.d /opt/apache/htdocs/secure_html

# 3. Configuración de autenticación LDAP para Apache
# Usamos la IP privada de la instancia LDAP
# El DN de Bind es el usuario 'reader' que creamos en el user_data de LDAP,
# es una mejor práctica no usar el admin DN para búsquedas de autenticación.
cat << 'APACHE_AUTH_CONF' > /opt/apache/conf.d/auth_ldap.conf
<Directory "/usr/local/apache2/htdocs/secure_html">
    AuthType Basic
    AuthName "Area Restringida - Login con LDAP"
    AuthBasicProvider ldap

    # LDAP URL: ldap://<ldap_server_ip>:<port>/<base_dn>?<uid_attribute_to_search_for_user>
    AuthLDAPURL "ldap://${aws_instance.ldap_instancia.private_ip}:389/ou=users,dc=laura,dc=local?uid" NONE

    # DN para hacer el bind (búsqueda) inicial. Usar un usuario con permisos de lectura.
    AuthLDAPBindDN "uid=reader,ou=system,dc=laura,dc=local"
    AuthLDAPBindPassword "reader_password"

    # Opcional: Si necesitas que el usuario pertenezca a un grupo específico
    # Require ldap-group cn=appusers,ou=groups,dc=laura,dc=local
    
    Require valid-user
</Directory>
APACHE_AUTH_CONF

echo "<h1>¡Bienvenido al Área Segura!</h1><p>Si ves esto, te has autenticado contra LDAP correctamente, ¡ji ji!</p>" > /opt/apache/htdocs/secure_html/index.html
echo "<h1>Página principal de Apache (no segura)</h1>" > /opt/apache/htdocs/index.html


# 5. Desplegar Apache en Docker
# La imagen httpd:2.4 ya incluye mod_ldap y mod_authnz_ldap
docker run -d --name apache_server \
  -p 80:80 \
  -v /opt/apache/conf.d:/usr/local/apache2/conf.d:ro \
  -v /opt/apache/htdocs:/usr/local/apache2/htdocs:ro \
  httpd:2.4-alpine 
  # Usamos alpine para una imagen más ligera, pero httpd:2.4 también funciona

echo "Servidor Apache configurado con autenticación LDAP."
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

  # Renderizamos el contenido de nginx.conf directamente aquí para asegurar el orden
  user_data = templatefile("${path.module}/nginx/user_data_nginx.sh.tftpl", {
    ssl_cert_pem          = var.ssl_cert_pem
    ssl_key_pem           = var.ssl_key_pem
    # Pasamos el contenido renderizado de nginx.conf a la plantilla del user_data
    nginx_conf_content    = templatefile("${path.module}/nginx/nginx.conf.tftpl", {
      apache_private_ip = aws_instance.apache_instancia.private_ip
    })
  })

  tags = {
    Name = "nginx"
  }
}