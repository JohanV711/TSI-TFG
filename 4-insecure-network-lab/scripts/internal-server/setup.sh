#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Forzar DNS funcional para evitar cuelgues
systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf

#Paquetes base
apt-get update -qq
apt-get install -y -qq \
openssh-server \
mysql-server \
samba \
netdiscover \
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
grep -q '^bind-address' /etc/mysql/mysql.conf.d/mysqld.cnf \
  && sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf \
  || echo 'bind-address = 0.0.0.0' >> /etc/mysql/mysql.conf.d/mysqld.cnf
systemctl restart mysql
sleep 5

# MySQL: permitir conexiones remotas sin contraseña SIN ELIMINAR el acceso local
set +e
mysql -u root << 'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY '';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
set -e
echo "MySQL root configurado sin contraseña (local + remoto)."

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
# Rutas persistentes con netplan
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