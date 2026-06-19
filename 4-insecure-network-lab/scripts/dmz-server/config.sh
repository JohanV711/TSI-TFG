#!/usr/bin/env bash
#Contenido web básico de prueba y FTP inseguro

set -euo pipefail

#Página web principal vulnerable.
cat > /var/www/html/index.html << 'EOF' 
<!DOCTYPE html> 
<html lang="es"> 
<head> 
<meta charset="UTF-8"> 
<title>CorpNet - Portal Interno</title> 
</head> 
<body> 
<h1>CorpNet S.A. - Portal de Servicios</h1> 
<p>Servidor: dmz-web01 | Ubuntu 22.04 LTS | Apache 2.4.52</p> 
<ul> 
<li><a href="/admin/">Panel de administración</a></li> 
<li><a href="/backup/">Directorio de backups</a></li> 
<li><a href="/info.php">Información del servidor</a></li> 
</ul> 
</body> 
</html> 
EOF

#phpinfo() expuesto públicamente
cat > /var/www/html/info.php << 'EOF'
<?php phpinfo(); ?>
EOF

#Panel de administración sin autenticación.
mkdir -p /var/www/html/admin 
cat > /var/www/html/admin/index.php << 'EOF' 
<?php 
// Panel de administración sin autenticación 
$db = new mysqli("192.168.58.10", "root", "", "corporativedb"); 
$result = $db->query("SELECT username, password, service FROM user_credentials"); 
?> 
<!DOCTYPE html> 
<html lang="es"> 
<head><meta charset="UTF-8"><title>Admin Panel</title></head> 
<body> 
<h2>Panel de Administración - CorpNet</h2> 
<h3>Credenciales de usuarios</h3> 
<table border="1"> 
<tr><th>Usuario</th><th>Contraseña</th><th>Servicio</th></tr> 
<?php while($row = $result->fetch_assoc()): ?> 
<tr> 
<td><?= $row['username'] ?></td> 
<td><?= $row['password'] ?></td> 
<td><?= $row['service'] ?></td> 
</tr> 
<?php endwhile; ?> 
</table> 
</body> 
</html> 
EOF

#Directorio de backups accesible vía web.
mkdir -p /var/www/html/backup
cat > /var/www/html/backup/credentials.txt << 'EOF'
MySQL root: root/ (sin contraseña)
FTP operator: ftpoperator/ftpoperator
SSH interno: root/root
VPN admin: admin/admin123
EOF

cat > /var/www/html/backup/network.txt << 'EOF'
Firewall: 100.70.9.1
DMZ: 192.168.57.10
Interno: 192.168.58.10
EOF

chmod -R 755 /var/www/html


#Ficheros en el FTP.
cat > /srv/ftp/public/readme.txt << 'EOF' 
Servidor FTP corporativo 
Acceso público al directorio /public 
Para soporte: admin@empresa.local 
EOF 

echo "Configurado readme.txt"

cat > /srv/ftp/public/config_backup.txt << 'EOF' 
DB_HOST=192.168.58.10 
DB_USER=root 
DB_PASS= 
DB_NAME=corporativedb 
SMTP_USER=notificaciones@empresa.local 
SMTP_PASS=smtp2024! 
EOF

echo "configurado config_backup.txt"

chmod -R 755 /srv/ftp/public

systemctl restart apache2
systemctl restart vsftpd

echo "[dmz-server] Configuración completada."


