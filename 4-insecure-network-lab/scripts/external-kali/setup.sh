#!/usr/bin/env bash

#Configuración de máquina de rol de atacante externo Kali.
#Red 100.70.9.0/24, ip: 100.70.9.10. Sin salida a internet
set -euo pipefail

#Actualización mínima del sistema.
export DEBIAN_FRONTEND=noninteractive #Comando para evitar que el SO solicite infromación al usuario durante instalación o actualización de paquetes basados en Debian.
apt-get update -qq
#Se instalan herramientas complementarias no incluidas en la box base.
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

nmcli connection modify "Wired connection 1" \
  ipv4.route-metric 50 || true

nmcli connection add \
  type ethernet \
  ifname eth1 \
  con-name "lab-externa" \
  ip4 100.70.9.10/24 \
  -- ipv4.method manual \
     ipv4.route-metric 101 \
     ipv4.never-default yes \
     ipv6.method disabled || true

# Rutas hacia otras redes a través del firewall
nmcli connection modify "lab-externa" \
  +ipv4.routes "192.168.57.0/24 100.70.9.1" \
  +ipv4.routes "192.168.58.0/24 100.70.9.1" || true

  # Aplicar en orden: primero eth0, luego eth1
nmcli connection up "Wired connection 1" || true
sleep 1
nmcli connection up "lab-externa" || true

#El atacante no hace routing, solo escucha, por eso ip_forward desactivado.
sysctl -w net.ipv4.ip_forward=0
echo "net.ipv4.ip_forward=0">/etc/sysctl.d/99-kali-lab.conf

#Crear directorios de trabajo del atacante para guardar datos.
mkdir -p /home/vagrant/lab/{recon,captures,exploits}
chown -R vagrant:vagrant /home/vagrant/lab

#Alias para las prácticas.
cat >> /home/vagrant/.bashrc<<'EOF'
#Insecure-network-lab aliases
alias nmap-quick='nmap -sV -T4 --open'
alias nmap-full='nmap -sV -sC -O -p- -T4'
alias iface='ip -br addr show'
alias targets='echo "DMZ: 192.168.57.10"; echo "Internal: 192.168.58.10"'
EOF

ssh-keygen -f '/home/vagrant/.ssh/known_hosts' -R '192.168.57.10'

echo "[external-kali] completado"
