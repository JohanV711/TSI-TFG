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