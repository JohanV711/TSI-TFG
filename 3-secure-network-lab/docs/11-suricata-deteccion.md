## 11. Detección de intrusiones con Suricata

Suricata es el motor de detección y prevención de intrusiones (IDS/IPS) integrado en OPNsense. En este laboratorio actúa como **sensor de red pasivo** sobre las interfaces WAN y DMZ, analizando el tráfico en busca de patrones maliciosos conocidos y generando alertas que quedan registradas en el panel de OPNsense.

Su presencia en la arquitectura cumple directamente con el control ENS `op.mon.1` (detección de intrusiones) y complementa las reglas de firewall añadiendo visibilidad sobre el contenido del tráfico, no solo sobre sus cabeceras.

---

### 11.1 Configuración aplicada y rulesets activos

La configuración se ha optimizado para funcionar dentro de las limitaciones de recursos del entorno virtualizado, priorizando la cobertura de los vectores de ataque más relevantes para el laboratorio sobre la exhaustividad.

**Parámetros generales (Services → Intrusion Detection → Administration):**

| Parámetro | Valor | Justificación |
|-----------|-------|---------------|
| Modo | IDS (detección) | Evita falsos positivos que corten tráfico legítimo |
| IPS mode | Deshabilitado | Se habilitaría tras validación en producción |
| Promiscuous mode | Deshabilitado | Suficiente para el tráfico que pasa por OPNsense |
| Interfaces monitorizadas | WAN, DMZ | WAN cubre ataques externos; DMZ cubre el servidor web |
| Pattern matcher | Aho-Corasick | Equilibrio entre rendimiento y detección |
| Detect profile | Low | Reduce consumo de RAM en entorno virtualizado |
| Home networks | `192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12` | Redes internas del laboratorio |
| Syslog alerts | Habilitado | Integración con el sistema de logs de OPNsense |
| EVE syslog output | Habilitado | Formato JSON estructurado para análisis |
| Rotate log | Diario | Retención de 7 días |

> **Nota sobre el modo IPS:** En producción se habilitaría IPS mode en la interfaz WAN una vez validado que los rulesets no generan falsos positivos. En este laboratorio se mantiene en IDS para no interrumpir el tráfico durante las pruebas.

**Rulesets activos:**

Se han seleccionado los conjuntos de reglas más relevantes para el escenario del laboratorio, descartando los que consumen más memoria sin aportar cobertura útil en este contexto:

| Ruleset | Descripción | Relevancia en el lab |
|---------|-------------|----------------------|
| `emerging-scan.rules` | Detecta escaneos de puertos y reconocimiento | Ataques desde `external-kali` con nmap |
| `emerging-web_server.rules` | Ataques a servidores web (SQLi, XSS, path traversal) | Protección del portal en DMZ |
| `emerging-sql.rules` | Intentos de inyección SQL | Ataques al backend Flask/MariaDB |
| `emerging-attack_response.rules` | Detecta respuestas que indican exploit exitoso | Detección post-compromiso |
| `emerging-dos.rules` | Floods y ataques de denegación de servicio | Simulación con `hping3` desde Kali |
| `botcc.rules` | Tráfico hacia servidores C2 conocidos | Control de tráfico saliente malicioso |
| `abuse.ch.feodotracker.rules` | IPs de botnets activas | Complementa botcc con feeds actualizados |

**Reglas de usuario definidas (User Defined Rules):**

Además de los rulesets estándar, se han añadido dos alertas personalizadas para monitorizar tráfico específico del laboratorio:

- Alerta sobre cualquier tráfico hacia el servidor de base de datos.
- Destino: `192.168.20.10` — Acción: `alert`.
- Descripción: `LAB-IDS: Detectar tráfico hacia MySQL (192.168.20.10) desde orígenes no autorizados`.

- Alerta sobre tráfico hacia el servidor web de la DMZ.
- Destino: `172.16.0.10` — Acción: `alert`.
- Descripción: `LAB-IDS: Monitorizar tráfico hacia el servidor web DMZ (172.16.0.10)`.

**Policy configurada:**

- **Priority:** 1 (máxima prioridad).
- **Rulesets asociados:** los listados en la tabla anterior.
- **Signature severity:** major y critical únicamente, para reducir ruido y consumo de recursos.
- **Classtypes monitorizados:** `attempted-recon`, `attempted-admin`, `web-application-attack`, `trojan-activity`.

---

### 11.2 Simulación de escaneo desde `external-kali`

Las siguientes pruebas generan tráfico malicioso controlado desde `external-kali` para verificar que Suricata detecta y registra las amenazas. Todas se realizan con la VPN desactivada para simular un atacante externo real actuando desde la WAN.

**Preparación:**

```bash
# Asegurarse de que no hay VPN activa
sudo wg-quick down wg-admins 2>/dev/null || true
sudo wg-quick down wg-users 2>/dev/null || true
```

Abrir simultáneamente en OPNsense: `Services → Intrusion Detection → Alerts` y activar auto-refresh.

**Prueba 1: Escaneo de puertos con nmap (detección de reconocimiento)**

```bash
sudo nmap -sS -T4 91.168.50.1
```

**Resultado esperado en Suricata Alerts:**

```text
[**] [1:2010937:3] ET SCAN Suspicious inbound to mySQL port 3306 [**]
[**] [1:2002910:6] ET SCAN Potential SSH Scan [**]
[**] [1:2000346:6] ET SCAN NMAP -sS window 1024 [**]
```

**Explicación:** El ruleset `emerging-scan.rules` contiene firmas específicas para detectar los patrones de paquetes SYN que genera `nmap` en modo `-sS` (SYN scan). La firma identifica la ventana TCP característica de nmap y el ritmo de envío de paquetes.

**Prueba 2: Escaneo agresivo orientado a servicios web**

```bash
sudo nmap -sV -p 80,443,8080,8443 91.168.50.1
```

**Resultado esperado en Suricata Alerts:** alertas adicionales de `emerging-scan.rules` relacionadas con detección de versiones de servicios.

**Prueba 3: Simulación de flood DoS con hping3**

```bash
sudo hping3 -S --flood -V -p 80 91.168.50.1
```

⚠️ Ejecutar durante no más de 10 segundos. Detener con `Ctrl+C`.

**Resultado esperado en Suricata Alerts:**

```text
[**] ET DOS Possible TCP SYN Flood [**]
```

**Explicación:** El ruleset `emerging-dos.rules` detecta tasas anómalas de paquetes SYN hacia un mismo destino. En un entorno de producción con IPS activo, Suricata bloquearía automáticamente la IP origen.

**Prueba 4: Intento de inyección SQL contra el portal web**

Con `wg-users` activo, para poder alcanzar el portal:

```bash
sudo wg-quick up wg-users

# Intento de SQLi básico en la ruta de empleados
curl "http://172.16.0.10/empleados?id=1' OR '1'='1"

# Intento de path traversal
curl "http://172.16.0.10/../../../etc/passwd"
```

**Resultado esperado en Suricata Alerts:**

```text
[**] ET WEB_SERVER SQL Injection attempt [**]
[**] ET WEB_SERVER Possible SQL Injection attempt UNION [**]
[**] ET WEB_SERVER Attempt to access /etc/passwd [**]
```

**Explicación:** El ruleset `emerging-web_server.rules` contiene patrones para detectar los payloads más comunes de SQLi y path traversal en peticiones HTTP. Suricata inspecciona el contenido de la capa de aplicación, no solo las cabeceras.

**Prueba 5: Verificación de alertas en el Live View**

Mientras se ejecutan las pruebas anteriores, en `Firewall → Log Files → Live View` se pueden correlacionar los eventos del firewall con las alertas de Suricata, observando cómo el mismo flujo de tráfico genera tanto una entrada en los logs del firewall como una alerta IDS.

---

### 11.3 Lectura de alertas en el panel de OPNsense

Las alertas generadas por Suricata se consultan en `Services → Intrusion Detection → Alerts`.

**Campos principales de cada alerta:**

| Campo | Descripción |
|-------|-------------|
| Timestamp | Fecha y hora del evento |
| Interface | Interfaz donde se detectó (WAN, DMZ) |
| Source IP | IP origen del tráfico sospechoso |
| Destination IP | IP destino |
| Proto | Protocolo (TCP, UDP, ICMP) |
| Alert | Descripción de la firma que disparó la alerta |
| Category | Clasificación del ataque (`attempted-recon`, `web-application-attack`, etc.) |
| Severity | Nivel de severidad de la firma |

**Ejemplo de alerta típica tras el escaneo nmap:**

```text
Timestamp:      2026-06-11T12:34:56
Interface:      WAN
Source:         91.168.50.10:54321
Destination:    91.168.50.1:22
Proto:          TCP
Alert:          ET SCAN Potential SSH Scan
Category:       attempted-recon
Severity:       2 (major)
```

**Filtrado de alertas por escenario:**

Para localizar las alertas de un ataque específico, usar el campo de búsqueda por IP origen:

- Ataques desde WAN: filtrar por `91.168.50.10`.
- Tráfico sospechoso en DMZ: filtrar por `172.16.0.10` o `172.16.0.0/24`.

**Correlación con los logs del firewall:**

Las alertas de Suricata y los logs del firewall son complementarios:

- Los logs del firewall muestran si el tráfico fue permitido o bloqueado a nivel de regla.
- Las alertas de Suricata muestran si el contenido de ese tráfico contiene patrones maliciosos.

Un flujo puede ser permitido por el firewall y detectado por Suricata simultáneamente, lo que en modo IPS provocaría su bloqueo retroactivo. En modo IDS, configuración actual, solo genera la alerta sin interrumpir el tráfico.

![Listado de alertas generadas por Suricata en OPNsense](images/image9.png)

*Figura 10: Listado de alertas generadas por Suricata en OPNsense. Se muestran las detecciones correspondientes a los escaneos y ataques simulados desde external-kali.*

**Exportación de alertas para documentación:**

Las alertas se pueden exportar desde la interfaz o consultarse en los logs del sistema:

```bash
# Desde la consola de OPNsense (o via Diagnostics → Execute Command)
cat /var/log/suricata/eve.json | python3 -m json.tool | head -100
```

---

### 11.4 Limitaciones en entorno virtualizado

El despliegue de Suricata en este laboratorio presenta restricciones que deben tenerse en cuenta al interpretar los resultados y al extrapolar conclusiones a un entorno de producción.

**Recursos limitados:**
OPNsense dispone de 1.5 GB de RAM, de los cuales Suricata consume aproximadamente 300-400 MB con los rulesets activos. Esto representa cerca del 25% del total disponible, lo que deja poco margen para picos de tráfico. En producción, un sensor Suricata dedicado con inspección profunda de paquetes necesitaría un mínimo de 4-8 GB de RAM y CPUs modernas con soporte para instrucciones SIMD.

**Rulesets reducidos:**
Solo se han activado 7 rulesets de los disponibles. Conjuntos completos como `emerging-malware.rules` o `emerging-exploit.rules` se han excluido por su elevado consumo de memoria. En producción se activarían todos los rulesets relevantes para el sector y se complementarían con feeds de inteligencia de amenazas propios.

**Tráfico cifrado no inspeccionado:**
Suricata no puede inspeccionar el contenido de los túneles WireGuard ni del tráfico HTTPS sin configuración adicional de SSL inspection. En este laboratorio, el tráfico entre `external-kali` y OPNsense está cifrado por WireGuard, por lo que Suricata solo ve los datagramas UDP encapsulados en la interfaz WAN, no el contenido. La inspección real ocurre sobre la interfaz DMZ, donde el tráfico ya está descifrado.

**Modo IDS en lugar de IPS:**
Con IPS activo, Suricata puede introducir latencia adicional al inspeccionar cada paquete antes de reenviarlo. En una VM con 1 vCPU, esto podría degradar el rendimiento de la red. Se ha optado por IDS para mantener la fluidez del laboratorio. En producción, IPS se habilitaría en hardware dedicado con capacidad de línea garantizada.

**Sin persistencia de alertas a largo plazo:**
Las alertas se rotan diariamente y se conservan 7 días. No hay integración con un SIEM externo ni exportación a almacenamiento centralizado. En un entorno real, los eventos de Suricata se enviarían a un SIEM, como Elasticsearch/Kibana o Splunk, para correlación, retención a largo plazo y generación de informes de cumplimiento ENS.

**Superficie de detección parcial:**
Al monitorizar solo WAN y DMZ, el tráfico lateral entre VLAN10, VLAN20 y las interfaces VPN no es inspeccionado por Suricata. En producción, se añadiría un sensor en cada segmento crítico o se implementaría mirroring de puertos en el switch core para enviar todo el tráfico a un sensor dedicado.

**Resumen:** Las limitaciones descritas no invalidan el valor didáctico del laboratorio. Las pruebas de la sección 11.2 demuestran que Suricata detecta correctamente los patrones de ataque más comunes. Las limitaciones son propias del entorno virtualizado y se documentan explícitamente como parte del análisis de riesgos del sistema, en línea con los requisitos de documentación del ENS.

---

[📑 Volver al índice general](../README.md)  |  [← Anterior](10-dns-control-privacidad.md)  |  [Siguiente →](12-logs-trazabilidad-ens.md)