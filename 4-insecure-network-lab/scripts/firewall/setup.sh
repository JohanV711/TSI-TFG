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

# Paquetes necesarios
apt-get update -qq
apt-get install -y -qq iptables iptables-persistent

#Habilitar ip_forward de forma permanente.
# En un firewall real estaría restringido por rutas y reglas.
# Aquí se habilita globalmente sin ningún control adicional.
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

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
iptables -P FORWARD ACCEPT

# Reglas explícitas permisivas.
iptables -A FORWARD -i eth1 -o eth2 -j ACCEPT # externo → DMZ
iptables -A FORWARD -i eth1 -o eth3 -j ACCEPT # externo → interno 
iptables -A FORWARD -i eth2 -o eth3 -j ACCEPT # DMZ → interno 
iptables -A FORWARD -i eth2 -o eth1 -j ACCEPT
iptables -A FORWARD -i eth3 -o eth1 -j ACCEPT
iptables -A FORWARD -i eth3 -o eth2 -j ACCEPT

# NAT para que los segmentos internos puedan
# comunicarse usando la IP del firewall como gateway
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth3 -j MASQUERADE

# Sin reglas de logging, si se ataca no queda rastro.
# 4. Persistir reglas entre reinicios
netfilter-persistent save
# 5. Sin firewall de aplicación ni IDS
ufw disable || true

echo "[firewall] Setup completado."