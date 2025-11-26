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
SERVER_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

mkdir -p $CLIENT_DIR

# Generate keys
wg genkey | tee $CLIENT_DIR/${NAME}_private.key | wg pubkey > $CLIENT_DIR/${NAME}_public.key

CLIENT_PRIV=$(cat $CLIENT_DIR/${NAME}_private.key)
CLIENT_PUB=$(cat $CLIENT_DIR/${NAME}_public.key)

# Assign incremental IP
IP_BASE="10.8.0."
LAST=$(ls $CLIENT_DIR/*.conf 2>/dev/null | wc -l)
CLIENT_IP="$IP_BASE$((LAST+2))/32"

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

# Add peer to server
wg set wg0 peer $CLIENT_PUB allowed-ips ${CLIENT_IP}
wg-quick save wg0

# Display QR code
if command -v qrencode >/dev/null; then
    echo ""
    echo "QR Code for mobile:"
    qrencode -t ansiutf8 < $CLIENT_DIR/${NAME}.conf
fi

echo ""
echo "Client created: $CLIENT_DIR/${NAME}.conf"
echo "Client IP: $CLIENT_IP"
