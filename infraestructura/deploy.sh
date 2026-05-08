#!/bin/bash
# =============================================================================
# deploy.sh — Infraestructura AWS para Café Volcán
# Laboratorio Práctico 1 — FDICI12 — Universidad de Los Lagos
# =============================================================================
# Este script crea toda la infraestructura desde cero usando AWS CLI.
# Ejecutar con: bash deploy.sh
# Requisitos: AWS CLI configurado con credenciales válidas
# =============================================================================

set -e  # Detener el script si algún comando falla

echo "=========================================="
echo " Desplegando infraestructura Café Volcán"
echo "=========================================="

# =============================================================================
# BLOQUE 1 — VPC
# Creamos una VPC con CIDR 10.0.0.0/16 que nos da 65.536 IPs disponibles.
# Este rango es el estándar recomendado para VPCs en producción.
# Habilitamos DNS hostnames para que las instancias tengan nombres DNS públicos.
# =============================================================================
echo "[1/8] Creando VPC..."

VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' \
  --output text)

aws ec2 create-tags \
  --resources $VPC_ID \
  --tags Key=Name,Value=vpc-cafe-volcan

aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames

echo "VPC creada: $VPC_ID"

# =============================================================================
# BLOQUE 2 — SUBREDES
# Creamos dos subredes en zonas de disponibilidad distintas (us-east-1a y 1b)
# para garantizar alta disponibilidad.
# - Subred pública (10.0.1.0/24): aloja la EC2 con servidor web, accesible
#   desde Internet. Se habilita auto-asignación de IP pública.
# - Subred privada (10.0.2.0/24): aislada de Internet, para recursos internos
#   como bases de datos (buena práctica de seguridad).
# =============================================================================
echo "[2/8] Creando subredes..."

SUBNET_PUB=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 create-tags \
  --resources $SUBNET_PUB \
  --tags Key=Name,Value=subnet-publica-cafe-volcan

aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_PUB \
  --map-public-ip-on-launch

SUBNET_PRV=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1b \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 create-tags \
  --resources $SUBNET_PRV \
  --tags Key=Name,Value=subnet-privada-cafe-volcan

echo "Subred publica: $SUBNET_PUB"
echo "Subred privada: $SUBNET_PRV"

# =============================================================================
# BLOQUE 3 — INTERNET GATEWAY
# El IGW es la puerta de enlace entre la VPC y el Internet público.
# Sin él, ningún recurso dentro de la VPC puede comunicarse con el exterior.
# Se debe adjuntar explícitamente a la VPC después de crearlo.
# =============================================================================
echo "[3/8] Creando Internet Gateway..."

IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 create-tags \
  --resources $IGW_ID \
  --tags Key=Name,Value=igw-cafe-volcan

aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID

echo "Internet Gateway: $IGW_ID"

# =============================================================================
# BLOQUE 4 — TABLA DE RUTEO
# La tabla de ruteo define cómo se enruta el tráfico dentro de la VPC.
# - Ruta 0.0.0.0/0 → IGW: todo el tráfico externo sale por el Internet Gateway.
# - Solo la subred pública se asocia a esta tabla.
# - La subred privada usa la tabla de ruteo default (sin ruta a Internet).
# =============================================================================
echo "[4/8] Configurando tablas de ruteo..."

RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-tags \
  --resources $RT_ID \
  --tags Key=Name,Value=rt-publica-cafe-volcan

aws ec2 create-route \
  --route-table-id $RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 associate-route-table \
  --route-table-id $RT_ID \
  --subnet-id $SUBNET_PUB

echo "Route Table: $RT_ID"

# =============================================================================
# BLOQUE 5 — SECURITY GROUP
# Aplicamos el principio de mínimo privilegio:
# - Puerto 80 (HTTP) abierto a 0.0.0.0/0: necesario para que cualquier
#   visitante pueda acceder al sitio web públicamente.
# - Puerto 22 (SSH) restringido a la IP del administrador (/32): solo el
#   administrador puede conectarse remotamente. Abrir SSH a 0.0.0.0/0
#   sería una vulnerabilidad crítica de seguridad.
# - Todo el tráfico restante está denegado implícitamente.
# =============================================================================
echo "[5/8] Configurando Security Group..."

MY_IP="190.5.45.155"  # IP del administrador — actualizar si cambia

SG_ID=$(aws ec2 create-security-group \
  --group-name "cafe-volcan-sg" \
  --description "Security Group Cafe Volcan" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

aws ec2 create-tags \
  --resources $SG_ID \
  --tags Key=Name,Value=cafe-volcan-sg

# Regla 1: HTTP público para el sitio web
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Regla 2: SSH restringido solo al administrador
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_IP}/32

echo "Security Group: $SG_ID"

# =============================================================================
# BLOQUE 6 — KEY PAIR
# Par de claves SSH para acceso seguro a la instancia EC2.
# La clave privada se guarda localmente y nunca debe compartirse.
# =============================================================================
echo "[6/8] Creando Key Pair..."

aws ec2 create-key-pair \
  --key-name cafe-volcan-key \
  --query 'KeyMaterial' \
  --output text > cafe-volcan-key.pem

chmod 400 cafe-volcan-key.pem

echo "Key Pair creado: cafe-volcan-key.pem"

# =============================================================================
# BLOQUE 7 — INSTANCIA EC2
# - AMI: Ubuntu 24.04 LTS (ami-0e86e20dae9224db8) en us-east-1
# - Tipo: t3.micro (free tier, 2 vCPU, 1GB RAM) — suficiente para sitio web
#   estático con tráfico moderado.
# - User Data: script de inicialización que instala Apache automáticamente
#   al lanzar la instancia.
# - Se lanza en la subred pública para ser accesible desde Internet.
# =============================================================================
echo "[7/8] Lanzando instancia EC2..."

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0e86e20dae9224db8 \
  --instance-type t3.micro \
  --key-name cafe-volcan-key \
  --subnet-id $SUBNET_PUB \
  --security-group-ids $SG_ID \
  --associate-public-ip-address \
  --user-data '#!/bin/bash
apt-get update -y
apt-get install -y apache2
systemctl start apache2
systemctl enable apache2
mkdir -p /mnt/datos/sitio-web
chmod 755 /mnt/datos
chown ubuntu:ubuntu /mnt/datos' \
  --query 'Instances[0].InstanceId' \
  --output text)

aws ec2 create-tags \
  --resources $INSTANCE_ID \
  --tags Key=Name,Value=ec2-cafe-volcan

echo "Esperando que la instancia este running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Instancia EC2: $INSTANCE_ID"
echo "IP Publica: $PUBLIC_IP"

# =============================================================================
# BLOQUE 8 — VOLUMEN EBS
# Creamos un volumen EBS adicional de 8GB (gp3) separado del volumen raíz.
# Esto implementa la buena práctica de separar el SO de los datos de la app.
# - gp3: tipo SSD de propósito general, mejor relación costo/rendimiento.
# - Debe estar en la misma AZ que la instancia EC2 (us-east-1a).
# - Se formatea con ext4 y se monta en /mnt/datos para los archivos del sitio.
# =============================================================================
echo "[8/8] Creando y adjuntando volumen EBS..."

VOL_ID=$(aws ec2 create-volume \
  --size 8 \
  --volume-type gp3 \
  --availability-zone us-east-1a \
  --query 'VolumeId' \
  --output text)

aws ec2 create-tags \
  --resources $VOL_ID \
  --tags Key=Name,Value=ebs-cafe-volcan

aws ec2 wait volume-available --volume-ids $VOL_ID

aws ec2 attach-volume \
  --volume-id $VOL_ID \
  --instance-id $INSTANCE_ID \
  --device /dev/xvdf

echo "Volumen EBS: $VOL_ID"

# =============================================================================
# RESUMEN FINAL
# =============================================================================
echo ""
echo "=========================================="
echo " Infraestructura desplegada exitosamente"
echo "=========================================="
echo "VPC:            $VPC_ID"
echo "Subred publica: $SUBNET_PUB"
echo "Subred privada: $SUBNET_PRV"
echo "Internet GW:    $IGW_ID"
echo "Route Table:    $RT_ID"
echo "Security Group: $SG_ID"
echo "Instancia EC2:  $INSTANCE_ID"
echo "Volumen EBS:    $VOL_ID"
echo "Sitio web:      http://$PUBLIC_IP"
echo "=========================================="
echo ""
echo "PASOS MANUALES POST-DEPLOY:"
echo "1. ssh -i cafe-volcan-key.pem ubuntu@$PUBLIC_IP"
echo "2. sudo mkfs -t ext4 /dev/nvme1n1"
echo "3. sudo mount /dev/nvme1n1 /mnt/datos"
echo "4. Subir archivos del sitio a /mnt/datos/sitio-web/"
echo "=========================================="