#!/bin/bash
set -e  # Exit on any error

error_exit() {
  echo "ERROR: $1" >&2
  exit 1
}

echo "Stopping previous hotspot if running..."
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo pkill hostapd 2>/dev/null || true
sleep 1

echo "Resetting Wi-Fi interface..."
# Keep wlan0 stable; just reset its address for hotspot mode
sudo ip addr flush dev wlan0 2>/dev/null || true
sudo ip link set wlan0 up 2>/dev/null || true
sleep 1
sudo ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null || true
sleep 1

echo "Starting hostapd before VPN..."
sudo systemctl restart hostapd || error_exit "Failed to start hostapd"
sleep 2
if ! sudo systemctl is-active --quiet hostapd; then
  sudo journalctl -xeu hostapd.service -n 20
  error_exit "hostapd did not start"
fi
echo "hostapd started"

echo "Starting dnsmasq..."
sudo systemctl start dnsmasq || error_exit "Failed to start dnsmasq"
if ! sudo systemctl is-active --quiet dnsmasq; then
  error_exit "dnsmasq did not start"
fi
echo "dnsmasq started"
sleep 1

echo "Starting VPN..."
sudo systemctl start vpnc || error_exit "Failed to start VPN. Run vpn-setup.sh first."

echo "Waiting for VPN tunnel (timeout: 30s)..."
TIMEOUT=30
ELAPSED=0
while ! ip link show tun0 > /dev/null 2>&1; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    error_exit "VPN tunnel did not connect. Check vpnc config and logs."
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo "  Waiting... ${ELAPSED}s"
done
echo "VPN tunnel connected"

echo "Setting wireless regulatory domain..."
sudo iw reg set EG 2>/dev/null || true

echo "Applying firewall rules..."
# Flush all old rules first
sudo iptables -F INPUT 2>/dev/null || true
sudo iptables -F FORWARD 2>/dev/null || true
sudo iptables -t nat -F POSTROUTING 2>/dev/null || true
sudo iptables -t mangle -F FORWARD 2>/dev/null || true
sleep 1

# Apply fresh rules
sudo iptables -A INPUT -i wlan0 -j ACCEPT || error_exit "Failed to add INPUT rule"
# NAT hotspot traffic out through both uplinks
sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE || error_exit "Failed to add NAT tun0 rule"
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE || error_exit "Failed to add NAT eth0 rule"
sudo iptables -A FORWARD -i wlan0 -o tun0 -j ACCEPT || error_exit "Failed to add FORWARD wlan0->tun0"
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT || error_exit "Failed to add FORWARD wlan0->eth0"
sudo iptables -A FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT || error_exit "Failed to add FORWARD tun0->wlan0"
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT || error_exit "Failed to add FORWARD eth0->wlan0"
sudo iptables -t mangle -A FORWARD -o tun0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu || error_exit "Failed to add TCPMSS clamp"
echo "Firewall rules applied"

echo "Applying routing rules..."
# Clean up old rules for this subnet (delete all rules matching our subnet)
# Get all rule priorities for our subnet and delete them
ip rule show | grep "192.168.4.0/24" | awk '{print $1}' | sed 's/:$//' | while read prio; do
  sudo ip rule del prio "$prio" 2>/dev/null
done
sleep 1
sudo ip route flush table vpn 2>/dev/null || true
echo "Routing rules applied (using main table with tun0+eth0 routes)"

echo ""
echo "VPN hotspot ready!"
echo "SSID: $(grep -oP '(?<=ssid=).*' /etc/hostapd/hostapd.conf 2>/dev/null || echo 'IPSEC')"
echo "Clients use main routing (internet via eth0, VPN subnets via tun0)"
