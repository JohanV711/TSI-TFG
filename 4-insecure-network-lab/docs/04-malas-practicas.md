# 4. Malas prácticas implementadas

Este documento detalla cada una de las configuraciones inseguras introducidas deliberadamente en las máquinas del laboratorio. Para cada mala práctica se describe **qué se ha hecho**, **cómo se ha implementado** y **qué implicaciones tiene** de cara a los ataques.

Se agrupan por máquina: firewall, DMZ e interno.

---

## 4.1 Firewall vulnerable

El equipo `firewall` (Ubuntu Server 22.04) actúa como puerta de enlace entre los tres segmentos, pero **no aplica ningún filtrado real**. Aparenta seguridad porque la política por defecto de FORWARD es DROP, pero las reglas añadidas la anulan por completo.

### 4.1.1 Política DROP en FORWARD… anulada con reglas ACCEPT

**Configuración real (iptables):**

```bash
iptables -P FORWARD DROP

iptables -A FORWARD -i eth1 -o eth2 -j ACCEPT    # externa → DMZ
iptables -A FORWARD -i eth1 -o eth3 -j ACCEPT    # externa → interna
iptables -A FORWARD -i eth2 -o eth3 -j ACCEPT    # DMZ → interna
iptables -A FORWARD -i eth2 -o eth1 -j ACCEPT    # DMZ → externa
iptables -A FORWARD -i eth3 -o eth1 -j ACCEPT    # interna → externa
iptables -A FORWARD -i eth3 -o eth2 -j ACCEPT    # interna → DMZ
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
```

- **Lo que parece**: una política restrictiva que bloquea el tráfico por defecto.
- **Lo que realmente ocurre**: se permite explícitamente cualquier comunicación entre los tres segmentos en ambas direcciones. La regla final de estado permite además todo el tráfico de retorno. Un atacante puede alcanzar cualquier destino sin restricción.
- **Consecuencia directa**: el reconocimiento de red (`nmap`) desde Kali muestra todas las máquinas y servicios, y el atacante puede atacar directamente la red interna sin necesidad de pivoting previo desde la DMZ.

### 4.1.2 Parámetros de kernel inseguros

**Configuración (`/etc/sysctl.d/99-firewall-lab.conf`):**

```text
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.all.accept_source_route = 1
net.ipv4.conf.all.accept_redirects = 1
net.ipv4.conf.all.send_redirects = 1
```

- `ip_forward=1`: necesario para enrutar, pero sin filtrado se convierte en un vector de pivoting.
- `rp_filter=0`: desactiva la verificación de ruta inversa, permitiendo tráfico con IP de origen falsificada (útil para ARP spoofing y suplantación).
- `accept_source_route=1`: permite paquetes con opción `source routing`, que un atacante puede usar para enrutar tráfico por caminos no previstos.
- `accept_redirects=1` y `send_redirects=1`: el firewall acepta y envía mensajes ICMP Redirect, facilitando el envenenamiento de rutas.

**Consecuencia directa**: ataques MITM con `arpspoof` y tráfico spoofeado son viables.

### 4.1.3 Sin logging ni detección

- **Iptables sin reglas LOG**: el tráfico malicioso no se registra en ninguna parte.
- **UFW desactivado**: el firewall local del equipo no filtra accesos al propio sistema.
- **Sin IDS/IPS**: no hay Suricata, Snort ni ninguna herramienta de detección de intrusiones.

**Consecuencia directa**: los ataques de reconocimiento, fuerza bruta y exfiltración no generan ninguna alerta ni dejan rastro en el firewall.

### 4.1.4 Sin NAT

En una red corporativa real, la DMZ y la red interna suelen salir a Internet mediante NAT. Aquí no se configura, lo que permite que las direcciones internas sean visibles desde la red externa y que el tráfico de laboratorio no se distinga del tráfico real.

**Consecuencia directa**: el atacante obtiene las IPs reales de los servidores internos durante el reconocimiento.

---

## 4.2 Servidor DMZ (`dmz-server`)

El servidor DMZ aloja los servicios públicos de la supuesta organización. La configuración es un catálogo de malas prácticas web, FTP, Telnet y de administración del sistema.

### 4.2.1 Apache: información de versión y directory listing

**Configuración:**

```apache
ServerTokens Full
ServerSignature On

<Directory /var/www/html>
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
```

- `ServerTokens Full`: las cabeceras HTTP incluyen la versión exacta de Apache y del sistema operativo (ej: `Apache/2.4.52 (Ubuntu)`).
- `ServerSignature On`: las páginas de error muestran la misma información.
- `Options Indexes`: si no existe un `index.html`, Apache muestra el listado de archivos del directorio.

**Consecuencia directa**: un simple `curl` o el escaneo con `nmap -sV` revela versiones exactas y permite buscar exploits específicos para Apache 2.4.52. El directory listing expone archivos que no deberían ser visibles (backup, admin).

(Insertar captura: `../../images/04-apache-server-tokens.png` mostrando las cabeceras con `curl -I`)

### 4.2.2 `phpinfo()` expuesto

**Configuración**: el archivo `/var/www/html/info.php` contiene `<?php phpinfo(); ?>` y es accesible públicamente.

**Consecuencia directa**: cualquier visitante obtiene la versión de PHP, los módulos cargados, las rutas del sistema, las variables de entorno y la configuración completa del intérprete. Esta información facilita la identificación de vulnerabilidades específicas del stack LAMP.

(Insertar captura: `../../images/04-phpinfo.png`)

### 4.2.3 Panel de administración sin autenticación

**Configuración**: `/var/www/html/admin/index.php` consulta directamente la base de datos interna (`192.168.57.10`, usuario `root`, sin contraseña) y vuelca en una tabla HTML las credenciales de la tabla `user_credentials`.

**Consecuencia directa**: sin necesidad de explotar ninguna vulnerabilidad, el atacante que descubra el directorio `/admin/` obtiene todas las credenciales corporativas almacenadas en la base de datos. Esto representa una violación completa de la confidencialidad.

(Insertar captura: `../../images/04-admin-panel.png`)

### 4.2.4 Directorio `/backup/` accesible públicamente

**Archivos expuestos**:

- `credentials.txt`: contiene credenciales MySQL, FTP, SSH y VPN en texto plano.
- `network.txt`: mapa de red con las IPs de los tres segmentos.

**Consecuencia directa**: el atacante puede descargar ambos archivos con `curl` y obtener de un solo vistazo la topología y las credenciales para el siguiente paso del ataque.

(Insertar captura: `../../images/04-backup-directory.png`)

### 4.2.5 FTP anónimo con permisos de escritura

**Configuración (`/etc/vsftpd.conf`):**

```text
anonymous_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_root=/srv/ftp
no_anon_password=YES
write_enable=YES
```

- Acceso anónimo sin contraseña.
- Posibilidad de subir y crear archivos en el directorio público.
- El archivo `config_backup.txt` contiene las credenciales de la base de datos interna.

**Consecuencia directa**: el atacante accede al FTP con `ftp 192.168.57.10`, usuario `anonymous`, y descarga `config_backup.txt` con las credenciales MySQL. Además, podría utilizar el espacio para alojar malware o herramientas.

### 4.2.6 Telnet activo (texto plano)

**Configuración**: `xinetd` lanza `telnetd` en el puerto 23.

**Consecuencia directa**: cualquier sesión Telnet transmite credenciales y comandos sin cifrar. Con `tcpdump` o `arpspoof` el atacante captura el usuario y la contraseña `ftpoperator:ftpoperator` en texto claro.

(Insertar captura: `../../images/04-telnet-capture.png` con tcpdump mostrando el login)

### 4.2.7 Usuario débil `ftpoperator`

**Configuración**: credencial `ftpoperator:ftpoperator` válida tanto para Telnet como para SSH.

**Consecuencia directa**: fuerza bruta trivial o reutilización de credenciales permite el acceso interactivo al servidor DMZ, desde donde se puede pivotar a la red interna.

### 4.2.8 SSH inseguro

Mismas malas prácticas que en el servidor interno (ver 4.3.1): `PermitRootLogin yes`, `PasswordAuthentication yes`, sin limitación de intentos.

**Consecuencia directa**: puerta trasera adicional si el ataque web o Telnet falla.

### 4.2.9 Sitio de phishing alojado en la DMZ

**Configuración**: VirtualHost Apache en el puerto 8080 que imita la página de login de GitHub. El formulario envía las credenciales a `capture.php`, que las almacena en `/var/log/phishing.log` y redirige a la víctima a la página real de GitHub con un mensaje de error falso.

**Consecuencia directa**: campañas de phishing interno extremadamente creíbles. Las credenciales capturadas se almacenan en texto plano en el propio servidor. El atacante solo tiene que acceder al servidor DMZ y leer el archivo de log para recolectarlas.

(Insertar captura: `../../images/04-phishing-page.png`)

### 4.2.10 Sin firewall local

**Configuración**: `ufw disable`. Ningún filtro de paquetes protege el propio servidor.

**Consecuencia directa**: todos los servicios están expuestos en todas las interfaces. Un atacante que obtenga acceso a la red DMZ puede atacar cualquier puerto abierto.

---

## 4.3 Servidor interno (`internal-server`)

El servidor interno almacena la base de datos corporativa, recursos compartidos Samba con información confidencial y permite acceso SSH sin restricciones. Representa el activo más valioso de la organización simulada y, debido a las malas prácticas, es alcanzable directamente desde fuera.

### 4.3.1 SSH sin restricciones y credenciales débiles

**Configuración (`/etc/ssh/sshd_config`):**

```text
PermitRootLogin yes
PasswordAuthentication yes
MaxAuthTries 10
```

Además, la cuenta `root` tiene la contraseña `root`.

**Consecuencia directa**: fuerza bruta con `hydra -l root -p root ssh://192.168.58.10` exitosa en el primer intento. Inicio de sesión directo como root desde cualquier máquina del laboratorio.

(Insertar captura: `../../images/04-ssh-root-login.png`)

### 4.3.2 Banner de SSH informativo

**Configuración**: el archivo `/etc/ssh/banner` muestra:

```text
**
  Internal Server 4-insecure-network-lab
  Ubuntu 22.04 LTS
  TFG TSI
**
```

**Consecuencia directa**: el banner revela el sistema operativo y su versión antes de autenticarse. Información útil para el atacante (fingerprinting).

### 4.3.3 MySQL sin contraseña y accesible desde toda la red

**Configuración**:

- `bind-address = 0.0.0.0` en `mysqld.cnf`.
- Usuario `root` sin contraseña tanto para conexiones locales (`localhost`) como remotas (`%`).
- Base de datos `corporativedb` con tablas `user_credentials`, `network_inventory` y `employees` sin cifrar.

**Consecuencia directa**: desde Kali o desde la DMZ basta ejecutar `mysql -h 192.168.58.10 -u root` para acceder como administrador a todos los datos corporativos.

(Insertar captura: `../../images/04-mysql-no-password.png`)

### 4.3.4 Samba como invitado con permisos de escritura

**Configuración (`/etc/samba/smb.conf`):**

```text
[confidential]
    path=/srv/samba/confidential
    browsable=yes
    read only=no
    guest ok=yes
    guest only=yes
    create mask = 0777
    directory mask = 0777
```

- Recurso accesible sin autenticación.
- Permisos de lectura y escritura para cualquier usuario.
- Contiene el archivo `passwords.txt` con las credenciales de todos los servicios del laboratorio.

**Consecuencia directa**: `smbclient //192.168.58.10/confidential -N` permite listar y descargar el archivo de contraseñas desde Kali o desde la DMZ. El atacante obtiene en un solo paso todas las credenciales.

(Insertar captura: `../../images/04-samba-guest-access.png`)

### 4.3.5 Sin firewall local

**Configuración**: `ufw disable`.

**Consecuencia directa**: todos los servicios del servidor interno (3306, 445, 139, 22) están expuestos y son alcanzables desde cualquier segmento, incluida la red externa.

### 4.3.6 Rutas estáticas hacia todos los segmentos

**Configuración (netplan):**

```yaml
routes:
  - to: 192.168.57.0/24
    via: 192.168.58.1
  - to: 100.70.9.0/24
    via: 192.168.58.1
```

El servidor interno conoce cómo alcanzar la DMZ y la red externa.

**Consecuencia directa**: no solo el atacante puede llegar a la red interna, sino que, una vez comprometido el servidor interno, este puede iniciar conexiones hacia la DMZ o hacia el exterior para exfiltrar datos (ver 5.6).

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="03-despliegue-acceso.md">← Anterior</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <a href="../README.md">Volver al índice</a>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <a href="05-escenarios-ataque.md">Siguiente →</a>
    </td>
  </tr>
</table>