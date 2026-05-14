#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
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
  net-tools

# Configuración de la interfaz de red con nmcli.
nmcli connection add \
  type ethernet \
  ifname eth1 \
  con-name "lab-externa" \
  ip4 91.168.50.10/24 \
  -- ipv4.method manual \
  ipv4.route-metric 100 \
  ipv4.never-default yes \
  ipv6.method disabled || true

nmcli connection up "lab-externa" || true

# Habilitamos respuesta a ping.
# y mantenemos el forwarding desactivado.
sysctl -w net.ipv4.ip_forward=0
echo "net.ipv4.ip_forward=0" > /etc/sysctl.d/99-kali-lab.conf

#Preparación de WireGuard.
#Creamos el directorio.
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

chown -R vagrant:vagrant /home/vagrant/lab
echo "[external-kali] Configuración completada."