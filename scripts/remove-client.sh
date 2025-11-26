#!/bin/bash
set -e

NAME=$1

if [ -z "$NAME" ]; then
    echo "Usage: remove-client.sh <client-name>"
    exit 1
fi

CLIENT_DIR="/opt/wireguard/clients"
CLIENT_CONF="$CLIENT_DIR/${NAME}.conf"

if [ ! -f "$CLIENT_CONF" ]; then
    echo "Error: Client $NAME not found"
    exit 1
fi

# Get client public key
CLIENT_PUB=$(cat $CLIENT_DIR/${NAME}_public.key)

# Remove peer block from config (blank line + [Peer] + PublicKey + AllowedIPs)
sed -i "/^\$/,/^AllowedIPs.*/{/PublicKey = $CLIENT_PUB/{g;N;N;d}}" /etc/wireguard/wg0.conf 2>/dev/null || \
    grep -v -A2 "PublicKey = $CLIENT_PUB" /etc/wireguard/wg0.conf > /tmp/wg0.conf.tmp && mv /tmp/wg0.conf.tmp /etc/wireguard/wg0.conf

# Remove client files
rm -f $CLIENT_DIR/${NAME}*

# Reload WireGuard
systemctl restart wg-quick@wg0

echo "Client $NAME removed successfully"
