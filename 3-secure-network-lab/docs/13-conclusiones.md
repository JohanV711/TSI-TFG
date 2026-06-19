## 13. Conclusiones

### 13.1 Controles de seguridad demostrados

Este laboratorio ha implementado y verificado una arquitectura de red corporativa segmentada que demuestra, de forma práctica y reproducible, los principios fundamentales de la seguridad en redes: defensa en profundidad, mínimo privilegio, segmentación de zonas y trazabilidad de eventos.

A lo largo de las secciones anteriores se ha evidenciado el correcto funcionamiento de los siguientes controles:

**Segmentación y control de acceso:**

- Cuatro zonas de red diferenciadas (WAN, DMZ, VLAN10 gestión, VLAN20 servidores) con políticas de firewall independientes y principio de denegación por defecto en todas ellas.
- Dos perfiles VPN con permisos asimétricos: `wg-admins` con acceso completo a la infraestructura y `wg-users` con acceso restringido exclusivamente al portal web corporativo.
- Imposibilidad demostrada de acceder a cualquier recurso interno sin VPN activa, incluyendo el portal web, la base de datos y la WebUI de gestión.
- Contención efectiva del servidor DMZ: aunque está expuesto a los clientes VPN, no puede iniciar conexiones hacia la red de gestión ni hacia recursos no autorizados de VLAN20.

**Defensa en profundidad:**

- El acceso a MariaDB está controlado en dos capas independientes: el firewall de OPNsense a nivel de red y los permisos de usuario de MariaDB a nivel de aplicación. Un compromiso de las credenciales VPN no otorga acceso directo a los datos.
- El servidor web actúa como intermediario controlado: los usuarios VPN acceden al portal, pero nunca contactan directamente con la base de datos.
- Las reglas de bloqueo explícitas (no solo el default deny) registran los intentos de acceso no autorizado, proporcionando trazabilidad adicional.

**Control del tráfico DNS:**

- Redirección forzada de todas las consultas DNS mediante Port Forward, impidiendo que cualquier cliente eluda el resolver interno independientemente de su configuración.
- Filtrado de dominios mediante Unbound Host Overrides, verificado como efectivo incluso cuando el cliente intenta usar DNS externo.
- Cifrado de las consultas DNS salientes de OPNsense mediante DNS over TLS hacia Cloudflare y Quad9, protegiendo la privacidad de los dominios consultados.

**Encaminamiento controlado:**

- Todo el tráfico de `dmz-server` y `vlan20-server` pasa obligatoriamente por OPNsense gracias a la configuración de netplan que establece el gateway por defecto en la IP de OPNsense para cada interfaz, eliminando la ruta directa por la NAT de Vagrant.
- El full-tunnel WireGuard (`AllowedIPs = 0.0.0.0/0`) garantiza que incluso el tráfico de Internet de los clientes VPN pasa por OPNsense y queda sujeto a sus políticas.

**Detección de intrusiones:**

- Suricata operativo en WAN y DMZ con rulesets relevantes para el escenario, capaz de detectar escaneos de puertos, intentos de SQLi, floods DoS y tráfico de reconocimiento desde `external-kali`.
- Correlación demostrada entre los logs del firewall y las alertas de Suricata para el mismo flujo de tráfico.

**Trazabilidad ENS:**

- Logging activo en todas las reglas de bloqueo y en las de paso críticas, con registros que incluyen IP origen, destino, protocolo, timestamp y descripción de la regla aplicada.
- Mapeo completo de cada control implementado con los artículos correspondientes del ENS (RD 311/2022), justificando las decisiones de diseño desde el punto de vista normativo.

---

### 13.2 Posibles mejoras y extensiones del laboratorio

El laboratorio en su estado actual cubre los controles esenciales de una arquitectura corporativa segura. Las siguientes mejoras representan el camino natural hacia una implantación de mayor madurez, ordenadas de menor a mayor complejidad de implementación.

---

**Zenarmor (anteriormente Sensei) — inspección de capa 7**

Zenarmor es el módulo de inspección profunda de paquetes de OPNsense, disponible como plugin. A diferencia de Suricata, que trabaja con firmas, Zenarmor identifica aplicaciones por su comportamiento de red independientemente del puerto o el cifrado, permitiendo políticas basadas en aplicación en lugar de en puerto.

En el contexto de este laboratorio aportaría:

- Identificación y bloqueo de aplicaciones específicas (Netflix, Telegram, Teams) sin depender de listas de dominios que se desactualizan rápidamente.
- Visibilidad de qué aplicaciones consumen ancho de banda, con estadísticas por usuario VPN.
- Filtrado de categorías de contenido web (redes sociales, apuestas, adultos) sin necesidad de mantener listas manuales como los Host Overrides de Unbound.
- Informes de actividad de red por usuario, útiles para auditorías de cumplimiento ENS.

> **Requisito:** Zenarmor requiere al menos 2 GB de RAM adicionales para funcionar con fluidez. En el laboratorio actual, con OPNsense limitado a 1.5 GB, no sería viable sin aumentar los recursos del Vagrantfile. En producción, con hardware dedicado, es una de las mejoras más impactantes disponibles en OPNsense.

---

**Alta disponibilidad y routing redundante con CARP**

La arquitectura actual tiene un único punto de fallo crítico: si OPNsense deja de funcionar, toda la conectividad de la organización se interrumpe. OPNsense soporta alta disponibilidad mediante el protocolo CARP (Common Address Redundancy Protocol), que permite desplegar dos instancias en modo activo-pasivo con failover automático.

**Implementación propuesta:**

```text
Internet
│
├── OPNsense-MASTER (activo) ──┐
│ ├── IP virtual compartida (VIP)
└── OPNsense-BACKUP (pasivo) ──┘
│
Red interna
```

En el laboratorio se implementaría añadiendo una segunda VM `opensense-backup` al Vagrantfile con la misma configuración de interfaces y sincronización de estado mediante `pfsync`. El failover se demostraría apagando `opensense-master` y verificando que la conectividad se mantiene en menos de 2 segundos.

---

**Autenticación multifactor para VPN (WireGuard + TOTP)**

Las claves WireGuard actuales son estáticas y están almacenadas en archivos de configuración. Si el dispositivo del administrador es comprometido, el atacante obtiene acceso total a la infraestructura. La mejora natural es añadir un segundo factor de autenticación.

OPNsense soporta autenticación multifactor mediante:

- **FreeRADIUS + Google Authenticator:** el cliente VPN debe presentar además de la clave WireGuard un TOTP válido generado por una app autenticadora.
- **Certificados de cliente:** en lugar de claves simétricas, usar PKI con certificados firmados por una CA interna, permitiendo revocar accesos sin regenerar todas las claves.
- **Integración con LDAP/Active Directory:** centralizar la gestión de usuarios y credenciales VPN en un directorio corporativo existente.

---

**Segmento de gestión físicamente segregado (OOB Management)**

En el laboratorio, la gestión de OPNsense se realiza a través de la VPN de administradores, lo que significa que el canal de gestión y el canal de datos comparten la misma infraestructura. En producción se implementaría una red de gestión fuera de banda (Out-of-Band):

```text
Internet ──── OPNsense ──── Red corporativa
│
└── Red OOB (gestión) ──── Switch de gestión ──── Consola serie
```

En el laboratorio se podría simular añadiendo una interfaz `net-oob` dedicada exclusivamente al acceso de administración, sin NAT ni acceso a Internet, accesible solo desde el host anfitrión mediante una red host-only de VirtualBox.

---

**SIEM para correlación y retención de logs**

Los logs de OPNsense se almacenan localmente con retención de 7 días. Para cumplimiento ENS en categoría ALTA se requiere retención mínima de 6 meses y capacidad de correlación de eventos entre sistemas. La mejora propuesta es integrar un SIEM externo:

- **Elasticsearch + Kibana (ELK Stack):** OPNsense puede enviar logs en formato EVE JSON directamente a Logstash. Los dashboards de Kibana permiten visualizar el tráfico, las alertas de Suricata y los eventos de autenticación en tiempo real.
- **Graylog:** alternativa más ligera a ELK, con soporte nativo para syslog. Permite crear alertas automáticas cuando se detectan patrones anómalos (múltiples intentos fallidos de VPN, escaneos repetidos desde la misma IP, etc.).

En el laboratorio se añadiría una quinta VM `siem-server` con Graylog o ELK, configurando OPNsense para enviar todos los logs por syslog UDP/514 o TCP/5044.

---

**Inspección SSL/TLS (HTTPS Inspection)**

Actualmente Suricata no puede inspeccionar el contenido de las conexiones HTTPS porque van cifradas. En producción, una organización puede implementar inspección TLS mediante un proxy intermedio que descifra, inspecciona y vuelve a cifrar el tráfico usando un certificado raíz instalado en los dispositivos cliente.

OPNsense soporta esto mediante el plugin **Squid** con interceptación SSL, o mediante la integración con **Zenarmor** que puede inspeccionar tráfico cifrado con soporte de SNI. Esto permitiría detectar malware que usa HTTPS para comunicarse con servidores C2, o exfiltración de datos cifrada.

> **Consideración ética y legal:** La inspección TLS en una organización requiere que los empleados sean informados explícitamente, ya que implica la interceptación de comunicaciones potencialmente privadas. En España, esta práctica está regulada y debe estar documentada en la política de uso aceptable de la organización.

---

**Nuevos servicios en la infraestructura**

El laboratorio es extensible con nuevas VMs que amplíen el escenario de seguridad:

| Servicio | VM propuesta | Valor para el TFG |
|---|---|---|
| Servidor de correo (Postfix) | `mail-server` en DMZ | Demostrar filtrado de spam y DKIM/SPF |
| Servidor de archivos (Samba/NFS) | `files-server` en VLAN20 | Control de acceso a recursos compartidos |
| PKI interna (Step-CA) | `ca-server` en VLAN10 | Emisión de certificados para HTTPS interno y VPN |
| Honeypot (Cowrie) | `honeypot` en DMZ | Detección temprana de atacantes que entran en DMZ |
| Proxy inverso con WAF (ModSecurity) | Añadir a `dmz-server` | Protección de capa 7 para el portal web |
| Servidor de salto (Bastion host) | `bastion` en VLAN10 | Canal de acceso SSH controlado a servidores internos |

---

**Automatización del despliegue con Ansible**

La configuración actual de OPNsense se realiza manualmente a través de la WebUI. Para hacer el laboratorio completamente reproducible y alineado con las prácticas de infraestructura como código (IaC), se podría automatizar mediante:

- **Ansible + colección de OPNsense:** permite definir reglas de firewall, aliases, configuración VPN y NAT en archivos YAML versionados en el repositorio.
- **Exportación del XML de OPNsense:** OPNsense almacena toda su configuración en un único archivo XML (`/conf/config.xml`) que puede incluirse en el repositorio y restaurarse automáticamente durante el `vagrant up`.

Esta mejora convertiría el laboratorio en un entorno completamente desatendido, donde un único `vagrant up` levantaría toda la infraestructura con la configuración de seguridad aplicada desde el primer momento, sin intervención manual en la WebUI.

---

> El conjunto de mejoras descritas representa una hoja de ruta hacia una implantación de nivel empresarial. Cada una de ellas añade una capa adicional de seguridad, visibilidad o resiliencia, y puede implementarse de forma incremental sobre la base de este laboratorio sin necesidad de rediseñar la arquitectura existente.

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="12-logs-trazabilidad-ens.md">← Anterior</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <a href="../README.md">Volver al índice</a>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <span style="color: #999;">Fin de la documentación</span>
    </td>
  </tr>
</table>