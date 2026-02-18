#!/bin/bash
set -e

#######################################
# CONFIG — EDIT THESE ONLY
#######################################
HOTSPOT_SSID="PiVPNHotspot"
HOTSPOT_PASSWORD="raspberryvpn"
HOTSPOT_SUBNET="192.168.4"
#######################################

echo "Installing hotspot packages..."
sudo apt update
sudo apt install -y hostapd dnsmasq iptables iptables-persistent

echo "Configuring wlan0 static IP..."
grep -q "interface wlan0" /etc/dhcpcd.conf || sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOF

interface wlan0
static ip_address=${HOTSPOT_SUBNET}.1/24
nohook wpa_supplicant
EOF

echo "Creating hostapd config..."
sudo mkdir -p /etc/hostapd

sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
interface=wlan0
driver=nl80211
ssid=${HOTSPOT_SSID}

hw_mode=g
channel=6

ieee80211n=1
wmm_enabled=1

macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0

wpa=2
wpa_passphrase=${HOTSPOT_PASSWORD}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

echo "Point hostapd service to config (Bookworm method)..."
sudo mkdir -p /etc/systemd/system/hostapd.service.d

sudo tee /etc/systemd/system/hostapd.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/hostapd /etc/hostapd/hostapd.conf
EOF

echo "Configuring DHCP server..."
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak 2>/dev/null || true

sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=wlan0
bind-interfaces
dhcp-range=${HOTSPOT_SUBNET}.10,${HOTSPOT_SUBNET}.100,255.255.255.0,24h
EOF

echo "Enable IP forwarding..."
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || \
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

sudo sysctl -p

echo "Create routing table..."

# Ensure directory + file exist (Trixie/Bookworm safe)
sudo mkdir -p /etc/iproute2
sudo touch /etc/iproute2/rt_tables

grep -q "200 vpn" /etc/iproute2/rt_tables || \
echo "200 vpn" | sudo tee -a /etc/iproute2/rt_tables
sudo systemctl daemon-reload

echo "Unmasking and enabling hotspot services..."
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq

echo "Disabling Wi-Fi client services (required for hotspot)..."
# Stop Wi-Fi client so wlan0 can be an AP
sudo systemctl stop wpa_supplicant 2>/dev/null || true
sudo systemctl disable wpa_supplicant 2>/dev/null || true
sudo systemctl stop wpa_supplicant@wlan0 2>/dev/null || true
sudo systemctl disable wpa_supplicant@wlan0 2>/dev/null || true
# Reset wlan0 so hostapd can take control
sudo ip link set wlan0 down || true
sudo rfkill unblock wifi || true
sudo ip link set wlan0 up || true

echo ""
echo "Hotspot setup complete."
echo "SSID: $HOTSPOT_SSID"
echo "Password: $HOTSPOT_PASSWORD"
echo ""
echo "Next step: run launch.sh"
