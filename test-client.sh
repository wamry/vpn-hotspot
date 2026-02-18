#!/bin/bash

#########################################
# VPN Hotspot Client Connectivity Test
# Run this on a client device connected to IPSEC
#########################################

echo "=== Client Connectivity Test ==="
echo ""

# Test 1: Check if client has IP
echo "1. Checking client IP..."
CLIENT_IP=$(ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
if [ -z "$CLIENT_IP" ]; then
  CLIENT_IP=$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -1)
fi

if [ -n "$CLIENT_IP" ]; then
  echo "Client IP: $CLIENT_IP"
else
  echo "No IP address found. Check DHCP connectivity."
  exit 1
fi

# Test 2: Check gateway
echo ""
echo "2. Testing gateway (192.168.4.1)..."
if ping -c 1 -W 2 192.168.4.1 &>/dev/null; then
  echo "Gateway reachable"
else
  echo "Cannot reach gateway. Check WiFi connection."
  exit 1
fi

# Test 3: Check DNS resolution
echo ""
echo "3. Testing DNS resolution..."
if nslookup google.com 192.168.4.1 &>/dev/null; then
  echo "DNS resolving (google.com)"
else
  echo "DNS not resolving. Check dnsmasq on gateway."
  exit 1
fi

# Test 4: Check internet connectivity
echo ""
echo "4. Testing internet (ping 8.8.8.8)..."
if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
  echo "Internet reachable via VPN"
else
  echo "Cannot reach internet. Check VPN tunnel and routing."
  exit 1
fi

# Test 5: Check HTTP/HTTPS
echo ""
echo "5. Testing web access..."
if curl -s --max-time 5 http://google.com > /dev/null 2>&1; then
  echo "HTTP accessible"
elif curl -s --max-time 5 https://google.com > /dev/null 2>&1; then
  echo "HTTPS accessible"
else
  echo "Cannot access websites. Check internet routing and firewalls."
  exit 1
fi

echo ""
echo "=== All Tests Passed! ==="
echo "Your VPN hotspot is working correctly."
