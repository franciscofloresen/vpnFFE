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
if [ -f "$CLIENT_DIR/${NAME}.conf" ]; then
    echo "Error: Client $NAME already exists"
    exit 1
fi

# Generate keys with proper permissions
umask 077
wg genkey | tee $CLIENT_DIR/${NAME}_private.key | wg pubkey > $CLIENT_DIR/${NAME}_public.key

CLIENT_PRIV=$(cat $CLIENT_DIR/${NAME}_private.key)
CLIENT_PUB=$(cat $CLIENT_DIR/${NAME}_public.key)

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
cat > $CLIENT_DIR/${NAME}.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $CLIENT_IP
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

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
    qrencode -t ansiutf8 < $CLIENT_DIR/${NAME}.conf
fi

echo ""
echo "Client created: $CLIENT_DIR/${NAME}.conf"
echo "Client IP: $CLIENT_IP"
