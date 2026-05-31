#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[+] Configurando external-kali (ENS lab)..."

# Forzar DNS funcional (como en el bloque inseguro)
systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf

apt-get update -qq

# Herramientas de pentesting + WireGuard
apt-get install -y -qq \
  wireguard \
  wireguard-tools \
  resolvconf \
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
  ettercap-text-only \
  john \
  sqlmap \
  dirb \
  gobuster \
  metasploit-framework \
  python3-pip \
  exploitdb

# Configurar interfaz de laboratorio (eth1) – red WAN 91.168.50.0/24
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

# Deshabilitar forwarding
sysctl -w net.ipv4.ip_forward=0
echo "net.ipv4.ip_forward=0" > /etc/sysctl.d/99-kali-lab.conf

# Preparación de WireGuard
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

# Directorios de trabajo
mkdir -p /home/vagrant/lab/{recon,captures,exploits,wireguard}
chown -R vagrant:vagrant /home/vagrant/lab

echo "[+] setup.sh completado"