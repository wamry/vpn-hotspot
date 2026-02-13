#!/bin/bash
set -e

#######################################
# CONFIG — EDIT THESE ONLY
#######################################
HOTSPOT_SSID="PiVPNHotspot"
HOTSPOT_PASSWORD="raspberryvpn"
HOTSPOT_SUBNET="192.168.4"
#######################################

echo "=== VPN Hotspot installer ==="

echo "Installing packages..."
apt update
apt install -y hostapd dnsmasq iptables iptables-persistent vpnc

systemctl stop hostapd || true
systemctl stop dnsmasq || true

echo "Configuring wlan0 static IP..."
grep -q "interface wlan0" /etc/dhcpcd.conf || cat >> /etc/dhcpcd.conf <<EOF

interface wlan0
static ip_address=${HOTSPOT_SUBNET}.1/24
nohook wpa_supplicant
EOF

echo "Configuring dnsmasq..."
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak 2>/dev/null || true
cat > /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=${HOTSPOT_SUBNET}.10,${HOTSPOT_SUBNET}.100,255.255.255.0,24h
EOF

echo "Configuring hostapd..."
cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=${HOTSPOT_SSID}
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${HOTSPOT_PASSWORD}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

echo "Enable IP forwarding..."
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "Create routing table..."
grep -q "200 vpn" /etc/iproute2/rt_tables || echo "200 vpn" >> /etc/iproute2/rt_tables

echo "Create VPNC service..."
cat > /etc/systemd/system/vpnc.service <<'EOF'
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

echo "Installing launch script..."
mkdir -p /opt/vpn-hotspot
cp ./launch.sh /opt/vpn-hotspot/launch.sh
chmod +x /opt/vpn-hotspot/launch.sh

echo "Create vpn-hotspot service..."
cat > /etc/systemd/system/vpn-hotspot.service <<'EOF'
[Unit]
Description=VPN Hotspot Launcher
After=network-online.target hostapd.service dnsmasq.service vpnc.service
Requires=vpnc.service

[Service]
Type=oneshot
ExecStart=/opt/vpn-hotspot/launch.sh

[Install]
WantedBy=multi-user.target
EOF



systemctl daemon-reload
systemctl enable hostapd dnsmasq vpnc vpn-hotspot.service

echo ""
echo "===================================="
echo "INSTALL COMPLETE"
echo "Hotspot SSID: $HOTSPOT_SSID"
echo "Hotspot Password: $HOTSPOT_PASSWORD"
echo "Reboot your Raspberry Pi now."
echo "===================================="
