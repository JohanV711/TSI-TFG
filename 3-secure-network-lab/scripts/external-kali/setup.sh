#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[+] Configurando external-kali (ENS lab)..."

# PASO 1 — Actualizar repositorios PRIMERO (antes de tocar DNS)
# eth0 NAT de Vagrant tiene DNS funcional en este momento
apt-get update -qq

# PASO 2 — Instalar paquetes
apt-get install -y -qq \
  wireguard \
  wireguard-tools \
  nmap \
  tcpdump \
  netcat-traditional \
  curl \
  wget \
  iputils-ping \
  net-tools \
  netdiscover \
  hydra \
  dsniff \
  john \
  sqlmap \
  dirb \
  gobuster \
  metasploit-framework \
  python3-pip \
  hping3 || true

# PASO 3 — Configurar DNS para compatibilidad con wg-quick
rm -f /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
systemctl enable systemd-resolved 2>/dev/null || true
systemctl start systemd-resolved 2>/dev/null || true

# PASO 4 — Configurar interfaz eth1 (red WAN del lab 91.168.50.0/24)
# never-default: eth0 sigue siendo default route para internet sin VPN y comprobar que todo funciona como debe.
nmcli connection delete "lab-externa" 2>/dev/null || true
nmcli connection add \
  type ethernet \
  ifname eth1 \
  con-name "lab-externa" \
  ip4 91.168.50.10/24 \
  -- ipv4.method manual \
     ipv4.route-metric 100 \
     ipv4.never-default yes \
     ipv6.method disabled

nmcli connection up "lab-externa" || true

# PASO 5 — Deshabilitar IP forwarding
sysctl -w net.ipv4.ip_forward=0
echo "net.ipv4.ip_forward=0" > /etc/sysctl.d/99-kali-lab.conf

# PASO 6 — Configuración WireGuard
# Claves privadas de este cliente — las públicas correspondientes
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard
#Configuración para vpn_admins.
cat > /etc/wireguard/wg-admins.conf << 'EOF'
[Interface]
PrivateKey = 8NuBhi82zdl/ArJmw0I37E5dk70DrXPSd1xm1kHPBHU=
Address = 10.10.1.51/32

[Peer]
# Clave pública instancia wg-admins en OPNsense
PublicKey = tlzDt6npntn7E2TX7MajuUHkNkIAAy8/LoVp/kYJzBo=
AllowedIPs = 0.0.0.0/0
Endpoint = 91.168.50.1:51820
PersistentKeepalive = 25
EOF
#Configuración para vpn_users.
cat > /etc/wireguard/wg-users.conf << 'EOF'
[Interface]
PrivateKey = 4MjzWv+k9j2EF6Ls1QGTWsPquiAi1XaAEbf6CSwLTF4=
Address = 10.10.2.51/32

[Peer]
# Clave pública instancia wg-users en OPNsense
PublicKey = dpb6pqNKyQ421inOZnBnSg+Q3PxPd6OxekiYPyrNlzA=
AllowedIPs = 0.0.0.0/0
Endpoint = 91.168.50.1:51821
PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/wg-admins.conf
chmod 600 /etc/wireguard/wg-users.conf

# PASO 7 — Directorios de trabajo
mkdir -p /home/vagrant/lab/{recon,captures,exploits,wireguard}
chown -R vagrant:vagrant /home/vagrant/lab

echo "--- setup.sh completado ---"
echo "external-kali configurado."
echo "IP WAN lab:   91.168.50.10"
echo "VPN admins:   sudo wg-quick up wg-admins"
echo "VPN users:    sudo wg-quick up wg-users"