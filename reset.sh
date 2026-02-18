#!/bin/bash
set -e

echo "Stopping VPN + hotspot services..."
sudo systemctl stop vpnc hostapd dnsmasq 2>/dev/null || true
sudo systemctl disable vpnc hostapd dnsmasq 2>/dev/null || true

echo "Removing vpnc service + config..."
sudo rm -f /etc/systemd/system/vpnc.service
sudo rm -rf /etc/vpnc

echo "Removing hostapd custom config..."
sudo rm -f /etc/hostapd/hostapd.conf
sudo rm -rf /etc/systemd/system/hostapd.service.d

echo "Restoring dnsmasq config..."
if [ -f /etc/dnsmasq.conf.bak ]; then
	sudo mv /etc/dnsmasq.conf.bak /etc/dnsmasq.conf
else
	sudo rm -f /etc/dnsmasq.conf
fi

echo "Removing wlan0 static config from dhcpcd..."
sudo sed -i '/^interface wlan0$/,/^nohook wpa_supplicant$/d' /etc/dhcpcd.conf 2>/dev/null || true

echo "Removing hotspot firewall + routing rules..."
while sudo iptables -C INPUT -i wlan0 -j ACCEPT 2>/dev/null; do
	sudo iptables -D INPUT -i wlan0 -j ACCEPT
done

while sudo iptables -C FORWARD -i wlan0 -o tun0 -j ACCEPT 2>/dev/null; do
	sudo iptables -D FORWARD -i wlan0 -o tun0 -j ACCEPT
done
while sudo iptables -C FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null; do
	sudo iptables -D FORWARD -i wlan0 -o eth0 -j ACCEPT
done
while sudo iptables -C FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; do
	sudo iptables -D FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
done
while sudo iptables -C FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; do
	sudo iptables -D FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
done

while sudo iptables -t nat -C POSTROUTING -o tun0 -j MASQUERADE 2>/dev/null; do
	sudo iptables -t nat -D POSTROUTING -o tun0 -j MASQUERADE
done
while sudo iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null; do
	sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
done

while sudo iptables -t mangle -C FORWARD -o tun0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null; do
	sudo iptables -t mangle -D FORWARD -o tun0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
done

echo "Removing policy routing entries..."
while ip rule show | grep -q "from 192.168.4.0/24 lookup vpn"; do
	sudo ip rule del from 192.168.4.0/24 table vpn 2>/dev/null || true
done
sudo ip route flush table vpn 2>/dev/null || true
sudo sed -i '/^200 vpn$/d' /etc/iproute2/rt_tables 2>/dev/null || true

echo "Reverting kernel forwarding/rpf settings..."
sudo rm -f /etc/sysctl.d/99-vpn-hotspot.conf
sudo sed -i '/^net\.ipv4\.ip_forward=1$/d' /etc/sysctl.conf 2>/dev/null || true
sudo sysctl --system >/dev/null || true

echo "Restoring Wi-Fi client services (wpa_supplicant)..."
sudo systemctl unmask wpa_supplicant 2>/dev/null || true
sudo systemctl enable wpa_supplicant 2>/dev/null || true
sudo systemctl start wpa_supplicant 2>/dev/null || true
sudo systemctl unmask wpa_supplicant@wlan0 2>/dev/null || true
sudo systemctl enable wpa_supplicant@wlan0 2>/dev/null || true
sudo systemctl start wpa_supplicant@wlan0 2>/dev/null || true

echo "Restoring NetworkManager control of wlan0..."
sudo rm -f /etc/NetworkManager/conf.d/unmanaged-wlan0.conf
sudo systemctl restart NetworkManager 2>/dev/null || true

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo ""
echo "Reset complete."
echo "Reboot recommended."
