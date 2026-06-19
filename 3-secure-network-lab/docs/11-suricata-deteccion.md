## 11. Detección de intrusiones con Suricata

Suricata es el motor de detección y prevención de intrusiones integrado en OPNsense. En este laboratorio actúa como sensor de red sobre las interfaces WAN y DMZ, analizando el tráfico en busca de patrones maliciosos conocidos y generando alertas registradas en el panel de OPNsense.

Su presencia en la arquitectura cumple directamente con el control ENS `op.mon.1` relativo a la detección de intrusiones y complementa las reglas del firewall al aportar visibilidad sobre el contenido del tráfico, no solo sobre sus cabeceras.

### 11.1 Configuración aplicada y rulesets activos

La configuración se ha ajustado para adaptarse a las limitaciones de recursos del entorno virtualizado, priorizando los conjuntos de reglas más relevantes para el laboratorio.

#### Parámetros generales

| Parámetro | Valor | Justificación |
|---|---|---|
| Modo | IDS | Evita bloquear tráfico legítimo durante la fase de validación. |
| IPS mode | Habilitado tras validación | Permite bloqueo activo una vez comprobada la ausencia de falsos positivos. |
| Promiscuous mode | Deshabilitado | Suficiente para el tráfico que atraviesa OPNsense. |
| Interfaces monitorizadas | WAN, DMZ | WAN cubre ataques externos; DMZ protege el servidor web. |
| Pattern matcher | Aho-Corasick | Equilibra rendimiento y capacidad de detección. |
| Detect profile | Low | Reduce el consumo de memoria en el entorno virtualizado. |
| Home networks | `192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12` | Redes internas del laboratorio. |
| Syslog alerts | Habilitado | Integra los eventos con el sistema de logs. |
| Rotate log | Diario | Conservación de 7 días. |

#### Rulesets activos

| Ruleset | Descripción | Relevancia |
|---|---|---|
| `emerging-scan` | Detección de escaneos y reconocimiento. | Ataques desde `external-kali` con `nmap`. |
| `emerging-web_server` | Ataques a servidores web. | Protección del portal en DMZ. |
| `emerging-sql` | Intentos de inyección SQL. | Ataques al backend Flask/MariaDB. |
| `emerging-attack_response` | Indicadores de exploit exitoso. | Detección post-compromiso. |
| `emerging-dos` | Floods y denegación de servicio. | Simulación con `hping3`. |
| `botcc` | Comunicación con servidores C2 conocidos. | Control de tráfico saliente malicioso. |
| `abuse.ch.Feodotracker` | IPs asociadas a botnets activas. | Complementa `botcc` con feeds actualizados. |

### 11.2 Verificación de alertas con tráfico real

A diferencia de las reglas del firewall, que actúan sobre **cabeceras de paquetes**, las alertas de Suricata dependen de que el contenido del tráfico coincida con una **firma activa**. En un entorno virtualizado con recursos limitados, no todas las firmas generan alertas visibles, porque algunas requieren patrones muy concretos o volúmenes elevados de tráfico.

Por ello, la verificación se ha centrado en las reglas definidas por el usuario, diseñadas específicamente para el laboratorio y con resultados consistentes.

#### Prueba 1: Acceso normal al portal web desde la VPN de usuarios

```bash
sudo wg-quick up wg-users
curl http://172.16.0.10
```

Se genera una alerta en `Services → Intrusion Detection → Alerts` con acción `allowed`, interfaz `DMZ`, origen `10.10.2.51` y destino `172.16.0.10:80`.

#### Prueba 2: Intento de path traversal contra el portal web

```bash
curl "http://172.16.0.10/../../../etc/passwd"
```

El servidor responde con error 404, y las reglas emerging-web_server pueden generar alertas si detectan un intento de acceder a rutas fuera del directorio permitido, como `../../etc/passwd`, que es un ataque de path traversal.

#### Prueba 3: Escaneo de puertos desde WAN

```bash
sudo wg-quick down wg-users 2>/dev/null
sudo nmap -sS -T4 91.168.50.1
```

El firewall registra y bloquea los intentos en `Live View`. Aunque algunas firmas de `emerging-scan` no siempre aparezcan en la pestaña de alertas, el firewall sí proporciona visibilidad del intento.

#### Prueba 4: Tráfico DNS y HTTP desde la DMZ

Las alertas de la regla de monitorización hacia la DMZ aparecen de forma continua debido al tráfico legítimo del laboratorio, como consultas DNS y accesos HTTP. Esto confirma que Suricata permanece activo y observando el tráfico real del entorno.

### 11.3 Lectura de alertas en OPNsense

Las alertas de Suricata se consultan en `Services → Intrusion Detection → Alerts`. Las columnas principales muestran fecha y hora, SID, acción, interfaz, origen, destino y descripción de la firma.

El filtrado por `Source`, `Interface` o `SID` permite localizar eventos concretos, especialmente las reglas personalizadas del laboratorio. Además, las alertas de Suricata y los logs del firewall se complementan: **el firewall indica si el tráfico fue permitido o bloqueado, mientras que Suricata indica si el contenido coincide con una firma de ataque conocida**.

### 11.4 Qué hace Suricata que no hace el firewall: ventajas y complementariedad

El firewall de OPNsense actúa principalmente sobre las **cabeceras de los paquetes**: direcciones IP, puertos, protocolo y estado de la conexión. Decide si el tráfico se permite o se bloquea según reglas basadas en estos criterios. Suricata, en cambio, inspecciona el **contenido de los paquetes** (payload), lo que le aporta capacidades que el firewall no tiene.

#### Principales ventajas de Suricata frente al firewall

| Capacidad | Firewall | Suricata |
|---|---|---|
| Inspección de payload | No | Sí |
| Detección de patrones de ataque (SQLi, XSS, path traversal) | No | Sí |
| Detección de escaneos y reconocimiento basado en comportamiento | Limitada | Sí |
| Identificación de tráfico hacia C2 y botnets | Solo por IP/port | Sí, con reglas y feeds |
| Alertas detalladas con contexto de ataque | No | Sí |
| Modo IDS (solo alerta) y IPS (alerta + bloqueo) | Solo bloqueo | IDS e IPS |

**Ventajas clave:**

1. **Detección basada en contenido**: Suricata puede detectar inyecciones SQL, ataques XSS, path traversal, exploits conocidos y otros ataques que dependen del contenido del paquete, no solo de la IP o puerto.

2. **Visibilidad de ataques avanzados**: El firewall puede bloquear tráfico por IP o puerto, pero no sabe si dentro de ese tráfico hay un intento de exploit. Suricata identifica patrones maliciosos en el payload.

3. **Alertas con contexto**: Cada alerta de Suricata incluye información detallada sobre la firma que la generó, categoría de ataque, severidad y referencia, lo que facilita el análisis post-evento.

4. **IDS e IPS**: Suricata puede operar en modo IDS (solo alerta, sin bloqueo) para validar reglas sin afectar tráfico legítimo, y en modo IPS (alerta + bloqueo activo) cuando se confirma que no hay falsos positivos.

5. **Integración con feeds de inteligencia de amenazas**: Rulesets como `botcc` y `abuse.ch.Feodotracker` permiten detectar tráfico hacia servidores C2 conocidos y IPs de botnets activas, complementando las listas de IPs bloqueadas en el firewall.

#### Por qué se activa Suricata en este laboratorio

Se activa Suricata en el laboratorio para:

- **Complementar el firewall** con una capa de detección basada en contenido, no solo en cabeceras.
- **Cumplir con el control ENS `op.mon.1`** de detección de intrusiones.
- **Aportar visibilidad sobre ataques específicos** del escenario: escaneos desde `external-kali`, intentos de SQLi y XSS hacia el portal en DMZ, tráfico hacia C2 y botnets.
- **Validar el funcionamiento de reglas personalizadas** diseñadas para monitorizar tráfico hacia el servidor web de la DMZ (`172.16.0.10`) y hacia la base de datos (`192.168.20.10`).
- **Generar alertas estructuradas en formato JSON** (EVE syslog) para análisis posterior.

### 11.5 Posibles mejoras y evolución hacia producción

El despliegue actual de Suricata en el laboratorio cumple los objetivos didácticos, pero en un entorno de producción serían necesarias varias mejoras para aumentar la cobertura, la retención de eventos y la capacidad de correlación.

#### Mejoras de configuración y reglas

- **Activar más rulesets**: En producción se activarían conjuntos como `emerging-malware.rules`, `emerging-exploit.rules` y otros feeds de inteligencia de amenazas específicos de la organización.
- **Reglas personalizadas más selectivas**: Ajustar las reglas de usuario para evitar alertas masivas por tráfico legítimo y centrarse en eventos realmente relevantes.
- **Perfil de detección más alto**: Cambiar de `Low` a `Medium` o `High` según los recursos disponibles, para mejorar la cobertura de detección.
- **Modo IPS en WAN**: Una vez validado que no hay falsos positivos, activar IPS mode en la interfaz WAN para bloqueo activo de ataques conocidos.

#### Mejoras de infraestructura y recursos

- **Hardware dedicado o VM con más recursos**: En producción, un sensor Suricata debería tener al menos 4–8 GB de RAM y CPUs modernas, con capacidad de línea garantizada para no introducir latencia crítica.
- **Monitorización de todas las interfaces críticas**: Añadir sensores en VLANs internas (VLAN10, VLAN20) o implementar port mirroring en el switch core para inspeccionar tráfico lateral.

#### Mejoras de integración y correlación

- **Integración con SIEM**: Enviar las alertas de Suricata a un SIEM como Elasticsearch/Kibana, Splunk o Wazuh para correlación con otros eventos (firewall, sistemas, aplicaciones) y retención a largo plazo.
- **Automatización de respuestas**: En escenarios con IPS activo, se pueden automatizar bloqueos temporales de IPs maliciosas o creación de reglas dinámicas en el firewall.
- **SSL/TLS inspection**: Configurar inspección SSL para poder analizar tráfico HTTPS y túneles cifrados, ampliando la superficie de detección.

#### Mejoras de retención y reporting

- **Retención prolongada de alertas**: En lugar de 7 días, mantener los eventos en un SIEM durante meses o años según la normativa.
- **Reportes periódicos**: Generar reportes de ataques detectados, tendencias de tráfico malicioso y métricas de eficacia de las reglas.

### 11.6 Limitaciones en entorno virtualizado

El despliegue de Suricata en este laboratorio tiene varias limitaciones que deben considerarse al interpretar los resultados. La memoria disponible es reducida y solo se han activado los rulesets más relevantes, dejando fuera conjuntos más pesados.

Además, el tráfico cifrado por WireGuard no puede inspeccionarse en la WAN, y solo el tráfico ya descifrado en la DMZ ofrece visibilidad completa. También debe tenerse en cuenta que el modo IPS puede introducir latencia adicional, especialmente en una VM con recursos limitados.

Por último, las alertas se conservan solo durante un periodo corto y no se envían a un SIEM externo, por lo que su utilidad es principalmente operativa y didáctica dentro del laboratorio.

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="10-dns-control-privacidad.md">← Anterior</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <a href="../README.md">Volver al índice</a>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <a href="12-logs-trazabilidad-ens.md">Siguiente →</a>
    </td>
  </tr>
</table>