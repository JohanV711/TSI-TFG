# 3-secure-network-lab — Guía práctica de arquitectura de red segura

## 1. Introducción y contexto

### 1.1 Propósito del laboratorio
Este laboratorio reproduce, en un entorno controlado y virtualizado, una arquitectura de red corporativa segmentada y securizada siguiendo los principios del Esquema Nacional de Seguridad (ENS). El objetivo es doble:

- **Demostrar buenas prácticas de defensa en profundidad** mediante la implementación de un firewall perimetral (OPNsense), segmentación en zonas de confianza (WAN, DMZ, VLAN de gestión, VLAN de servidores), acceso remoto con VPN (WireGuard) con diferentes niveles de privilegio, monitorización con IDS (Suricata) y políticas de DNS forzado.
- **Servir como plataforma de pruebas ofensivas y defensivas** para estudiantes y profesionales, permitiendo lanzar ataques controlados desde una máquina atacante externa (`external-kali`) y verificar la efectividad de las medidas de protección sobre servicios internos simulados (portal web corporativo, base de datos con datos sensibles).

Todo el entorno se despliega automáticamente mediante Vagrant + VirtualBox, lo que garantiza **reproducibilidad** y un punto de partida **idéntico** en cualquier equipo.

### 1.2 ¿Por qué este laboratorio es relevante?
Uno de los pilares de la ciberseguridad es la arquitectura segura de la infraestructura de comunicaciones entre dispositivos, por tanto su buena comprensión es crucial. Por ello este bloque ayuda a la práctica y entendimiento de cómo proteger una infraestructura de redes siguiendo un modelo corporativo y cubriendo los siguientes puntos:

- **Experimentar con configuraciones reales** de firewalls de nueva generación (OPNsense), segmentación de red, VPNs modernas y mecanismos de inspección profunda de paquetes.
- **Validar la eficacia de las políticas de seguridad** frente a escaneos, intentos de intrusión y movimientos laterales simulados.
- **Comprender las implicaciones de una mala configuración** (ej., rutas por defecto duplicadas, servicios escuchando en `0.0.0.0`, credenciales no restrictivas) y cómo subsanarlas, aunque esto se detalla mejor en el bloque 4 de este proyecto.
- **Prepararse para certificaciones y roles profesionales** donde se requiere diseñar, implementar y auditar arquitecturas de red seguras.

La elección de OPNsense como firewall central se debe a su creciente adopción empresarial como alternativa open-source a soluciones comerciales, y a que incorpora funcionalidades avanzadas (IDS/IPS, filtrado DNS, VPN, portal cautivo) en una única plataforma gestionable vía web.

### 1.3 Relación con el Esquema Nacional de Seguridad (ENS)
La arquitectura implementada se alinea directamente con varias de las medidas del Anexo II del ENS, en particular:

| Medida ENS | Aplicación en el laboratorio |
|------------|-------------------------------|
| **Protección de las instalaciones e infraestructuras** | Segmentación física/lógica en VLANs y redes internas de VirtualBox (WAN, DMZ, Gestión, Servidores). |
| **Protección de las comunicaciones** | Cifrado de las comunicaciones de gestión y de usuario mediante túneles WireGuard. HTTPS para la WebUI de OPNsense. |
| **Control de acceso lógico** | Listas de control de acceso en OPNsense por interfaz, restricción de MySQL a `webuser` solo desde `dmz-server` (172.16.0.10), autenticación independiente en la base de datos (defensa en profundidad). |
| **Prevención ante otros sistemas de información interconectados** | Firewall que deniega todo el tráfico por defecto; solo se habilita explícitamente lo necesario. |
| **Detección y respuesta ante incidentes** | Suricata IDS activo en la WAN y DMZ generando alertas ante escaneos y patrones de ataque; registro habilitado para cumplir con **trazabilidad**. |
| **Continuidad de la gestión y monitorización** | Servicios monitorizables vía WebUI y logs persistentes; el propio laboratorio puede ampliarse con un SIEM (Security Information and Event Management para tener un mejor control y registro de los logs de todos los dispositivos de la infraestructura). |

Además, la existencia de dos perfiles de VPN (administradores y usuarios) refleja el principio de **mínimo privilegio** exigido por el ENS, limitando el acceso a recursos sensibles (base de datos, gestión del firewall) únicamente al personal autorizado.

### 1.4 Casos de uso reales donde aplicaría esta arquitectura
El diseño presentado es extrapolable a múltiples escenarios empresariales reales:

- **Pequeña y mediana empresa con teletrabajo seguro**:  
  La DMZ aloja un portal web corporativo accesible solo por VPN. La VLAN de servidores protege la base de datos que contiene datos sensibles. Los administradores acceden a la gestión del firewall desde casa a través de una VPN exclusiva con mayor nivel de privilegio.

- **Entidad gubernamental o educativa que maneja datos sensibles**:  
  La segmentación entre la red de gestión (VLAN10) y la de servidores (VLAN20) impide que un atacante que comprometa el servidor web pueda saltar directamente a la consola del firewall. El **DNS forzado** y el **filtrado de dominios** (bloqueo de redes sociales o contenido no autorizado) cumplen con políticas de uso aceptable.

- **Laboratorio de formación en ciberseguridad (red team / blue team)**:  
  Se pueden simular ataques desde `external-kali` sin afectar la salida a internet de la organización, ya que esa máquina tiene su propia conexión NAT aislada. El blue team puede monitorizar las alertas de Suricata y ajustar las reglas de firewall para contrarrestar las intrusiones.

- **Demostración de cumplimiento normativo (ENS, ISO 27001)**:  
  La trazabilidad de todas las reglas de bloqueo, los logs de DNS y las alertas del IDS proporcionan evidencias auditables de que se están aplicando controles de seguridad efectivos.

Esta arquitectura, aunque desplegada en un solo host gracias a la virtualización, es perfectamente escalable a hardware dedicado mediante switches gestionables (VLANs 802.1Q) y múltiples servidores físicos.

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

## 3. Requisitos previos

### 3.1 Software necesario

El laboratorio se despliega y gestiona completamente desde la máquina anfitriona utilizando las siguientes herramientas:

| Software | Versión mínima | Uso |
|----------|:--------------:|-----|
| [VirtualBox](https://www.virtualbox.org/) | 6.1 o superior | Hipervisor que ejecuta todas las máquinas virtuales |
| [Vagrant](https://www.vagrantup.com/) | 2.3 o superior | Orquestador que aprovisiona y configura las MV desde el Vagrantfile |
| Cliente SSH (OpenSSH, PuTTY, etc.) | cualquiera | Acceso por terminal a las MV (opcional, principalmente a `external-kali`) |
| Navegador web moderno | actual, moderna | Acceso a la WebUI de OPNsense, portal web de la DMZ y escritorio noVNC |

**Sistemas operativos anfitriones compatibles:**
- Linux (Ubuntu 22.04/24.04 LTS recomendado)
- Windows 10/11 con VirtualBox y Vagrant instalados
- macOS (Intel y Apple Silicon, este último con limitaciones conocidas en VirtualBox)

No se requieren plugins adicionales de Vagrant, ya que las redes privadas y las redes internas de VirtualBox se definen directamente en el Vagrantfile sin necesidad de extensiones externas.

### 3.2 Recursos hardware recomendados

El despliegue simultáneo de las cuatro máquinas virtuales requiere una cantidad considerable de memoria y CPU. Las cifras que se indican a continuación corresponden a la configuración asignada en el Vagrantfile y a los valores recomendados para un funcionamiento fluido.

| MV | RAM asignada | vCPUs |
|----|:------------:|:-----:|
| opensense | 1500 MB | 1 |
| external-kali | 2560 MB | 2 |
| dmz-server | 612 MB | 1 |
| vlan20-server | 612 MB | 1 |
| **Total asignado** | **5284 MB** | **5** |

**Recomendación para el anfitrión:**
- **RAM total**: mínimo 8 GB; recomendado 16 GB para holgura del sistema operativo anfitrión.
- **CPU**: procesador de 4 núcleos físicos o superior, con soporte de virtualización (Intel VT-x / AMD-V) habilitado en BIOS/UEFI.
- **Disco duro**: aproximadamente 30 GB libres para las MV y las imágenes base descargadas. Se recomienda SSD para tiempos de arranque y provisión aceptables.

Los valores de RAM del laboratorio ya están optimizados para entornos con recursos limitados. Aun así, es posible levantar solo un subconjunto de máquinas mediante comandos `vagrant up opensense dmz-server` donde se levantarían la MV del firewall y el dmz-server por ejemplo.

### 3.3 Puertos y configuración del host

La máquina anfitriona solo expone un puerto hacia el exterior de la infraestructura virtual hacia la máquina anfitriona, destinado al acceso gráfico de `external-kali`. El resto de las comunicaciones se realizan a través de las redes internas de VirtualBox y, en su caso, mediante las VPNs.

**Puerto utilizado en el host:**

| Puerto host | MV destino | Servicio |
|:-----------:|------------|----------|
| **8081** | external-kali | noVNC (escritorio virtual) |

**Cómo acceder al escritorio virtual:**
1. Arrancar `external-kali` con `vagrant up external-kali` (o `vagrant reload external-kali` si ya estaba creada).
2. Esperar a que los servicios `vncserver` y `novnc` terminen de levantarse (el provisionamiento los configura automáticamente).
3. Abrir en el navegador:  
   [http://localhost:8081/vnc.html](http://localhost:8081/vnc.html)
4. La contraseña VNC es `vagrant`.

Este mecanismo utiliza una redirección de puertos definida en el Vagrantfile (`8081:8081`) y websockify redirige del puerto 8081 al servidor VNC local de la MV (puerto 5901). No se necesita ninguna configuración adicional de red en el anfitrión.

**Acceso a la WebUI de OPNsense:**
La gestión del firewall no se expone directamente en el host. Para acceder a la WebUI (https://192.168.10.1) es necesario:
- Conectar primero la VPN de administradores en `external-kali`.
- Acceder a un navegador dentro de `external-kali` e introducir la URL del OPNsense (https://192.168.10.1).
- Aunque aparezca que la web no es segura hay que continuar, dándole a *avanzado* y continuar hacia el portal we.

**Redes internas de VirtualBox:**
El Vagrantfile crea cuatro redes internas que no son accesibles desde el anfitrión salvo que se configure explícitamente un puente o reenvío de puertos adicional. Estas redes son:
- `net-wan`
- `net-dmz`
- `net-gestion`
- `net-lan`

No se recomienda modificar esta configuración para mantener la integridad del laboratorio.

## 4. Despliegue del laboratorio

### 4.1 Clonar el repositorio

El laboratorio se distribuye como parte del repositorio del TFG. El primer paso es clonar el código en la máquina anfitriona:

```bash
git clone https://github.com/JohanV711/TSI-TFG.git
cd TFG/3-secure-network-lab
```

Dentro de este directorio se encuentran:

- `Vagrantfile` — definición de las máquinas virtuales y sus redes.
- `scripts/` — provisionadores de cada MV.
- `README.md` — esta misma guía.

No se requiere ninguna configuración adicional antes del despliegue. Vagrant descargará automáticamente las boxes necesarias (`snl-opensense/snl-opensense`, `kalilinux/rolling` y `ubuntu/jammy64`) en el primer `vagrant up`.

### 4.2 Levantar las máquinas virtuales

El laboratorio puede levantarse completo o por partes. El comando principal es:

```bash
vagrant up
```

Este comando crea y provisiona las cuatro MV en paralelo, respetando las dependencias de red definidas en el `Vagrantfile`. El proceso completo puede tardar entre 15 y 30 minutos dependiendo de la velocidad de conexión y del hardware del anfitrión.

Si se desea levantar una MV concreta:

```bash
vagrant up opensense
vagrant up dmz-server
vagrant up vlan20-server
vagrant up external-kali
```

**Nota importante:** la primera vez que se ejecuta `vagrant up` para una MV, Vagrant ejecutará el script de provisionamiento correspondiente (`setup.sh` y, en el caso de `external-kali`, también `gui.sh`). Esto configura automáticamente interfaces, rutas, servicios y credenciales. No es necesario ejecutar nada manualmente dentro de las MV para la configuración base.

### 4.3 Orden de arranque recomendado

Aunque Vagrant es capaz de levantar todas las MV en paralelo, se recomienda el siguiente orden para garantizar que los servicios dependientes estén disponibles al finalizar el provisionamiento:

- `opensense` — el firewall debe estar operativo antes que el resto, ya que actúa como gateway y servidor DNS para las demás MV.
- `dmz-server` y `vlan20-server` — estos dos servidores pueden levantarse en cualquier orden una vez que OPNsense está listo. La conexión entre ellos (MariaDB) se establece en el provisionamiento, pero no depende de un orden estricto.
- `external-kali` — la máquina atacante se puede levantar en cualquier momento, pero conviene hacerlo al final para que los servidores internos ya estén totalmente configurados antes de lanzar las pruebas de conectividad.

En la práctica, un simple `vagrant up` lanza las cuatro MV y, aunque los tiempos de provisionamiento pueden solaparse, el resultado final es consistente gracias a las comprobaciones incluidas en los scripts (espera activa de MySQL, reintentos de conexión, etc.).

Para reconstruir una MV desde cero (por ejemplo, si se desea volver al estado inicial de las pruebas):

```bash
vagrant destroy <nombre_mv>
vagrant up <nombre_mv>
```

### 4.4 Verificación inicial de que todo está en pie

Una vez finalizado el provisionamiento, conviene realizar unas comprobaciones rápidas para confirmar que las MV están ejecutándose y los servicios básicos arrancados. 

**Paso 1: Estado de las máquinas virtuales**

```bash
vagrant status
```

Debe mostrar `running` para las cuatro MV.

**Paso 2: Verificar que los servicios escuchan localmente en cada servidor**

Conectarse a `dmz-server` y comprobar que Nginx está activo:

```bash
vagrant ssh dmz-server
systemctl status nginx
curl -s http://127.0.0.1 | head -5
exit
```

Conectarse a `vlan20-server` y comprobar que MariaDB está activo y escucha en su IP interna:

```bash
vagrant ssh vlan20-server
sudo systemctl status mysql
sudo ss -tlnp | grep 3306
```

Debe mostrar `192.168.20.10:3306`, no `127.0.0.1`.

```bash
exit
```

**Paso 3: Escritorio virtual de `external-kali`**

Abrir en el navegador del anfitrión: [http://localhost:8081/vnc.html](http://localhost:8081/vnc.html)

La contraseña VNC por defecto es `vagrant`. Debe aparecer el escritorio XFCE de Kali Linux. Este acceso gráfico confirma que `external-kali` está completamente operativa.

**Paso 4: Interfaces de red esperadas**

Dentro de `external-kali` (vía SSH o terminal VNC), verificar que las interfaces están configuradas:

```bash
ip a | grep -E "eth0|eth1"
```

- `eth0`: NAT propia (`10.0.2.15`).
- `eth1`: red WAN del lab (`91.168.50.10`).

## 5. Diferencias respecto a un entorno real

### 5.1 Limitaciones del entorno virtualizado

Aunque el laboratorio reproduce fielmente una arquitectura de red corporativa, existen **diferencias inevitables** al ejecutarse íntegramente sobre VirtualBox en un único anfitrión:

- **Segmentación simulada:** Las zonas de red (WAN, DMZ, VLAN10, VLAN20) se implementan mediante redes internas de VirtualBox (`intnet`), no con switches físicos gestionables ni etiquetado VLAN 802.1Q. Cada segmento es una red aislada en software, no una VLAN real con trunking.
- **Hipervisor como punto único de fallo:** Si el anfitrión se detiene o falla, todas las máquinas virtuales y sus servicios dejan de funcionar simultáneamente. En producción, la redundancia de hardware y la alta disponibilidad son imprescindibles.
- **Aislamiento no físico:** Un atacante con acceso al hipervisor podría potencialmente saltarse las reglas de firewall o capturar tráfico entre las MV, algo que en un entorno real requeriría comprometer varios dispositivos físicos independientes.
- **Rendimiento de red irreal:** La latencia entre segmentos es mínima (microsegundos) y el ancho de banda no está limitado. En una red real habría enlaces con capacidades y latencias variables, así como posibles congestiones.
- **Escritorio virtual de Kali por conveniencia:** El acceso gráfico a `external-kali` mediante noVNC es un añadido para facilitar el manejo del laboratorio. En un entorno real, una máquina atacante externa no contaría con este servicio expuesto.

### 5.2 Aspectos que funcionarían diferente en producción

Varios elementos del laboratorio están simplificados o adaptados. En una implantación real se aplicarían estas diferencias:

- **WAN real:** La red WAN simulada (91.168.50.0/24) representa una conexión a **Internet con IP pública**. En producción, el firewall tendría una o varias direcciones IP públicas asignadas por el proveedor de acceso, y estaría expuesto a tráfico real y continuo desde el exterior o conectado a uno o varios routers.
- **VPNs con autenticación multifactor:** WireGuard se configura aquí con pares de claves estáticas. En un despliegue real se añadiría autenticación multifactor (TOTP, certificados de cliente) y un sistema de gestión de claves más robusto, posiblemente integrado con un directorio corporativo.
- **DNS y filtrado de contenido:** La redirección forzada de DNS a Unbound es una medida efectiva pero básica. Un entorno corporativo real añadiría un proxy HTTP/HTTPS con inspección de contenido, categorización de URLs y posiblemente un agente de seguridad endpoint para el filtrado de dominios, pero en este entorno esto requiriría muchos recursos de RAM y almacenamiento.
- **Gestión de reglas de firewall:** Aquí las reglas se administran directamente en la WebUI de OPNsense. En una organización con varios firewalls se usaría gestión centralizada, control de cambios, revisión por pares y posiblemente infraestructura como código (Ansible, Terraform) para mantener la consistencia.
- **Acceso a la gestión del firewall:** La administración de OPNsense se realiza exclusivamente a través de la VPN de administradores (`wg-admins`), no mediante una interfaz de gestión expuesta al anfitrión. Esto sigue la buena práctica de no exponer paneles de administración a redes no controladas, pero en producción se añadiría una red de gestión física segregada y un bastión de acceso. Es importante mencionar que en este laboratorio las claves privadas están hardcodeadas en el script de provisioning por reproducibilidad, algo que **nunca** se haría en producción donde las claves se generarían en el dispositivo del usuario y nunca saldrían de él.

### 5.3 Consideraciones de recursos (RAM, almacenamiento)

Los recursos asignados a cada máquina virtual son ajustados para funcionar en un entorno de desarrollo o en un portátil. No representan el dimensionamiento necesario en producción:

- **OPNsense (1.5 GB RAM, 1 vCPU):** Suficiente para aplicar reglas, gestionar VPNs y ejecutar Suricata con conjuntos de reglas limitados. En producción, un firewall con inspección profunda de paquetes, múltiples túneles VPN y decenas de miles de conexiones simultáneas necesitaría al menos 4-8 GB de RAM y varias CPU.
- **external-kali (2.5 GB RAM, 2 vCPUs):** Dimensionada para ejecutar herramientas de ataque con escritorio gráfico XFCE. En un entorno real de pruebas de penetración, la máquina del analista no estaría limitada artificialmente.
- **dmz-server y vlan20-server (612 MB RAM, 1 vCPU cada uno):** Recursos mínimos para ejecutar Nginx + Flask y MariaDB respectivamente. MariaDB en particular está configurado con un `innodb_buffer_pool_size` de solo 64 MB para reducir el consumo de memoria, lo que sería insuficiente para bases de datos de tamaño real.
- **Almacenamiento:** Los discos virtuales son dinámicos y de tamaño reducido. No se ha implementado redundancia, copias de seguridad ni políticas de retención, aspectos todos ellos obligatorios en un sistema en producción según el ENS.

Estas limitaciones no afectan a los objetivos didácticos del laboratorio, pero deben tenerse en cuenta antes de extrapolar directamente cualquier métrica de rendimiento o seguridad a un entorno corporativo real.

## 6. Acceso a las máquinas y servicios

### 6.1 Acceso a la WebUI de OPNsense

La interfaz de administración del firewall OPNsense está disponible exclusivamente a través de su IP en la red de gestión (`192.168.10.1`). El acceso está restringido solo con acceso a través de la VPN de administradores (`wg-admins`) como medida de seguridad fundamental, evitando exponer la consola de gestión a la WAN o a otras zonas de la red.

**Procedimiento de acceso:**

1. Desde `external-kali`, activar la VPN de administradores:

```bash
sudo wg-quick up wg-admins
```

2. Verificar que el túnel se ha establecido correctamente:

```bash
sudo wg show
```

Debe aparecer `latest handshake` reciente y bytes transferidos mayores que 0.

3. Abrir el navegador dentro de `external-kali` y acceder a:
[https://192.168.10.1](https://192.168.10.1)

4. Aceptar la advertencia de *su conexión no es privada*.

5. Introducir las credenciales de administrador configuradas durante el provisionamiento de OPNsense.
**Usuario**: root
**Contraseña**: Contraseniarobustademinimo16caracteres!.

**Nota:** no existe acceso directo desde el anfitrión a esta WebUI. Todo el tráfico de administración se canaliza obligatoriamente a través del túnel WireGuard, garantizando cifrado y autenticación.

### 6.2 Acceso SSH a `dmz-server` y `vlan20-server`

Se puede acceder directamente desde el anfitrión utilizando el comando `vagrant ssh`. Este método no depende de la VPN:

```bash
vagrant ssh dmz-server
vagrant ssh vlan20-server
```

Sin embargo, para las pruebas de seguridad y verificación de políticas de acceso, se debe utilizar siempre el acceso a través de la red del laboratorio y las VPNs.

### 6.3 Configuración de los túneles VPN WireGuard

Las configuraciones de WireGuard en `external-kali` se generan automáticamente durante el provisionamiento y se almacenan en:

- `/etc/wireguard/wg-admins.conf` — perfil de administrador.
- `/etc/wireguard/wg-users.conf` — perfil de usuario.

**Activar un túnel:**

```bash
# Activar VPN de administradores
sudo wg-quick up wg-admins

# Activar VPN de usuarios
sudo wg-quick up wg-users
```

**Desactivar un túnel:**

```bash
sudo wg-quick down wg-admins
sudo wg-quick down wg-users
```

**Verificar el estado de un túnel activo:**

```bash
sudo wg show wg-admins
sudo wg show wg-users
```

Los campos importantes a vigilar son `latest handshake`, que debe ser un valor reciente, y `transfer`, que debe mostrar bytes recibidos y enviados. Los campos `interface` y `peer` confirman que la clave pública del servidor OPNsense coincide con la configurada.

**Nota importante:** ambos perfiles utilizan `AllowedIPs = 0.0.0.0/0`, lo que significa que todo el tráfico de `external-kali` se enruta a través del túnel cuando está activo. Esto incluye la navegación web, las consultas DNS y cualquier conexión a redes internas. Para volver al acceso directo a internet a través de la NAT propia de `external-kali`, hay que desactivar la VPN con `sudo wg-quick down`.

### 6.4 Acceso al portal web corporativo (DMZ)

El portal web corporativo se encuentra en `dmz-server`, puerto 80. Está accesible únicamente desde las VPNs, tanto `wg-admins` como `wg-users`. Sin una VPN activa, el firewall bloquea todo el tráfico hacia la DMZ.

**Acceso con VPN activa (cualquiera de las dos):**

```bash
# Desde external-kali con wg-users o wg-admins activo
curl http://172.16.0.10
```

Devuelve el HTML del portal corporativo.

```bash
curl http://172.16.0.10/empleados
```

Devuelve el JSON con datos de empleados.

**Verificación del bloqueo sin VPN:**

```bash
# Asegurarse de que ninguna VPN está activa
sudo wg-quick down wg-admins 2>/dev/null
sudo wg-quick down wg-users 2>/dev/null

# Intentar acceder (debe fallar)
curl --connect-timeout 5 http://172.16.0.10
```

Resultado: sin respuesta o timeout.

El portal muestra una página principal con información corporativa simulada y un enlace al listado de empleados. La aplicación Flask que genera el contenido se ejecuta en localhost (`127.0.0.1:5000`) y Nginx actúa como proxy inverso hacia ella. Este diseño evita exponer directamente el servicio de la aplicación al resto de la red.
Todas estas pruebas se pueden realizar desde el escritorio virtual a través de noVNC también para que sea más intuitivo y visual (usando el navegador por ejemplo).

