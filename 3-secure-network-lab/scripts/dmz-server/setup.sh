#!/bin/bash
# =============================================================================
# setup.sh — dmz-server (172.16.0.10)
# Servidor web corporativo en zona DMZ
#
# Principios de seguridad aplicados:
#   - Nginx como proxy inverso (no expone Flask directamente)
#   - Flask escucha solo en localhost (127.0.0.1:5000)
#   - Ruta por defecto hacia OPNsense DMZ (no NAT de Vagrant)
#   - Rutas persistentes via rc.local hacia VLANs internas y redes VPN
# =============================================================================

set -e

echo "[*] Iniciando configuración de dmz-server (172.16.0.10)..."
# PASO 1 — Instalar paquetes usando NAT de Vagrant
echo "[*] Actualizando repositorios..."
apt-get update -qq

echo "[*] Instalando Nginx y Python3..."
apt-get install -y nginx python3 python3-pip mariadb-client 2>/dev/null traceroute
pip3 install flask mysql-connector-python --quiet 2>/dev/null || true

# PASO 2 — Rutas persistentes via rc.local
echo "[*] Configurando rutas persistentes hacia OPNsense DMZ..."
cat > /etc/rc.local << 'EOF'
#!/bin/bash
ip route del default 2>/dev/null || true
ip route add default via 172.16.0.1 dev enp0s8 2>/dev/null || true
ip route add 192.168.20.0/24 via 172.16.0.1 dev enp0s8 2>/dev/null || true
ip route add 10.10.1.0/24 via 172.16.0.1 dev enp0s8 2>/dev/null || true
ip route add 10.10.2.0/24 via 172.16.0.1 dev enp0s8 2>/dev/null || true
exit 0
EOF
chmod +x /etc/rc.local
systemctl enable rc-local 2>/dev/null || true
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
          via: 172.16.0.1
        - to: 192.168.20.0/24
          via: 172.16.0.1
        - to: 192.168.10.0/24
          via: 172.16.0.1
        - to: 10.10.1.0/24
          via: 172.16.0.1
        - to: 10.10.2.0/24
          via: 172.16.0.1
      nameservers:
        addresses: [172.16.0.1]
EOF
netplan apply
ip route del default 2>/dev/null || true
ip route add default via 172.16.0.1 dev enp0s8 2>/dev/null || true
ip route add 192.168.20.0/24 via 172.16.0.1 dev enp0s8 2>/dev/null || true
ip route add 10.10.1.0/24 via 172.16.0.1 dev enp0s8 2>/dev/null || true
ip route add 10.10.2.0/24 via 172.16.0.1 dev enp0s8 2>/dev/null || true

# PASO 3 — Crear aplicación Flask
echo "[*] Creando aplicación web corporativa..."
mkdir -p /opt/webapp
cat > /opt/webapp/app.py << 'EOF'
from flask import Flask, jsonify, render_template_string
import mysql.connector

app = Flask(__name__)

DB_CONFIG = {
    'host':     '192.168.20.10',
    'user':     'webuser',
    'password': 'webpassword',
    'database': 'empresa'
}

TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
  <title>Portal Corporativo — Lab ENS</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
    h1   { color: #2B5EA7; }
    .badge { background: #2B5EA7; color: white; padding: 4px 10px;
             border-radius: 4px; font-size: 12px; }
  </style>
</head>
<body>
  <h1>Portal Corporativo</h1>
  <p><span class="badge">ACCESO RESTRINGIDO</span></p>
  <p>Solo accesible mediante VPN autenticada. Laboratorio de ciberseguridad ENS.</p>
  <hr>
  <a href="/empleados">Ver listado de empleados</a>
</body>
</html>
"""

@app.route('/')
def index():
    return render_template_string(TEMPLATE)

@app.route('/empleados')
def empleados():
    try:
        conn   = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT id, nombre, departamento FROM empleados")
        datos  = cursor.fetchall()
        conn.close()
        return jsonify(datos)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=False)
EOF

chown -R www-data:www-data /opt/webapp

# PASO 4 — Configurar Nginx como proxy inverso
echo "[*] Configurando Nginx como proxy inverso..."
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass         http://127.0.0.1:5000;
        proxy_set_header   Host            $host;
        proxy_set_header   X-Real-IP       $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
nginx -t

# PASO 5 — Crear servicio systemd para Flask
echo "[*] Creando servicio systemd para Flask..."
cat > /etc/systemd/system/webapp.service << 'EOF'
[Unit]
Description=Portal Web Corporativo - Lab ENS
After=network.target

[Service]
User=www-data
WorkingDirectory=/opt/webapp
ExecStart=/usr/bin/python3 /opt/webapp/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable webapp nginx
systemctl start webapp || true
sleep 2
systemctl restart nginx

sudo chmod 600 /etc/netplan/99-lab-routes.yaml
ip route del default via 10.0.2.2 dev enp0s3 2>/dev/null || true
ip route add default via 172.16.0.1 dev enp0s8 2>/dev/null || true
echo " dmz-server configurado correctamente"
echo " IP:           172.16.0.10"
echo " Gateway:      172.16.0.1 (OPNsense DMZ)"
echo " Portal web:   http://172.16.0.10"
echo " Empleados:    http://172.16.0.10/empleados"
echo " Acceso:       solo via VPN wg-users y wg-admins"