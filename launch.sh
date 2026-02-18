#!/bin/bash

echo "Starting VPN..."
sudo systemctl start vpnc

echo "Waiting for tunnel..."
while ! ip link show tun0 > /dev/null 2>&1; do sleep 2; done

echo "Starting hotspot..."
sudo systemctl start hostapd
sudo systemctl start dnsmasq

echo "Applying firewall..."
sudo iptables -t nat -F
sudo iptables -F FORWARD

sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
sudo iptables -A FORWARD -i wlan0 -o tun0 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j REJECT

echo "Applying routing..."
sudo ip rule add from 192.168.4.0/24 table vpn 2>/dev/null
sudo ip route add default dev tun0 table vpn 2>/dev/null

echo "VPN hotspot ready."
