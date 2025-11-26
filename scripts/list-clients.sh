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
