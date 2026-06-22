#!/usr/bin/env bash

# Configuración de máquina de rol de atacante externo Kali.
# Red 100.70.9.0/24, ip: 100.70.9.10. Sin salida a internet
set -euo pipefail


export DEBIAN_FRONTEND=noninteractive


# Forzar DNS funcional para evitar cuelgues
systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf

apt-get update -qq

# Se instalan herramientas complementarias no incluidas en la box base.
apt-get install -y -qq \
  netdiscover \
  hydra \
  tcpdump \
  wireshark-common \
  dsniff \
  nmap \
  ettercap-text-only \
  telnet \
  ftp

# Configurar interfaz de gestión (eth0 - NAT de Vagrant)
nmcli connection modify "Wired connection 1" \
  ipv4.route-metric 50 || true

# Configurar interfaz del laboratorio (eth1)
# Eliminar conexión anterior si existe para evitar conflictos
nmcli connection delete "lab-externa" 2>/dev/null || true

# Crear nueva conexión para la red del laboratorio
nmcli connection add \
  type ethernet \
  ifname eth1 \
  con-name "lab-externa" \
  ip4 100.70.9.10/24 \
  -- ipv4.method manual \
     ipv4.route-metric 101 \
     ipv4.never-default yes \
     ipv6.method disabled

# Añadir rutas hacia otras redes a través del firewall
nmcli connection modify "lab-externa" \
  +ipv4.routes "192.168.57.0/24 100.70.9.1" \
  +ipv4.routes "192.168.58.0/24 100.70.9.1"

# Activar conexiones en orden
nmcli connection up "Wired connection 1" || true
sleep 2
nmcli connection up "lab-externa" || true

# Forzar rutas por si nmcli no las aplicó
sleep 3
ip route add 192.168.57.0/24 via 100.70.9.1 dev eth1 2>/dev/null || true
ip route add 192.168.58.0/24 via 100.70.9.1 dev eth1 2>/dev/null || true

# Verificar que la IP se asignó correctamente
echo "=== Configuración de red aplicada ==="
ip addr show eth1
echo "=== Rutas configuradas ==="
ip route show

# CONFIGURACIÓN DE SEGURIDAD (MALAS PRÁCTICAS)

# El atacante no hace routing, solo escucha
sysctl -w net.ipv4.ip_forward=0
echo "net.ipv4.ip_forward=0" > /etc/sysctl.d/99-kali-lab.conf

# Crear directorios de trabajo del atacante
mkdir -p /home/vagrant/lab/{recon,captures,exploits}
chown -R vagrant:vagrant /home/vagrant/lab

# Alias útiles para las prácticas
cat >> /home/vagrant/.bashrc << 'EOF'
# Insecure-network-lab aliases
alias nmap-quick='nmap -sV -T4 --open'
alias nmap-full='nmap -sV -sC -O -p- -T4'
alias iface='ip -br addr show'
alias targets='echo "DMZ: 192.168.57.10"; echo "Internal: 192.168.58.10"'
EOF

# Configuración SSH para evitar confirmaciones de host
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
cat > /home/vagrant/.ssh/config << 'EOF'
Host 192.168.57.*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host 192.168.58.*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
chmod 600 /home/vagrant/.ssh/config
chown -R vagrant:vagrant /home/vagrant/.ssh

echo "[external-kali] completado"