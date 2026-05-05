#!/usr/bin/env bash
#DMZ con malas prácticas
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

#Paquetes base
apt-get update -qq
apt-get install -y -qq \
apache2 \
vsftpd \
telnetd \
xinetd \
php \
php-mysql \
libapache2-mod-php

#Malas prácticas para Apache
cat > /etc/apache2/conf-available/insecure.conf << 'EOF'
ServerTokens Full
ServerSignature On

<Directory /var/www/html>
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
EOF

a2enconf insecure
systemctl restart apache2

#vsftpd- FTP anónimo sin restricciones que permite acceder y descargar ficheros sin autenticación.
cat > /etc/vsftpd.conf << 'EOF'
listen=YES
listen_ipv6=NO
anonymous_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
local_enable=YES
write_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=NO
connect_from_port_20=YES
ftp_banner=vsftpd 3.0.3 - CorpNet FTP Server
anon_root=/srv/ftp
no_anon_password=YES
EOF

mkdir -p /srv/ftp/public
chmod 777 /srv/ftp/public
chown -R ftp:ftp /srv/ftp

systemctl restart vsftpd

#Telnet servicio de puerto 23 con texto en claro y captura de credenciales con Wireshark/tcpdump.

cat > /etc/xinetd.d/telnet << 'EOF'
service telnet
{
flags=REUSE
socket_type=stream
wait=no
user=root
server=/usr/sbin/in.telnetd
log_on_failure+=USERID
disable=no
}
EOF

systemctl restart xinetd

#Usuario débil para Telnet y FTP con credenciales por defecto.
id ftpoperator || useradd -m -s /bin/bash ftpoperator
echo "ftpoperator:ftpoperator" | chpasswd
#Quitar firewall local
ufw disable || true
echo "[dmz-server] setup completado."


#Ruta hacia red interna pasando por el firewall:
ip route add 192.168.58.0/24 via 192.168.57.1 || true
ip route add 100.70.9.0/24 via 192.168.57.1 || true

cat >> /etc/netplan/50-cloud-init.yaml << 'EOF'
network:
  version: 2
  ethernets:
    eth1:
      routes:
        - to: 192.168.58.0/24
          via: 192.168.57.1
        - to: 100.70.9.0/24
          via: 192.168.57.1
EOF
netplan apply || true
echo "rutas de dmz-server configuradas correctmanete"

