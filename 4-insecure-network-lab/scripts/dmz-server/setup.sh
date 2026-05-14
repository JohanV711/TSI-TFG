#!/usr/bin/env bash
#DMZ con malas prácticas
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

#Paquetes base
apt-get update -qq
apt-get install -y -qq \
apache2 \
vsftpd \
xinetd \
inetutils-telnetd \
php \
php-mysql \
mysql-client \
libapache2-mod-php \
smbclient \
dsniff \
netdiscover \
openssh-server

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
mkdir -p /srv/ftp/public
#/srv/ftp dueño ftp, sin escritura para nadie porque vsftpd lo exige.
chown ftp:ftp /srv/ftp
chmod 555 /srv/ftp

chown ftp:ftp /srv/ftp/public
chmod 777 /srv/ftp/public

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
anon_root=/srv/ftp
no_anon_password=YES
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=30100
EOF

systemctl enable vsftpd
systemctl restart vsftpd

#Telnet servicio de puerto 23 con texto en claro y captura de credenciales con Wireshark/tcpdump.
cat > /etc/xinetd.d/telnet << 'EOF'
service telnet
{
flags = REUSE
socket_type = stream
wait = no
user = root
server = /usr/sbin/telnetd
log_on_failure += USERID
disable = no
}
EOF

systemctl enable xinetd
systemctl restart xinetd

#Usuario débil para Telnet y FTP con credenciales por defecto.
id ftpoperator || useradd -m -s /bin/bash ftpoperator
echo "ftpoperator:ftpoperator" | chpasswd
#Quitar firewall local
ufw disable || true

# Detectar interfaz de la red DMZ (la que tiene 192.168.57.x)
DMZ_IFACE=$(ip -br addr | awk '/192\.168\.57\./ {print $1}')
echo "Interfaz DMZ detectada: $DMZ_IFACE"

cat > /etc/netplan/99-lab-routes.yaml << EOF
network:
  version: 2
  ethernets:
    ${DMZ_IFACE}:
      routes:
        - to: 192.168.58.0/24
          via: 192.168.57.1
        - to: 100.70.9.0/24
          via: 192.168.57.1
EOF
netplan apply

cat > /etc/ssh/sshd_config << 'EOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
MaxAuthTries 10
LoginGraceTime 120
X11Forwarding no
PrintMotd yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

systemctl restart ssh

echo "[dmz-server] setup completado."