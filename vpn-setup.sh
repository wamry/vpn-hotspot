#!/bin/bash
set -e

echo "Installing VPNC..."
sudo apt update
sudo apt install -y vpnc

echo "Installing VPN config..."
sudo mkdir -p /etc/vpnc

# copy local default.conf → system location
sudo cp ./default.conf /etc/vpnc/default.conf
sudo chmod 600 /etc/vpnc/default.conf

echo "Creating vpnc systemd service..."

sudo tee /etc/systemd/system/vpnc.service > /dev/null <<'EOF'
[Unit]
Description=VPNC VPN connection
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStart=/usr/sbin/vpnc
ExecStop=/usr/sbin/vpnc-disconnect
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

echo ""
echo "VPN setup complete."
echo "Local file used: ./default.conf"
echo "Installed to: /etc/vpnc/default.conf"
