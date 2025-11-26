terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# --------------------------
# DATA SOURCES
# --------------------------
data "aws_ami" "ubuntu_arm" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --------------------------
# VPC
# --------------------------
resource "aws_vpc" "vpn_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "vpn-vpc" }
}

resource "aws_subnet" "vpn_public_subnet" {
  vpc_id                  = aws_vpc.vpn_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.az
  tags = { Name = "vpn-public-subnet" }
}

resource "aws_internet_gateway" "vpn_igw" {
  vpc_id = aws_vpc.vpn_vpc.id
}

resource "aws_route_table" "vpn_public_rt" {
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpn_igw.id
  }

  tags = { Name = "vpn-public-rt" }
}

resource "aws_route_table_association" "vpn_rt_assoc" {
  subnet_id      = aws_subnet.vpn_public_subnet.id
  route_table_id = aws_route_table.vpn_public_rt.id
}

# --------------------------
# SECURITY GROUP
# --------------------------
resource "aws_security_group" "vpn_sg" {
  name        = "vpn-sg"
  description = "Allow WireGuard UDP"
  vpc_id      = aws_vpc.vpn_vpc.id

  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Optional SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_ip == "" ? [] : [var.ssh_allowed_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vpn-sg" }
}

# --------------------------
# EC2
# --------------------------
resource "aws_instance" "vpn_ec2" {
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu_arm.id
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.vpn_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.vpn_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
#!/bin/bash
set -e

# Install WireGuard and dependencies
apt update && apt install -y wireguard qrencode

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Create directory structure
mkdir -p /opt/wireguard/clients /opt/wireguard/scripts

# Generate server keys with proper permissions
umask 077
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key
cp /etc/wireguard/server_public.key /opt/wireguard/server_public.key

SERVER_PRIV=$(cat /etc/wireguard/server_private.key)

# Detect primary network interface
IFACE=$(ip route | grep default | awk '{print $5}')

# Create WireGuard config
cat > /etc/wireguard/wg0.conf <<CONFIG
[Interface]
PrivateKey = $SERVER_PRIV
Address = 10.8.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $IFACE -j MASQUERADE
CONFIG

# Create client management script
cat > /opt/wireguard/scripts/create-client.sh <<'SCRIPT'
#!/bin/bash
set -e

NAME=$1

if [ -z "$NAME" ]; then
    echo "Usage: create-client.sh <client-name>"
    exit 1
fi

BASE_DIR="/opt/wireguard"
CLIENT_DIR="$BASE_DIR/clients"
SERVER_PUB=$(cat $BASE_DIR/server_public.key)

# IMDSv2 token
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
SERVER_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

mkdir -p $CLIENT_DIR

# Check if client already exists
if [ -f "$CLIENT_DIR/$${NAME}.conf" ]; then
    echo "Error: Client $NAME already exists"
    exit 1
fi

# Generate keys with proper permissions
umask 077
wg genkey | tee $CLIENT_DIR/$${NAME}_private.key | wg pubkey > $CLIENT_DIR/$${NAME}_public.key

CLIENT_PRIV=$(cat $CLIENT_DIR/$${NAME}_private.key)
CLIENT_PUB=$(cat $CLIENT_DIR/$${NAME}_public.key)

# Assign incremental IP based on highest existing IP
IP_BASE="10.8.0."
HIGHEST=1
for conf in $CLIENT_DIR/*.conf; do
    [ -f "$conf" ] || continue
    IP=$(grep "^Address" "$conf" | awk '{print $3}' | cut -d'/' -f1 | cut -d'.' -f4)
    [ "$IP" -gt "$HIGHEST" ] && HIGHEST=$IP
done
CLIENT_NUM=$((HIGHEST+1))
CLIENT_IP="$IP_BASE$CLIENT_NUM/32"

# Create client config
cat > $CLIENT_DIR/$${NAME}.conf <<CONF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $CLIENT_IP
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CONF

# Add peer to server config file (persistent)
cat >> /etc/wireguard/wg0.conf <<PEER

[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = $CLIENT_IP
PEER

# Reload WireGuard
systemctl restart wg-quick@wg0

# Display QR code
if command -v qrencode >/dev/null; then
    echo ""
    echo "QR Code for mobile:"
    qrencode -t ansiutf8 < $CLIENT_DIR/$${NAME}.conf
fi

echo ""
echo "Client created: $CLIENT_DIR/$${NAME}.conf"
echo "Client IP: $CLIENT_IP"
SCRIPT

chmod +x /opt/wireguard/scripts/create-client.sh

# Create list clients script
cat > /opt/wireguard/scripts/list-clients.sh <<'SCRIPT'
#!/bin/bash
echo "=== Active WireGuard Connections ==="
wg show

echo ""
echo "=== Configured Clients ==="
CLIENT_DIR="/opt/wireguard/clients"
if [ -d "$CLIENT_DIR" ]; then
    for conf in $CLIENT_DIR/*.conf; do
        [ -f "$conf" ] || continue
        NAME=$(basename "$conf" .conf)
        IP=$(grep "^Address" "$conf" | awk '{print $3}')
        echo "  - $NAME: $IP"
    done
else
    echo "  No clients configured"
fi
SCRIPT

chmod +x /opt/wireguard/scripts/list-clients.sh

# Create remove client script
cat > /opt/wireguard/scripts/remove-client.sh <<'SCRIPT'
#!/bin/bash
set -e

NAME=$1

if [ -z "$NAME" ]; then
    echo "Usage: remove-client.sh <client-name>"
    exit 1
fi

CLIENT_DIR="/opt/wireguard/clients"
CLIENT_CONF="$CLIENT_DIR/$${NAME}.conf"

if [ ! -f "$CLIENT_CONF" ]; then
    echo "Error: Client $NAME not found"
    exit 1
fi

# Get client public key
CLIENT_PUB=$(cat $CLIENT_DIR/$${NAME}_public.key)

# Remove peer block from config (blank line + [Peer] + PublicKey + AllowedIPs)
sed -i "/^\$/,/^AllowedIPs.*/{/PublicKey = $CLIENT_PUB/{g;N;N;d}}" /etc/wireguard/wg0.conf 2>/dev/null || \
    grep -v -A2 "PublicKey = $CLIENT_PUB" /etc/wireguard/wg0.conf > /tmp/wg0.conf.tmp && mv /tmp/wg0.conf.tmp /etc/wireguard/wg0.conf

# Remove client files
rm -f $CLIENT_DIR/$${NAME}*

# Reload WireGuard
systemctl restart wg-quick@wg0

echo "Client $NAME removed successfully"
SCRIPT

chmod +x /opt/wireguard/scripts/remove-client.sh

# Start WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

EOF

  tags = { Name = "wireguard-vpn" }
}