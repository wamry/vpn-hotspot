#!/bin/bash

echo "Waiting for VPN tunnel..."
while ! ip link show tun0 > /dev/null 2>&1; do
    sleep 2
done

echo "Resetting firewall rules"

# Flush previous rules (prevents duplicates)
iptables -t nat -F
iptables -F FORWARD

echo "Applying VPN hotspot firewall + routing"

# NAT hotspot → VPN
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables -A FORWARD -i wlan0 -o tun0 -j ACCEPT
iptables -A FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Kill-switch (prevent bypass)
iptables -A FORWARD -i wlan0 -o eth0 -j REJECT

# Reset policy routing (avoid duplicates)
ip rule del from 192.168.4.0/24 table vpn 2>/dev/null || true
ip route flush table vpn 2>/dev/null || true

ip rule add from 192.168.4.0/24 table vpn
ip route add default dev tun0 table vpn

echo "VPN hotspot ready"
