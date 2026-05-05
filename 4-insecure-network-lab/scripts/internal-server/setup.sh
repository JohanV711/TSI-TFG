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

#Contraseña débil
echo "root:root" | chpasswd

systemctl restart ssh

#Mysql sin autenticación t accesible desde cualquier IP
sed -i 's/^bind-address\s*=.*/bind-address=0.0.0.0/' \
/etc/mysql/mysql.conf.d/mysqld.cnf
systemctl start mysql
sleep 10
systemctl is-active --quiet mysql

#Quitar contraseña root mysql.
mysql -u root << 'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';
UPDATE mysql.user SET host='%' WHERE user ='root' AND host='localhost';
FLUSH PRIVILEGES;
SQL

#SAMBA.
mkdir -p /srv/samba/confidential
chmod 777 /srv/samba/confidential

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

systemctl restart smbd nmbd

#Desactivar ufw, ahora sin firewall.
ufw disable || true

echo "[internal-server] Setup completado."


#Rutas:
ip route add 192.168.57.0/24 via 192.168.58.1 || true
ip route add 100.70.9.0/24 via 192.168.58.1 || true

cat >> /etc/netplan/50-cloud-init.yaml << 'EOF'
network:
  version: 2
  ethernets:
    eth1:
      routes:
        - to: 192.168.57.0/24
          via: 192.168.58.1
        - to: 100.70.9.0/24
          via: 192.168.58.1
EOF
netplan apply || true
echo "rutas de internal-server configuradas correctmanete"
