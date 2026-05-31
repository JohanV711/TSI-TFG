#!/bin/bash
# =============================================================================
# setup.sh — vlan20-server (192.168.20.10)
# Servidor de base de datos MySQL con datos sensibles simulados
# LAN_VLAN20 — zona de máxima restricción
#
# Principios de seguridad aplicados:
#   - MySQL escucha SOLO en 192.168.20.10 (no en 0.0.0.0)
#   - webuser con permisos mínimos solo desde 172.16.0.10
#   - Rutas persistentes via netplan hacia todas las redes internas y VPN
#   - Paquetes instalados ANTES de cambiar rutas
# =============================================================================

set -e

echo "[*] Iniciando configuración de vlan20-server (192.168.20.10)..."

# -----------------------------------------------------------------------------
# PASO 1 — Instalar paquetes usando NAT de Vagrant
# NO tocar rutas todavía — apt necesita salida a internet por NAT
# -----------------------------------------------------------------------------
echo "[*] Actualizando repositorios..."
apt-get update -qq

echo "[*] Instalando MySQL Server..."
DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server 2>/dev/null

# -----------------------------------------------------------------------------
# PASO 2 — Rutas persistentes via netplan
# Se configura DESPUÉS de instalar paquetes
# Necesaria para que MySQL pueda responder al webserver en DMZ
# y para que los clientes VPN admin puedan alcanzar esta máquina
# -----------------------------------------------------------------------------
echo "[*] Configurando rutas persistentes hacia redes internas y VPN..."
cat > /etc/netplan/99-lab-routes.yaml << 'EOF'
network:
  version: 2
  ethernets:
    enp0s8:
      routes:
        - to: 172.16.0.0/24
          via: 192.168.20.1
        - to: 192.168.10.0/24
          via: 192.168.20.1
        - to: 10.10.1.0/24
          via: 192.168.20.1
        - to: 10.10.2.0/24
          via: 192.168.20.1
EOF
netplan apply

# Aplicar también ahora sin esperar al reinicio
ip route add 172.16.0.0/24 via 192.168.20.1 dev enp0s8 2>/dev/null || true
ip route add 192.168.10.0/24 via 192.168.20.1 dev enp0s8 2>/dev/null || true
ip route add 10.10.1.0/24 via 192.168.20.1 dev enp0s8 2>/dev/null || true
ip route add 10.10.2.0/24 via 192.168.20.1 dev enp0s8 2>/dev/null || true

# -----------------------------------------------------------------------------
# PASO 3 — Hardening de MySQL
# Restringir a interfaz interna — nunca escuchar en 0.0.0.0
# -----------------------------------------------------------------------------
echo "[*] Restringiendo MySQL a interfaz interna (192.168.20.10)..."
sed -i 's/^bind-address.*/bind-address = 192.168.20.10/' \
    /etc/mysql/mysql.conf.d/mysqld.cnf

# -----------------------------------------------------------------------------
# PASO 4 — Crear base de datos y datos simulados
# -----------------------------------------------------------------------------
echo "[*] Iniciando MySQL para configurar base de datos..."
systemctl start mysql

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
  ('Ana Garcia',    'Seguridad IT',   'ana@empresa.lab',    45000.00),
  ('Carlos Lopez',  'Desarrollo',     'carlos@empresa.lab', 42000.00),
  ('Maria Perez',   'Administracion', 'maria@empresa.lab',  38000.00),
  ('Juan Martinez', 'Redes',          'juan@empresa.lab',   44000.00),
  ('Laura Sanchez', 'RRHH',           'laura@empresa.lab',  36000.00),
  ('Pedro Gomez',   'Direccion',      'pedro@empresa.lab',  65000.00);

INSERT INTO accesos (usuario, ip_origen, resultado) VALUES
  ('ana',    '10.10.0.2',    'exito'),
  ('hacker', '91.168.50.10', 'fallo'),
  ('carlos', '10.10.0.2',    'exito');

-- Principio de mínimo privilegio:
-- webuser SOLO puede SELECT en empleados
-- SOLO desde 172.16.0.10 (dmz-server)
CREATE USER IF NOT EXISTS 'webuser'@'172.16.0.10'
  IDENTIFIED BY 'webpassword';
GRANT SELECT ON empresa.empleados TO 'webuser'@'172.16.0.10';
FLUSH PRIVILEGES;
SQLEOF

# -----------------------------------------------------------------------------
# PASO 5 — Habilitar y reiniciar MySQL con la nueva configuración
# -----------------------------------------------------------------------------
echo "[*] Habilitando MySQL..."
systemctl enable mysql
systemctl restart mysql

echo ""
echo "=================================================="
echo " vlan20-server configurado correctamente"
echo " IP:           192.168.20.10"
echo " Gateway:      192.168.20.1 (OPNsense VLAN20)"
echo " MySQL:        192.168.20.10:3306 (solo desde 172.16.0.10)"
echo " Acceso admin: solo via VPN wg-admins (10.10.1.0/24)"
echo "=================================================="