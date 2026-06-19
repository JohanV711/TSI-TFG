#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Forzar DNS funcional 
systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf

echo "[gui] Instalando escritorio XFCE y TigerVNC..."
apt-get update -qq
apt-get install -y -qq \
    xfce4 \
    xfce4-goodies \
    x11-xserver-utils \
    dbus-x11 \
    tigervnc-standalone-server \
    novnc \
    websockify

# Directorio VNC para vagrant
mkdir -p /home/vagrant/.vnc

# xstartup: lanza XFCE limpio sin session manager ni dbus previos
cat > /home/vagrant/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x /home/vagrant/.vnc/xstartup

# Password VNC: "vagrant" (acceso solo desde localhost vía forwarded_port)
echo "vagrant" | sudo -u vagrant vncpasswd -f > /home/vagrant/.vnc/passwd
chmod 600 /home/vagrant/.vnc/passwd
chown -R vagrant:vagrant /home/vagrant/.vnc

# Servicio VNC (TigerVNC en :1 → puerto 5901)
cat > /etc/systemd/system/vncserver.service << 'UNIT'
[Unit]
Description=TigerVNC server (XFCE) para vagrant
After=network.target

[Service]
Type=simple
User=vagrant
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill :1 > /dev/null 2>&1 || true'
ExecStart=/usr/bin/vncserver :1 \
    -geometry 1280x800 \
    -depth 24 \
    -localhost no \
    -rfbauth /home/vagrant/.vnc/passwd \
    -xstartup /home/vagrant/.vnc/xstartup \
    -fg
ExecStop=/usr/bin/vncserver -kill :1
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

# Servicio noVNC (websockify :8082 → localhost:5901)
cat > /etc/systemd/system/novnc.service << 'UNIT'
[Unit]
Description=noVNC proxy (websockify 8082 → VNC 5901)
After=network.target vncserver.service
Requires=vncserver.service

[Service]
Type=simple
ExecStart=/usr/bin/websockify --web=/usr/share/novnc 8082 localhost:5901
Restart=on-failure
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable vncserver novnc

# Arrancar en orden con espera entre ellos
systemctl start vncserver
sleep 5
systemctl start novnc

echo "[gui] Entorno gráfico listo. Accede en http://localhost:8082/vnc.html (password: vagrant)"