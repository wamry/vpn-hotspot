#!/bin/bash

echo "Stopping previous hotspot if running..."
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo pkill hostapd 2>/dev/null || true
sleep 2

echo "Starting VPN..."
sudo systemctl start vpnc

echo "Waiting for tunnel..."
while ! ip link show tun0 > /dev/null 2>&1; do sleep 2; done

echo "Starting hotspot..."
# kill any previous instance
sudo pkill hostapd 2>/dev/null || true
# start hostapd manually (no systemd)
sudo /usr/sbin/hostapd -B /etc/hostapd/hostapd.conf
sleep 3
sudo systemctl start dnsmasq
sleep 2

echo "Applying firewall..."
sudo iptables -t nat -F
sudo iptables -F FORWARD
# Allow hotspot clients to talk to the Pi (gateway/DNS/DHCP)
sudo iptables -A INPUT -i wlan0 -j ACCEPT
# NAT hotspot traffic into VPN
sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
sudo iptables -A FORWARD -i wlan0 -o tun0 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
# Kill-switch: block bypassing VPN via eth0
sudo iptables -A FORWARD -i wlan0 -o eth0 -j REJECT

echo "Applying routing..."
sudo ip rule add from 192.168.4.0/24 table vpn 2>/dev/null
sudo ip route add default dev tun0 table vpn 2>/dev/null

echo "VPN hotspot ready."
