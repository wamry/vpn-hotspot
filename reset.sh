#!/bin/bash

echo "Stopping VPN + hotspot services..."
sudo systemctl stop vpnc hostapd dnsmasq 2>/dev/null || true
sudo systemctl disable vpnc hostapd dnsmasq 2>/dev/null || true

echo "Removing vpnc service + config..."
sudo rm -f /etc/systemd/system/vpnc.service
sudo rm -rf /etc/vpnc

echo "Removing hostapd override..."
sudo rm -rf /etc/systemd/system/hostapd.service.d

echo "Restoring dnsmasq config..."
sudo mv /etc/dnsmasq.conf.bak /etc/dnsmasq.conf 2>/dev/null || true

echo "Removing wlan0 static config..."
sudo sed -i '/interface wlan0/,+2d' /etc/dhcpcd.conf 2>/dev/null || true

echo "Flushing firewall + routing..."
sudo iptables -t nat -F
sudo iptables -F
sudo iptables -X
sudo ip rule flush
sudo ip route flush table vpn 2>/dev/null || true

echo "Removing routing table entry..."
sudo sed -i '/200 vpn/d' /etc/iproute2/rt_tables 2>/dev/null || true

echo "Re-enabling Wi-Fi client (wpa_supplicant)..."
sudo systemctl enable wpa_supplicant 2>/dev/null || true
sudo systemctl enable wpa_supplicant@wlan0 2>/dev/null || true
sudo systemctl start wpa_supplicant 2>/dev/null || true

echo "Reloading systemd..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo ""
echo "Reset complete."
echo "Reboot recommended."
