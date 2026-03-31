# VPN Hotspot

Turns a Raspberry Pi into a Wi-Fi hotspot that routes all client traffic through an IPSec VPN. Clients connect to the hotspot and automatically get VPN access — no configuration needed on their end.

## Setup

### 1. Add VPN Credentials

Create a `default.conf` file using `example.conf` as a template and fill in your VPN credentials:

```bash
cp example.conf default.conf
nano default.conf
```

### 2. Install the VPN Service

```bash
sudo ./vpn-setup.sh
```

This installs `vpnc`, copies your `default.conf` to `/etc/vpnc/`, and creates a systemd service for the VPN connection.

### 3. Configure Hotspot Name & Password

Edit lines 9 and 10 in `setup.sh` to set your preferred hotspot SSID and password:

```bash
HOTSPOT_SSID="IPSEC"
HOTSPOT_PASSWORD="changeme123"
```

### 4. Run Initial Setup

```bash
sudo ./setup.sh
```

This installs all required packages (hostapd, dnsmasq, etc.), configures the Wi-Fi interface, DHCP, firewall, IP forwarding, and registers a systemd service so the hotspot launches automatically on boot.

> **Note:** Do not move the project directory after running setup. The boot service references the absolute path to `launch.sh`.

## Usage

After setup, the hotspot starts automatically on boot. To start it manually:

```bash
sudo ./launch.sh
```

## Files

| File | Description |
|---|---|
| `setup.sh` | One-time setup script. Installs packages, configures hostapd, dnsmasq, DHCP, firewall rules, IP forwarding, and registers the auto-launch service. Run with `sudo`. |
| `vpn-setup.sh` | Installs `vpnc` and creates the VPN systemd service from `default.conf`. Run with `sudo`. |
| `launch.sh` | Starts the hotspot and VPN tunnel. Brings up hostapd, dnsmasq, vpnc, applies firewall/NAT rules, and waits for the VPN tunnel to connect. Runs automatically on boot after setup. |
| `reset.sh` | Tears down everything — stops services, removes configs, restores wpa_supplicant and NetworkManager, and cleans up firewall/routing rules. Reboot recommended after running. |
| `test-client.sh` | Diagnostic script to run from a client connected to the hotspot. Tests gateway reachability, DNS, internet access, and HTTP connectivity. |
| `default.conf` | Your VPN credentials (not committed). Created from `example.conf`. |
| `example.conf` | Template for `default.conf` showing the required VPN credential fields. |