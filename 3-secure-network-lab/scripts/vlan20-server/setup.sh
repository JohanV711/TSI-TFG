#!/bin/bash
# =============================================================================
# setup.sh — vlan20-server (192.168.20.10)
# Servidor de base de datos MySQL con datos sensibles simulados.
# LAN_VLAN20 — zona de máxima restricción.
#
# Principios de seguridad aplicados:
#   - MySQL escucha SOLO en 192.168.20.10 (no en 0.0.0.0)
#   - webuser con permisos mínimos solo desde 172.16.0.10
#   - Optimizaciones de memoria ANTES del primer arranque de MySQL
#   - Rutas persistentes via netplan hacia todas las redes internas y VPN
#   - Paquetes instalados ANTES de cambiar rutas
# =============================================================================

set -e
echo "[*] Iniciando configuración de vlan20-server (192.168.20.10)..."

# PASO 1 — Instalar MySQL usando NAT de Vagrant
echo "[*] Actualizando repositorios..."
apt-get update -qq

echo "[*] Instalando MySQL Server..."
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server 2>/dev/null
# Detener MySQL inmediatamente si arrancó durante la instalación
systemctl stop mysql 2>/dev/null || true

# PASO 2 — Hardening y optimización de MySQL
sed -i 's/^bind-address.*/bind-address = 192.168.20.10/' \
    /etc/mysql/mariadb.conf.d/50-server.cnf

cat >> /etc/mysql/mariadb.conf.d/50-server.cnf << 'EOF'

# Optimización para lab virtualizado
innodb_buffer_pool_size = 64M
performance_schema = OFF
table_open_cache = 64
skip-name-resolve
EOF

# PASO 3 — Rutas persistentes via netplan
# Necesaria para que MySQL pueda responder al webserver en DMZ
# y para que los clientes VPN admin puedan alcanzar esta máquina
echo "[*] Configurando rutas persistentes hacia redes internas y VPN..."
cat > /etc/netplan/99-lab-routes.yaml << 'EOF'
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
      dhcp4-overrides:
        use-routes: false
        use-dns: false
      dhcp6-overrides:
        use-routes: false
        use-dns: false
    enp0s8:
      routes:
        - to: default
          via: 192.168.20.1
        - to: 172.16.0.0/24
          via: 192.168.20.1
        - to: 192.168.10.0/24
          via: 192.168.20.1
        - to: 10.10.1.0/24
          via: 192.168.20.1
        - to: 10.10.2.0/24
          via: 192.168.20.1
      nameservers:
        addresses: [192.168.20.1]
EOF

chmod 600 /etc/netplan/99-lab-routes.yaml
netplan apply
ip route add 172.16.0.0/24 via 192.168.20.1 dev enp0s8 2>/dev/null || true
ip route add 192.168.10.0/24 via 192.168.20.1 dev enp0s8 2>/dev/null || true
ip route add 10.10.1.0/24 via 192.168.20.1 dev enp0s8 2>/dev/null || true
ip route add 10.10.2.0/24 via 192.168.20.1 dev enp0s8 2>/dev/null || true

# PASO 4 — Arrancar MySQL y crear base de datos
systemctl start mysql

# Esperar hasta que MySQL esté operativo (máximo 60 segundos)
echo "[*] Esperando a que MySQL esté operativo..."
for i in $(seq 1 60); do
  if mysqladmin ping -u root --silent 2>/dev/null; then
    echo "[*] MySQL operativo tras ${i}s"
    break
  fi
  sleep 1
done
echo "[*] Creando base de datos empresa con datos sensibles simulados..."
mysql -u root << 'SQLEOF'
CREATE DATABASE IF NOT EXISTS empresa
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE empresa;

CREATE TABLE IF NOT EXISTS empleados (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  nombre        VARCHAR(100) NOT NULL,
  departamento  VARCHAR(50)  NOT NULL,
  email         VARCHAR(100) NOT NULL UNIQUE,
  salario       DECIMAL(8,2) NOT NULL,
  fecha_alta    DATE         NOT NULL DEFAULT (CURRENT_DATE)
);

CREATE TABLE IF NOT EXISTS accesos (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  usuario       VARCHAR(100) NOT NULL,
  ip_origen     VARCHAR(45)  NOT NULL,
  fecha_acceso  DATETIME     NOT NULL DEFAULT NOW(),
  resultado     ENUM('exito','fallo') NOT NULL
);

INSERT INTO empleados (nombre, departamento, email, salario) VALUES
  ('Johan Vargas',    'Seguridad IT',   'johanv@empresa.lab',    45000.00),
  ('Cristian Alvarez',  'Desarrollo',     'cristianalvarez@empresa.lab', 42000.00),
  ('Julián Alvarez',   'Administracion', 'julianalvarez@empresa.lab',  38000.00),
  ('Lionel Andres Messi', 'Redes',          'messi@empresa.lab',   44000.00),
  ('Ibra', 'RRHH',           'ibra@empresa.lab',  36000.00),
  ('Luis Enrique',   'Direccion',      'lenrique@empresa.lab',  65000.00);

INSERT INTO accesos (usuario, ip_origen, resultado) VALUES
  ('johan',    '10.10.0.2',    'exito'),
  ('hacker', '91.168.50.10', 'fallo'),
  ('cristian', '10.10.0.2',    'exito');

-- Principio de mínimo privilegio:
-- webuser SOLO puede SELECT en empleados
-- SOLO desde 172.16.0.10 (dmz-server) IMPORTANTE seguridad por parte de MariaDB que solo permite entrar a usuarios de la red determinada.
CREATE USER IF NOT EXISTS 'webuser'@'172.16.0.10'
  IDENTIFIED BY 'webpassword';
GRANT SELECT ON empresa.empleados TO 'webuser'@'172.16.0.10';
FLUSH PRIVILEGES;
SQLEOF

# PASO 5 — Habilitar MySQL y ajustar rutas finales
echo "[*] Habilitando MySQL para arranque automático..."
systemctl enable mysql

# Cambiar default route a OPNsense (quitar la de Vagrant)
ip route del default via 10.0.2.2 dev enp0s3 2>/dev/null || true
ip route add default via 192.168.20.1 dev enp0s8 2>/dev/null || true
echo "vlan20-server configurado."
echo "IP:           192.168.20.10"
echo "Gateway:      192.168.20.1 (OPNsense VLAN20)"
echo "MySQL:        192.168.20.10:3306 (solo desde 172.16.0.10)"