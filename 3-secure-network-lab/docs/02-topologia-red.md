## 2. Topología de red

### 2.1 Diagrama de red

![Diagrama de red](images/diagramadered.png)  
*Figura 1: Topología del laboratorio. Las líneas representan enlaces de red entre las máquinas virtuales. Las nubes indican las redes internas de VirtualBox utilizadas para la segmentación.*

---

### 2.2 Descripción de zonas y segmentos

La arquitectura se organiza en cinco zonas diferenciadas, replicando un modelo de defensa en profundidad común en entornos corporativos:

**Zona WAN (91.168.50.0/24)**  
Simula la red externa, no confiable. Contiene la máquina atacante `external-kali` y la interfaz WAN del firewall. El tráfico desde esta zona hacia el interior está restringido por defecto, permitiendo únicamente respuestas a conexiones ya establecidas o tráfico explícitamente autorizado (como las conexiones entrantes a los túneles WireGuard).

**Zona DMZ (172.16.0.0/24)**  
Red desmilitarizada donde reside el servidor web corporativo (`dmz-server`). Esta zona tiene acceso controlado desde el exterior únicamente a través de las VPNs, y desde aquí se permite la consulta a la base de datos en VLAN20. No tiene acceso a la red de gestión, limitando el movimiento lateral en caso de compromiso.

**Zona de Gestión – VLAN10 (192.168.10.0/24)**  
Red dedicada exclusivamente a la administración del firewall OPNsense. **No aloja máquinas virtuales adicionales**, su único propósito es ofrecer la WebUI de OPNsense en `192.168.10.1`. El acceso está restringido a la VPN de administradores (`wg-admins`), impidiendo que usuarios estándar o equipos comprometidos de otras zonas alcancen la consola de gestión del firewall.

**Zona de Servidores – VLAN20 (192.168.20.0/24)**  
Red de máxima restricción que alberga la base de datos (`vlan20-server`) con información sensible simulada. Solo acepta conexiones entrantes al puerto 3306 desde la DMZ, y únicamente permite tráfico de gestión desde la VPN de administradores. Cualquier otro tráfico es denegado y registrado.

**Red VPN**  
Dos subredes virtuales internas para los clientes WireGuard:  
- `10.10.1.0/24` para administradores (`wg-admins`), con acceso completo a todas las zonas internas.  
- `10.10.2.0/24` para usuarios (`wg-users`), con acceso limitado al portal web en la DMZ y salida a internet, pero sin visibilidad sobre la red de gestión ni la VLAN de servidores.

Es importante mencionar que todas las máquinas internas (salvo `external-kali`) carecen de interfaz NAT propia de VirtualBox operativa para la salida a internet, forzando que cualquier tráfico hacia el exterior **pase obligatoriamente** por OPNsense y sus políticas de filtrado.

---

### 2.3 Tabla de máquinas virtuales

| Máquina virtual | Zona | IP principal | Otras IPs | Interfaces | Propósito |
|-----------------|------|--------------|-----------|------------|-----------|
| **opensense** | WAN / DMZ / VLAN10 / VLAN20 | 91.168.50.1 (WAN) | 172.16.0.1 (DMZ), 192.168.10.1 (VLAN10), 192.168.20.1 (VLAN20) | em0 (NAT implícita), em1 (WAN), em2 (DMZ), em3 (VLAN10), em4 (VLAN20), wg0 (wgadmins), wg1 (wgusers) | Firewall, router, VPN, IDS, DNS |
| **external-kali** | WAN | 91.168.50.10 | 10.10.1.51 (wg-admins), 10.10.2.51 (wg-users) | eth0 (NAT propia), eth1 (WAN lab) | Máquina atacante, cliente VPN, pruebas de conectividad |
| **dmz-server** | DMZ | 172.16.0.10 | — | enp0s3 (NAT deshabilitada para salidaa internet), enp0s8 (DMZ) | Servidor web con portal corporativo, cliente MariaDB |
| **vlan20-server** | VLAN20 | 192.168.20.10 | — | enp0s3 (NAT deshabilitada para salida a internet), enp0s8 (VLAN20) | Servidor de base de datos con datos sensibles |

---

### 2.4 Matriz de comunicaciones permitidas y bloqueadas

La siguiente tabla resume el comportamiento esperado del firewall entre las distintas zonas y perfiles. Se indica **P** (permitido) o **B** (bloqueado), junto con el detalle del tráfico autorizado cuando procede.

| Origen | Destino | Puerto / Servicio | Resultado | Notas |
|--------|---------|-------------------|:---------:|-------|
| external-kali (sin VPN) | OPNsense WAN (91.168.50.1) | 51820, 51821 UDP | **P** | Necesario para establecer túneles WireGuard |
| external-kali (sin VPN) | DMZ (172.16.0.10) | 80 HTTP | **B** | Portal web inaccesible sin VPN |
| external-kali (sin VPN) | VLAN20 (192.168.20.10) | 3306 MySQL | **B** | Base de datos nunca expuesta sin VPN |
| external-kali (sin VPN) | VLAN10 (192.168.10.1) | 443 HTTPS | **B** | Gestión OPNsense solo por VPN admins |
| external-kali (wg-admins) | DMZ (172.16.0.10) | 80 HTTP, 443 | **P** | Acceso completo al portal web |
| external-kali (wg-admins) | VLAN20 (192.168.20.10) | 22 SSH, 3306 MySQL | **P** | El firewall permite el acceso a la base de datos pero MariaDB **restringe** conexiones a nivel de aplicación (webuser solo desde 172.16.0.10). Defensa en profundidad: **dos capas de control independientes** |
| external-kali (wg-admins) | VLAN10 (192.168.10.1) | 443 HTTPS | **P** | WebUI de gestión OPNsense |
| external-kali (wg-admins) | Internet (8.8.8.8:53) | DNS | **B** (pero interceptado) | El DNS se fuerza a Unbound; bloqueo de dominios |
| external-kali (wg-users) | DMZ (172.16.0.10) | 80 HTTP | **P** | Acceso al portal web y /empleados |
| external-kali (wg-users) | VLAN20 (192.168.20.10) | Cualquier puerto | **B** | Sin acceso a servidores internos |
| external-kali (wg-users) | VLAN10 (192.168.10.1) | 443 HTTPS | **B** | Sin acceso a la gestión |
| dmz-server (172.16.0.10) | vlan20-server (192.168.20.10) | 3306 MySQL | **P** | Consultas a la base de datos desde el portal web |
| dmz-server (172.16.0.10) | VLAN10 (192.168.10.1) | Cualquier puerto | **B** | DMZ no debe alcanzar la red de gestión |
| dmz-server (172.16.0.10) | Internet | 80, 443, DNS | **P** | Tráfico de actualizaciones y DNS (forzado a Unbound) |
| vlan20-server (192.168.20.10) | DMZ (172.16.0.10) | Cualquier puerto | **B** | No puede iniciar conexiones hacia DMZ; las respuestas MySQL son tráfico de retorno permitido por estado |
| vlan20-server (192.168.20.10) | Internet | 80, 443, DNS | **P** | Actualizaciones controladas, DNS forzado |
| vlan20-server (192.168.20.10) | VLAN10 (192.168.10.1) | Cualquier puerto | **B** | Aislamiento total de la red de gestión |
| Cualquier cliente VPN (admins/users) | Internet | 80, 443 | **P** | Navegación web a través de OPNsense |
| Cualquier cliente VPN (admins/users) | DNS (8.8.8.8:53) | 53 UDP | **B** (interceptado) | El firewall redirige el DNS a Unbound; si se usa DNS externo, los dominios prohibidos se bloquean igual |
| Todos los hosts internos | Instagram, Facebook (dominios) | DNS | **B** (0.0.0.0) | Bloqueo DNS en Unbound |