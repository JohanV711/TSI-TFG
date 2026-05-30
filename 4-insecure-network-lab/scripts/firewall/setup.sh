#!/usr/bin/env bash
# Malas prácticas intencionadas.
# - Política ACCEPT por defecto en INPUT, OUTPUT y FORWARD
# - ip_forward habilitado sin restricción de rutas
# - Sin inspección de estado (stateless)
# - Sin limitación de puertos entre segmentos
# - Sin logging de tráfico
# - Reglas permisivas explícitas que anulan cualquier control
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Forzar DNS funcional para evitar cuelgues
systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf

sleep 10
ip -br addr   

MGMT_IFACE=$(ip route | grep default | awk '{print $5}')
echo "Interfaz de gestión: $MGMT_IFACE"
EXT_IFACE=$(ip -br addr | awk '/100\.70\.9\.1/ {print $1}')
DMZ_IFACE=$(ip -br addr | awk '/192\.168\.57\.1/ {print $1}')
INT_IFACE=$(ip -br addr | awk '/192\.168\.58\.1/ {print $1}')

# Verificar que tenemos todas las interfaces
if [ -z "$EXT_IFACE" ] || [ -z "$DMZ_IFACE" ] || [ -z "$INT_IFACE" ]; then
  echo "ERROR: interfaces no detectadas. Interfaces actuales:"
  ip -br addr
  echo "Esperando 30 segundos adicionales..."
  sleep 30
  # Reintentar detección
  EXT_IFACE=$(ip -br addr | awk '/100\.70\.9\.1/ {print $1}')
  DMZ_IFACE=$(ip -br addr | awk '/192\.168\.57\.1/ {print $1}')
  INT_IFACE=$(ip -br addr | awk '/192\.168\.58\.1/ {print $1}')
fi

echo "EXT=$EXT_IFACE DMZ=$DMZ_IFACE INT=$INT_IFACE MGMT=$MGMT_IFACE"

# Paquetes necesarios
apt-get update -qq
apt-get install -y -qq iptables iptables-persistent

# Configuración permanente de ip_forward y malas prácticas.
cat > /etc/sysctl.d/99-firewall-lab.conf << 'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
# Sin protecciones adicionales (malas prácticas)
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.all.accept_source_route = 1
net.ipv4.conf.all.accept_redirects = 1
net.ipv4.conf.all.send_redirects = 1
EOF
sysctl --system -q
echo 1 > /proc/sys/net/ipv4/ip_forward

#Reglas iptables.
# Limpiar reglas existentes
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Política por defecto ACCEPT en todo.
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

#permitir tráfico de gestión Vagrant.
iptables -A INPUT -i $MGMT_IFACE -j ACCEPT
iptables -A OUTPUT -o $MGMT_IFACE -j ACCEPT

# Reglas explícitas permisivas.
iptables -A FORWARD -i $EXT_IFACE -o $DMZ_IFACE -j ACCEPT # externo → DMZ
iptables -A FORWARD -i $EXT_IFACE -o $INT_IFACE -j ACCEPT # externo → interno 
iptables -A FORWARD -i $DMZ_IFACE -o $INT_IFACE -j ACCEPT # DMZ → interno 
iptables -A FORWARD -i $DMZ_IFACE -o $EXT_IFACE -j ACCEPT
iptables -A FORWARD -i $INT_IFACE -o $EXT_IFACE -j ACCEPT
iptables -A FORWARD -i $INT_IFACE -o $DMZ_IFACE -j ACCEPT

#Permitir el tráfico de retorno
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Aislamiento: evitar que el tráfico del laboratorio llegue a la interfaz de gestión
iptables -A FORWARD -i $EXT_IFACE -o $MGMT_IFACE -j DROP
iptables -A FORWARD -i $DMZ_IFACE -o $MGMT_IFACE -j DROP
iptables -A FORWARD -i $INT_IFACE -o $MGMT_IFACE -j DROP

# Prevenir acceso desde redes internas al propio firewall (solo por sus IPs internas)
iptables -A INPUT -i $EXT_IFACE -j DROP
iptables -A INPUT -i $DMZ_IFACE -j DROP
iptables -A INPUT -i $INT_IFACE -j DROP

#Rutas estáticas persistentes con netplan
cat > /etc/netplan/01-firewall-routes.yaml << EOF
network:
  version: 2
  ethernets:
    ${MGMT_IFACE}:
      dhcp4: true
    ${EXT_IFACE}:
      addresses:
        - 100.70.9.1/24
      dhcp4: false
    ${DMZ_IFACE}:
      addresses:
        - 192.168.57.1/24
      dhcp4: false
    ${INT_IFACE}:
      addresses:
        - 192.168.58.1/24
      dhcp4: false
EOF

netplan apply

# Sin reglas de logging, si se ataca no queda rastro.
# 4. Persistir reglas entre reinicios
netfilter-persistent save
# 5. Sin firewall de aplicación ni IDS
ufw disable || true

echo "[firewall] Setup completado."