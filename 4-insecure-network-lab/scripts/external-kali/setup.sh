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
dsniff \
ettercap-text-only \
telnet \
ftp

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

echo "[external-kali] Provisioning completado."

ip route add 192.168.57.0/24 via 100.70.9.1 || true
ip route add 192.168.58.0/24 via 100.70.9.1 || true
echo "[external-kali] rutas completado."
