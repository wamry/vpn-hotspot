#!/bin/bash
set -e

#######################################
# CONFIG - EDIT THESE ONLY
#######################################
HOTSPOT_SSID="IPSEC"
HOTSPOT_PASSWORD="bigfoot1"
HOTSPOT_SUBNET="192.168.4" # Update in launch.sh also
#######################################

error_exit() {
  echo "ERROR: $1" >&2
  exit 1
}

echo "Installing hotspot packages..."
sudo apt update
sudo apt install -y hostapd dnsmasq iptables iptables-persistent dhcpcd5

echo "Enabling DHCP client daemon..."
sudo systemctl enable dhcpcd
sudo systemctl start dhcpcd

echo "Setting Wi-Fi regulatory domain..."
# Required for hotspot/AP mode on Raspberry Pi
sudo mkdir -p /etc/wpa_supplicant
sudo tee /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null <<EOF
country=EG
EOF

# Also configure through raspi-config silently (no popup)
sudo raspi-config nonint do_wifi_country EG 2>/dev/null || true

echo "Configuring wlan0 static IP..."
grep -q "interface wlan0" /etc/dhcpcd.conf || sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOF

interface wlan0
static ip_address=${HOTSPOT_SUBNET}.1/24
nohook wpa_supplicant
EOF

echo "Creating hostapd config..."
sudo mkdir -p /etc/hostapd
sudo rm -f /etc/hostapd/hostapd.conf
sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
interface=wlan0
driver=nl80211
ssid=${HOTSPOT_SSID}

hw_mode=g
channel=6

ieee80211n=0
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
Type=simple
ExecStart=
ExecStart=/usr/sbin/hostapd /etc/hostapd/hostapd.conf
TimeoutStartSec=120
Restart=always
RestartSec=3
EOF

echo "Configuring DHCP server..."
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak 2>/dev/null || true

sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=wlan0
bind-interfaces
no-resolv
dhcp-authoritative
dhcp-range=${HOTSPOT_SUBNET}.10,${HOTSPOT_SUBNET}.100,255.255.255.0,24h
dhcp-option=3,${HOTSPOT_SUBNET}.1
dhcp-option=6,${HOTSPOT_SUBNET}.1
dhcp-option=26,1380
server=8.8.8.8
server=8.8.4.4
log-queries
log-dhcp
EOF

echo "Enable IP forwarding..."
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || \
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

echo "Writing kernel forwarding/rpf settings..."
sudo tee /etc/sysctl.d/99-vpn-hotspot.conf > /dev/null <<EOF
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.wlan0.rp_filter=0
net.ipv4.conf.tun0.rp_filter=0
EOF

sudo sysctl -p
sudo sysctl --system >/dev/null

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
sudo systemctl mask wpa_supplicant 2>/dev/null || true

# Also disable per-interface instance
sudo systemctl stop wpa_supplicant@wlan0 2>/dev/null || true
sudo systemctl disable wpa_supplicant@wlan0 2>/dev/null || true
sudo systemctl mask wpa_supplicant@wlan0 2>/dev/null || true

echo "Disabling systemd hostapd/dnsmasq services (will be started manually by launch.sh)..."
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true

echo "Configuring NetworkManager to ignore wlan0..."
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/unmanaged-wlan0.conf > /dev/null <<EOF
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF
sudo systemctl restart NetworkManager 2>/dev/null || true

echo "Restarting hostapd to apply config..."
sudo systemctl restart hostapd 2>/dev/null || true
sleep 2

echo ""
echo "Validating setup..."
[ -f /etc/hostapd/hostapd.conf ] && echo "hostapd config exists" || error_exit "hostapd config not found"
[ -f /etc/dnsmasq.conf ] && echo "dnsmasq config exists" || error_exit "dnsmasq config not found"
ip link show wlan0 &>/dev/null && echo "wlan0 interface exists" || error_exit "wlan0 interface not found"

echo ""
echo "Hotspot setup complete."
echo "SSID: $HOTSPOT_SSID"
echo "Password: $HOTSPOT_PASSWORD"
echo ""
echo "Next step: run ./launch.sh"
