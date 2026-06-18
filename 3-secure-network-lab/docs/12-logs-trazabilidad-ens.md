## 12. Logs y trazabilidad ENS

La trazabilidad es uno de los pilares del Esquema Nacional de Seguridad. El control `op.mon.1` exige que los sistemas registren los eventos de seguridad relevantes de forma que sea posible reconstruir lo ocurrido ante un incidente. En este laboratorio, OPNsense centraliza los logs de firewall, VPN, DNS e IDS, proporcionando una visión completa de todo el tráfico que atraviesa la infraestructura.

---

### 12.1 Dónde ver los logs en OPNsense

OPNsense organiza los logs en varias ubicaciones según el subsistema que los genera. La tabla siguiente resume los puntos de acceso principales:

| Subsistema | Ruta en la WebUI | Descripción |
|------------|-----------------|-------------|
| Firewall (tiempo real) | Firewall → Log Files → Live View | Tráfico permitido y bloqueado en tiempo real con filtros |
| Firewall (histórico) | Firewall → Log Files → Plain | Entradas de log en texto plano, exportables |
| Suricata IDS | Services → Intrusion Detection → Alerts | Alertas generadas por firmas de Suricata |
| WireGuard VPN | VPN → WireGuard → Status | Estado de túneles, handshakes y transferencia |
| Unbound DNS | Services → Unbound DNS → Log File | Consultas DNS resueltas y bloqueadas |
| Sistema general | System → Log Files → General | Eventos del sistema operativo y demonios |
| Autenticación | System → Log Files → Auth | Intentos de acceso a la WebUI de OPNsense |

**Live View del firewall:**

El Live View (`Firewall → Log Files → Live View`) es la herramienta principal para observar el comportamiento del firewall en tiempo real. Permite filtrar por interfaz, IP origen, IP destino, protocolo o descripción de regla, y muestra la acción aplicada (`pass`/`block`) junto con la regla que la causó. Su uso se detalla en la sección 8.1.

**Activación de logging en las reglas:**

Para que una regla aparezca en los logs, debe tener el icono de log activado (columna con el símbolo `i` en la tabla de reglas). En este laboratorio todas las reglas de bloqueo y las reglas de paso más relevantes tienen logging habilitado para garantizar la trazabilidad de accesos legítimos e intentos no autorizados.

---

### 12.2 Ejemplos de entradas de log por escenario

Las siguientes entradas son representativas de los eventos que genera cada escenario del laboratorio. Se pueden reproducir ejecutando las pruebas de la sección 7 con el Live View abierto.

---

**Escenario A — Acceso sin VPN bloqueado (WAN)**

Acción en `external-kali`: `curl --connect-timeout 3 http://172.16.0.10` sin VPN activa.

```text
Timestamp: 2026-06-11T10:15:32
Interface: WAN → [in]
Action: BLOCK
Source: 91.168.50.10:54231
Destination: 172.16.0.10:80
Protocol: TCP
Rule: Default deny / state violation rule
```

**Interpretación:** El paquete llega a la interfaz WAN pero no existe ninguna regla que permita tráfico desde la WAN hacia la DMZ en el puerto 80. La política por defecto de OPNsense en WAN es denegar todo lo no explícitamente permitido.

---

**Escenario B — Establecimiento de túnel WireGuard (WAN)**

Acción en `external-kali`: `sudo wg-quick up wg-admins`.

```text
Timestamp: 2026-06-11T10:16:01
Interface: WAN → [in]
Action: PASS
Source: 91.168.50.10:47110
Destination: 91.168.50.1:51820
Protocol: UDP
Rule: WAN-IN: Permitir tráfico UDP entrante al puerto 51820 (WireGuard VPN)
```

**Interpretación:** El paquete UDP de negociación WireGuard es aceptado porque existe una regla explícita en WAN que permite UDP al puerto 51820. Esta es la única entrada permitida desde la WAN; cualquier otro tráfico es bloqueado.

---

**Escenario C — Acceso al portal web con `wg-users` (DMZ)**

Acción en `external-kali`: `curl http://172.16.0.10` con `wg-users` activo.

```text
Timestamp: 2026-06-11T10:17:45
Interface: wgusers → [in]
Action: PASS
Source: 10.10.2.51:52341
Destination: 172.16.0.10:80
Protocol: TCP
Rule: VPN-USERS: Acceso a DMZ desde usuarios VPN autenticados
```

**Interpretación:** El tráfico entra por la interfaz `wgusers` y es permitido por la regla que autoriza a `VPN_USERS` hacia `RED_DMZ`. La IP origen es `10.10.2.51`, la dirección del cliente dentro del túnel VPN.

---

**Escenario D — Intento de acceso a VLAN20 bloqueado (`wg-users`)**

Acción en `external-kali`: `nc -zv 192.168.20.10 3306` con `wg-users` activo.

```text
Timestamp: 2026-06-11T10:18:12
Interface: wgusers → [in]
Action: BLOCK
Source: 10.10.2.51:43201
Destination: 192.168.20.10:3306
Protocol: TCP
Rule: VPN-USERS: BLOQUEAR acceso directo a VLAN20 servidores
```

**Interpretación:** Un usuario VPN estándar intenta acceder directamente a la base de datos. La regla de bloqueo explícita en `wgusers` actúa antes de que el paquete llegue a VLAN20. El acceso queda registrado con la IP del cliente VPN, proporcionando trazabilidad del intento.

---

**Escenario E — Acceso completo con `wg-admins` (VLAN20)**

Acción en `external-kali`: `nc -zv 192.168.20.10 3306` con `wg-admins` activo.

```text
Timestamp: 2026-06-11T10:19:03
Interface: wgadmins → [in]
Action: PASS
Source: 10.10.1.51:38921
Destination: 192.168.20.10:3306
Protocol: TCP
Rule: VPN-ADMINS: Acceso completo a VLAN20 servidores desde administradores VPN
```

**Interpretación:** El mismo intento de conexión al puerto 3306, pero desde el perfil de administrador, es permitido. El firewall distingue entre perfiles VPN gracias a los aliases `VPN_ADMINS` y `VPN_USERS`, que contienen las subredes `10.10.1.0/24` y `10.10.2.0/24` respectivamente.

---

**Escenario F — Intento de DMZ hacia red de gestión (bloqueado)**

Acción desde `dmz-server`: `curl --connect-timeout 3 https://192.168.10.1`.

```text
Timestamp: 2026-06-11T10:20:17
Interface: DMZ → [in]
Action: BLOCK
Source: 172.16.0.10:51234
Destination: 192.168.10.1:443
Protocol: TCP
Rule: DMZ-BLOCK: Bloquear tráfico desde DMZ hacia red de gestión
```

**Interpretación:** El servidor web de la DMZ intenta acceder a la WebUI de OPNsense. Este bloqueo es crítico para la contención: si un atacante comprometiera el servidor web, no podría pivotar hacia la consola de administración del firewall. El log registra la IP del servidor DMZ, permitiendo detectar este comportamiento anómalo.

---

**Escenario G — Redirección DNS interceptada (Port Forward)**

Acción en `external-kali`: `nslookup instagram.com 8.8.8.8` con VPN activa.

```text
Timestamp: 2026-06-11T10:21:05
Interface: wgadmins → [in]
Action: PASS (NAT redirect)
Source: 10.10.1.51:53421
Destination: 8.8.8.8:53 → redirigido a 10.10.1.1:53
Protocol: UDP
Rule: DNS-INTERCEPT: Forzar DNS de admins VPN por Unbound OPNsense
```

**Interpretación:** La consulta DNS dirigida a `8.8.8.8` es interceptada por la regla de Port Forward. OPNsense reescribe el destino a `10.10.1.1:53` (Unbound) antes de procesarla. El cliente recibe la respuesta como si viniera de `8.8.8.8`, sin poder detectar la redirección. Unbound aplica los Host Overrides y bloquea `instagram.com` devolviendo `0.0.0.0`.

---

**Escenario H — Alerta Suricata por escaneo nmap**

Acción en `external-kali`: `sudo nmap -sS -T4 91.168.50.1` sin VPN.

```text
Timestamp: 2026-06-11T10:22:33
Interface: WAN
Action: ALERT (IDS)
Source: 91.168.50.10:variable
Destination: 91.168.50.1:variable
Protocol: TCP
Suricata SID: 2000346
Alert: ET SCAN NMAP -sS window 1024
Category: attempted-recon
Severity: major
```

**Interpretación:** Suricata identifica el patrón de paquetes SYN con ventana TCP 1024 característico de nmap en modo `-sS`. La alerta aparece en `Services → Intrusion Detection → Alerts`. En modo IDS no se interrumpe el escaneo, pero el evento queda registrado con la IP del atacante, el tipo de ataque y la severidad.

![Ejemplos de logs en el Live View de OPNsense](images/image10.png)

*Figura 11: Live View de OPNsense mostrando varias de las entradas de log descritas en los escenarios A-H. Se observan tanto tráfico bloqueado (`BLOCK`) como permitido (`PASS`) y redirecciones DNS.*

---

### 12.3 Relación de cada regla con controles ENS

El Esquema Nacional de Seguridad define controles de seguridad agrupados en categorías. La siguiente tabla mapea cada regla del firewall con el control ENS que implementa o refuerza, justificando las decisiones de diseño desde el punto de vista normativo.

| Regla | Control ENS | Categoría | Justificación |
|-------|-------------|-----------|---------------|
| WAN: permitir UDP 51820/51821 (WireGuard) | `mp.com.2` | Protección de comunicaciones | El acceso remoto se realiza exclusivamente mediante canal cifrado. No existe acceso directo a recursos internos sin VPN. |
| WAN: bloquear MySQL desde exterior | `op.acc.4` | Control de acceso | La base de datos nunca es accesible desde redes no confiables, reduciendo la superficie de ataque. |
| `wgadmins`: acceso a WebUI solo VPN admins | `op.acc.5` | Privilegio mínimo | La consola de administración del firewall solo es accesible para el perfil de administrador autenticado mediante VPN. |
| `wgusers`: bloquear VLAN10 y VLAN20 | `mp.ac.4` | Separación de funciones | Los usuarios estándar no tienen acceso a infraestructura de gestión ni a datos sensibles. |
| DMZ: bloquear tráfico hacia RED_GESTION | `op.acc.6` | Contención de compromiso | Si el servidor web es comprometido, el atacante no puede pivotar hacia la red de gestión del firewall. |
| DMZ: MySQL solo desde `172.16.0.10` | `op.acc.4` | Mínimo privilegio | Solo el servidor web autorizado puede consultar la base de datos. Ningún otro origen puede iniciar conexiones MySQL. |
| VLAN20: bloqueo por defecto | `mp.ac.4` | Protección de activos críticos | La VLAN de servidores tiene una política de denegación por defecto. Solo se permite tráfico explícitamente autorizado. |
| Port Forward DNS (redirección forzada) | `op.acc.5` | Control de navegación | Ningún cliente puede eludir el resolver interno, garantizando que las políticas de filtrado DNS se aplican universalmente. |
| Unbound Host Overrides (bloqueo dominios) | `op.ext.9` | Protección frente a código dañino | El filtrado DNS bloquea dominios de redes sociales y puede extenderse a dominios de malware y C2. |
| DNS over TLS (Cloudflare/Quad9) | `mp.com.2` | Confidencialidad de comunicaciones | Las consultas DNS salientes van cifradas, impidiendo que el ISP o intermediarios observen los dominios consultados. |
| Suricata en WAN y DMZ | `op.mon.1` | Detección de intrusiones | El tráfico entrante y el dirigido al servidor web se analiza en busca de patrones de ataque conocidos. |
| Logging en todas las reglas de bloqueo | `op.mon.1` | Trazabilidad | Todos los intentos de acceso no autorizado quedan registrados con IP origen, destino, protocolo y timestamp. |
| NAT Outbound por WANparainternetreal | `op.acc.4` | Control de salida | Todo el tráfico de las VMs internas hacia Internet pasa por OPNsense, que aplica NAT y puede aplicar filtrado de salida. |
| `wgadmins`/`wgusers`: DNS forzado a Unbound | `op.acc.5` | Control de resolución | Los clientes VPN no pueden usar resolvers externos, garantizando que el filtrado de dominios se aplica también en tránsito. |

**Niveles de cumplimiento ENS referenciados:**

- `mp.com.2` — Protección de la confidencialidad: cifrado de comunicaciones en tránsito.
- `op.acc.4` — Control de acceso basado en necesidad de conocer.
- `op.acc.5` — Privilegio mínimo: cada perfil accede solo a lo estrictamente necesario.
- `op.acc.6` — Mecanismos de control de acceso en profundidad.
- `mp.ac.4` — Separación de funciones y responsabilidades.
- `op.ext.9` — Protección frente a código dañino y contenido malicioso.
- `op.mon.1` — Detección de intrusiones y monitorización continua.

> **Nota sobre la categoría ENS del sistema:** Este laboratorio simula una infraestructura de categoría **MEDIA** según el ENS, al gestionar datos de empleados y servicios corporativos. Los controles implementados cubren los requisitos mínimos de esa categoría. Una categoría **ALTA** requeriría controles adicionales como autenticación multifactor, auditorías periódicas, continuidad de negocio y cifrado de datos en reposo.

![Tabla de reglas con logging habilitado](images/image11.png)

*Figura 12: Listado de reglas de una interfaz en OPNsense. Se observa el icono de logging activado en las reglas de bloqueo, garantizando que todos los intentos no autorizados queden registrados.*

<br>
<div style="display: flex; justify-content: space-between; align-items: center; width: 100%;">
  <span><a href="11-suricata-deteccion.md">← Anterior</a></span>
  <span><a href="../README.md">Volver al índice</a></span>
  <span><a href="13-conclusiones.md">Siguiente →</a></span>
</div>