#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

#Paquetes base
apt-get update -qq
apt-get install -y -qq \
openssh-server \
mysql-server \
samba \
smbclient

#Malas prácticas para SSH
cat > /etc/ssh/sshd_config << 'EOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
MaxAuthTries 10
LoginGraceTime 120
X11Forwarding no
PrintMotd yes
Banner /etc/ssh/banner
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

cat > /etc/ssh/banner << 'EOF'
*******************************************
  Internal Server 4-insecure-network-lab
  Ubuntu 22.04 LTS
  TFG TSI
*******************************************
EOF

#Contraseña débil
echo "root:root" | chpasswd
systemctl restart ssh

#Mysql sin autenticación t accesible desde cualquier IP
sed -i 's/^bind-address\s*=.*/bind-address=0.0.0.0/' \
  /etc/mysql/mysql.conf.d/mysqld.cnf

systemctl restart mysql
sleep 5

#Comprobar si root ya tiene acceso desde cualquier host
ROOT_CONFIGURED=$(mysql -u root \
  -e "SELECT host FROM mysql.user WHERE user='root' AND host='%';" \
  2>/dev/null | grep -c '%' || true)

if [ "$ROOT_CONFIGURED" -eq 0 ]; then
  mysql -u root << 'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';
UPDATE mysql.user SET host='%' WHERE user='root' AND host='localhost';
FLUSH PRIVILEGES;
SQL
  echo "MySQL root configurado sin contraseña."
else
  echo "MySQL root ya estaba configurado, omitiendo ALTER USER."
fi

#SAMBA.
mkdir -p /srv/samba/confidential
chmod 777 /srv/samba/confidential
#idempotencia
if ! grep -q '\[confidential\]' /etc/samba/smb.conf; then
cat >> /etc/samba/smb.conf << 'EOF'
[confidential]
    path=/srv/samba/confidential
    browsable=yes
    read only=no
    guest ok= yes
    guest only=yes
    create mask = 0777
    directory mask= 0777
    comment= Confidential Documents
EOF
fi
systemctl restart smbd nmbd

#Desactivar ufw, ahora sin firewall.
ufw disable || true


# Detectar interfaz de la red interna (la que tiene 192.168.58.x)
INT_IFACE=$(ip -br addr | awk '/192\.168\.58\./ {print $1}')
echo "Interfaz interna detectada: $INT_IFACE"

# Rutas estáticas temporales
ip route add 192.168.57.0/24 via 192.168.58.1 2>/dev/null || true
ip route add 100.70.9.0/24   via 192.168.58.1 2>/dev/null || true

# Rutas persistentes con el nombre de interfaz real
cat > /etc/netplan/99-lab-routes.yaml << EOF
network:
  version: 2
  ethernets:
    ${INT_IFACE}:
      routes:
        - to: 192.168.57.0/24
          via: 192.168.58.1
        - to: 100.70.9.0/24
          via: 192.168.58.1
EOF
netplan apply

echo "[internal-server] Setup completado."