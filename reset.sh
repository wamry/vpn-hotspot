#!/bin/bash

echo "Stopping services..."
sudo systemctl stop vpnc hostapd dnsmasq 2>/dev/null

echo "Removing firewall rules..."
sudo iptables -t nat -F
sudo iptables -F
sudo ip rule flush
sudo ip route flush table vpn 2>/dev/null

echo "Removing VPN service..."
sudo rm -f /etc/systemd/system/vpnc.service
sudo rm -rf /etc/vpnc

echo "Restoring dnsmasq..."
sudo mv /etc/dnsmasq.conf.bak /etc/dnsmasq.conf 2>/dev/null || true

echo "Done. Reboot recommended."
