#!/usr/bin/env bash
# Interfaz gráfica ligera (XFCE) + noVNC para Kali atacante
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Forzar DNS funcional para evitar cuelgues
systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf

echo "[gui] Instalando escritorio XFCE y herramientas VNC..."

apt-get update -qq
apt-get install -y -qq \
    xfce4 \
    xfce4-goodies \
    lightdm \
    x11-xserver-utils \
    x11vnc \
    novnc \
    websockify

# Auto-login del usuario vagrant en XFCE
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf << 'LIGHTDM'
[Seat:*]
autologin-user=vagrant
autologin-user-timeout=0
LIGHTDM

# Evitar bloqueos de sesión y salvapantallas
sudo -u vagrant bash << 'USER'
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="dpms-enabled" type="bool" value="false"/>
</channel>
EOF
USER

# Servicio de sistema para x11vnc (depende de lightdm)
cat > /etc/systemd/system/x11vnc.service << 'UNIT'
[Unit]
Description=VNC server for X11 (x11vnc)
After=lightdm.service
Requires=lightdm.service

[Service]
Type=simple
ExecStartPre=/bin/sleep 3
ExecStart=/usr/bin/x11vnc -forever -shared -display :0 -auth /var/run/lightdm/root/:0 -rfbport 5900 -o /var/log/x11vnc.log
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
UNIT

# Servicio de sistema para noVNC (puerto 8080)
cat > /etc/systemd/system/novnc.service << 'UNIT'
[Unit]
Description=noVNC proxy
After=network.target x11vnc.service
Requires=x11vnc.service

[Service]
Type=simple
ExecStart=/usr/bin/websockify --web=/usr/share/novnc 8080 localhost:5900
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
UNIT

# Habilitar e iniciar todo
systemctl daemon-reload
systemctl enable x11vnc 2>/dev/null || true
systemctl enable lightdm 2>/dev/null || true
systemctl enable novnc   2>/dev/null || true

systemctl start lightdm 2>/dev/null || true
sleep 5  # Esperar a que la sesión gráfica esté lista
systemctl start x11vnc  2>/dev/null || true
systemctl start novnc   2>/dev/null || true

echo "[gui] Entorno gráfico listo. Accede en http://localhost:8081/vnc.html"