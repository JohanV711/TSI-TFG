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

---

[📑 Volver al índice general](../README.md)  |  [Siguiente →](02-topologia-red.md)