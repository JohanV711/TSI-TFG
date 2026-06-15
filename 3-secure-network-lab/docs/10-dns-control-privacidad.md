## 10. DNS — control y privacidad

El sistema de resolución de nombres es uno de los vectores de control más efectivos en una arquitectura de red corporativa. En este laboratorio, OPNsense actúa como **resolver DNS autoritativo** para todas las zonas internas, interceptando cualquier consulta que intente saltarse este control y aplicando filtrado de dominios a nivel de DNS. Adicionalmente, las consultas salientes van cifradas mediante DNS over TLS, protegiendo la privacidad de la organización frente a terceros.

---

### 10.1 Redirección forzada de DNS por OPNsense (Port Forward)

Por defecto, un cliente puede configurar manualmente cualquier servidor DNS externo (`8.8.8.8`, `1.1.1.1`, etc.) y saltarse así los controles de filtrado aplicados en el resolver interno. Para evitarlo, en nuestra configuración forzamos a OPNsense a que **intercepte toda consulta DNS** que salga de las redes internas, independientemente del servidor de destino configurado en el cliente, y la redirija a Unbound DNS. 

**Unbound DNS** es el servidor DNS resolver que viene predeterminado en OPNsense y actúa como un resolvedor, validador y caché. A diferencia de los servicios de reenvío tradicionales, Unbound es un **resolvedor recursivo**, lo que significa que, en lugar de preguntar directamente a los DNS del proveedor de internet (ISP), se comunica directamente con los **servidores raíz** de internet para encontrar las direcciones IP por sí mismo.

Las ventajas principales de usar Unbound DNS incluyen:
- **Privacidad mejorada**: Evitas que el proveedor de internet registre todas las páginas web que se visiten.
- **Caché local**: Almacena en memoria las direcciones que ya has visitado para acelerar la navegación de otros equipos en la red.
- **Control local**: Permite configurar bloqueos por dominio (como bloquear anuncios, malware o redes sociales) directamente en el firewall.

**Mecanismo:** Se implementa mediante reglas de NAT de destino (Port Forward) en cada interfaz interna. Cuando un cliente envía una consulta UDP o TCP al puerto 53 hacia cualquier IP que no sea OPNsense, el firewall reescribe el destino y la entrega a Unbound. 

**Reglas configuradas en Firewall → NAT → Port Forward:**

| Interfaz | Origen | Destino original | Redirige a |
|----------|--------|-----------------|------------|
| DMZ | RED_DMZ | ! 172.16.0.1 : 53 | 172.16.0.1 : 53 |
| LAN_VLAN20 | RED_SERVIDORES | ! 192.168.20.1 : 53 | 192.168.20.1 : 53 |
| wgadmins | VPN_ADMINS | ! 10.10.1.1 : 53 | 10.10.1.1 : 53 |
| wgusers | VPN_USERS | ! 10.10.2.1 : 53 | 10.10.2.1 : 53 |

El símbolo `!` indica negación: la regla se aplica a cualquier destino excepto la propia IP de OPNsense en esa interfaz, evitando bucles. 

**Flujo completo con redirección:**

```text
Cliente configura DNS: 8.8.8.8
│
▼
Envía consulta UDP → 8.8.8.8:53
│
▼
OPNsense intercepta (Port Forward)
│
▼
Reescribe destino → 10.10.1.1:53 (Unbound)
│
▼
Unbound resuelve aplicando políticas de filtrado
│
▼
Respuesta al cliente
```

**Relación con ENS:** Esta medida implementa el control de acceso a nivel de red y garantiza que las políticas de filtrado de contenido no puedan ser eludidas por configuración manual del cliente.

---

### 10.2 Verificación de que el DNS externo queda interceptado

Las siguientes pruebas confirman que la redirección es efectiva independientemente del servidor DNS que intente usar el cliente.

**Desde `external-kali` con `wg-admins` activo:**

**Prueba 1: Consulta forzando DNS externo — debe ser interceptada**

```bash
nslookup google.com 8.8.8.8
```

**Resultado esperado:**

```text
Server:         8.8.8.8
Address:        8.8.8.8#53

Non-authoritative answer:
Name:   google.com
Address: x.x.x.x
Name:   google.com
Address: xxxx:xxxx:xxxx:xxx::xxxx
```

Aunque el campo `Server` muestre `8.8.8.8`, la consulta no llegó a Google. OPNsense interceptó el paquete y fue Unbound quien respondió. El cliente no puede distinguirlo porque la respuesta es válida. Se puede confirmar revisando el Live View del firewall, donde aparecerá la regla de Port Forward actuando sobre ese tráfico. 

**Prueba 2: Verificación en el Live View de OPNsense**

Mientras se ejecuta la prueba anterior, en `Firewall → Log Files → Live View` se observa:

```text
Interface: wgadmins
Source:    10.10.1.51:XXXXX
Dest:      10.10.1.1:53
Proto:     UDP
Rule:      DNS hacia Opensense
```

Esto confirma que el paquete fue capturado y redirigido antes de salir por la WAN. 

![Live View de OPNsense](images/image6.png)

*Figura 7: Live View de OPNsense. Se observa cómo una consulta DNS dirigida a 8.8.8.8 es interceptada y redirigida a Unbound.*

**Desde `dmz-server`:**

```bash
nslookup google.com 1.1.1.1
```

**Resultado esperado:** Respuesta válida de Unbound, no de Cloudflare. Verificable en Live View con la regla de Port Forward de la interfaz DMZ. 

---

### 10.3 Bloqueo de dominios mediante Unbound Host Overrides

Unbound permite responder con una IP específica para cualquier dominio, independientemente de lo que devuelva el resolver upstream. En este laboratorio se usa para bloquear redes sociales devolviendo `0.0.0.0`, lo que hace que el cliente no pueda establecer ninguna conexión con esos dominios. 

**Dominios bloqueados configurados en Services → Unbound DNS → Overrides → Host Overrides:**

| Host | Dominio | Responde con |
|---|---|---|
| `*` | `instagram.com` | `0.0.0.0` |
| `*` | `cdninstagram.com` | `0.0.0.0` |
| `*` | `i.instagram.com` | `0.0.0.0` |
| `*` | `facebook.com` | `0.0.0.0` |
| `*` | `fbcdn.net` | `0.0.0.0` |
| `*` | `fb.com` | `0.0.0.0` |

El comodín `*` en el campo Host cubre cualquier subdominio (`www.instagram.com`, `static.instagram.com`, etc.). 

![Listado de Host Overrides en Unbound DNS](images/image7.png)

*Figura 8: Listado de Host Overrides en Unbound DNS. Se muestran los dominios bloqueados con la respuesta forzada a 0.0.0.0.*

**Alternativa no utilizada: Blocklists automáticas**

OPNsense permite cargar listas de bloqueo mantenidas por la comunidad (como las de StevenBlack, Firebog, etc.) desde **Services → Unbound DNS → Blocklist**. Estas listas agrupan dominios por categorías —redes sociales, malware, publicidad, pornografía, etc.— y se actualizan periódicamente sin intervención manual.

Para este laboratorio se descartó esta opción por dos motivos:

1. **Consumo de recursos:** cada lista descargada se convierte en miles de entradas que Unbound debe mantener en memoria. En un entorno virtualizado con 1,5 GB de RAM para OPNsense, cargar una blocklist completa podría afectar al rendimiento del resto de servicios (Suricata, VPN, firewall).
2. **Valor didáctico:** la configuración manual mediante Host Overrides obliga a definir explícitamente cada dominio y su respuesta forzada. **Esto permite entender el mecanismo subyacente** y verificar con precisión qué dominios se bloquean, algo que una blocklist oculta tras una interfaz de “activo/inactivo”.

En un despliegue real se combinarían ambas técnicas: blocklists para categorías amplias (malware, phishing) y Host Overrides para excepciones puntuales o dominios corporativos bloqueados por política interna.

**Verificación del bloqueo:**

```bash
# Desde external-kali con cualquier VPN activa
nslookup instagram.com 10.10.1.1
```

**Resultado esperado:**

```text
Server:         10.10.1.1
Address:        10.10.1.1#53

Name:   instagram.com
Address: 0.0.0.0
```

```bash
# Intentar cargar la página (debe fallar)
curl --connect-timeout 3 https://www.instagram.com -k
```

**Resultado esperado:** `curl: (7) Failed to connect to www.instagram.com port 443`

**Verificación con DNS externo interceptado:**

```bash
# Aunque se use 8.8.8.8, OPNsense intercepta y Unbound bloquea igualmente
nslookup instagram.com 8.8.8.8
```

**Resultado esperado:** `Address: 0.0.0.0`

Esto demuestra que el bloqueo es efectivo incluso cuando el cliente intenta eludir el DNS interno, gracias a la combinación de redirección forzada y filtrado en Unbound. 

**Relación con ENS:** El control de acceso a contenidos y la protección frente a código dañino justifican esta medida. En un entorno real se complementaría con un proxy HTTP/HTTPS con inspección de contenido para cubrir casos en que se use DNS sobre HTTPS en el navegador. 

**Limitación conocida:** Si un cliente usa DNS sobre HTTPS directamente en el navegador, el bloqueo puede eludirse porque el tráfico va cifrado por HTTPS y no por el puerto 53. En producción se añadiría una regla de firewall para bloquear los servidores DoH conocidos.

---

### 10.4 DNS over TLS hacia Cloudflare y Quad9

Mientras las secciones anteriores controlan el DNS entrante, esta sección aborda el DNS saliente: las consultas que Unbound realiza hacia Internet para resolver dominios que no están en caché ni en los Host Overrides.

Sin DNS over TLS (DoT), estas consultas salen en texto plano por UDP/53 y pueden ser observadas por el ISP o cualquier agente en la ruta de red, revelando qué dominios consulta la organización. Con DoT activado, Unbound establece una conexión TLS cifrada con los resolvers upstream antes de enviar ninguna consulta. El contenido de las consultas es confidencial para cualquier observador externo.

**Configuración aplicada en Services → Unbound DNS → DNS over TLS:**

| Servidor | IP | Puerto | CN verificado | Descripción |
|---|---:|---:|---|---|
| Cloudflare | 1.1.1.1 | 853 | `cloudflare-dns.com` | Resolver primario |
| Quad9 | 9.9.9.9 | 853 | `dns.quad9.net` | Resolver de respaldo |

**Verificación de que las consultas salen cifradas:**

En `Firewall → Log Files → Live View`, filtrar por el puerto 853:

```text
Interface: WAN para internet real
Source:    10.0.2.15:XXXXX
Dest:      1.1.1.1:853
Proto:     TCP
Rule:      let out anything from firewall host itself
```

Se observa TCP al puerto 853, es decir, DoT, en lugar de UDP al puerto 53, DNS en claro. Las consultas van cifradas mediante TLS 1.3. 

![Live View de OPNsense](images/image8.png)

*Figura 9: Live View de OPNsense. Se observan las consultas DNS salientes de Unbound hacia 1.1.1.1:853 usando TCP cifrado.*

**Cadena completa de resolución DNS en este laboratorio:**

```text
Cliente VPN (external-kali)
        │  consulta DNS (UDP/53)
        ▼
OPNsense intercepta (Port Forward si el destino no es OPNsense)
        │
        ▼
Unbound (10.10.1.1 / 10.10.2.1 / etc.)
        │  comprueba Host Overrides → bloquea instagram.com → 0.0.0.0
        │  si no hay override, consulta upstream
        ▼
Cloudflare 1.1.1.1:853 (TCP cifrado con TLS)
        │
        ▼
Respuesta cifrada → Unbound la descifra → responde al cliente
```

**Relación con ENS:** El cifrado de las comunicaciones DNS implementa la medida de protección de la confidencialidad del ENS. Adicionalmente, el uso de Quad9 como resolver de respaldo aporta una capa de filtrado adicional, ya que Quad9 bloquea dominios maliciosos conocidos antes de resolver.

**Nota sobre Forward Mode:** Para que DoT funcione, Unbound debe estar configurado en modo forwarding (`Enable Forwarding Mode` en `Services → Unbound DNS → General`). Sin esta opción, Unbound resolvería directamente contra los servidores raíz por UDP/53 y las entradas DoT serían ignoradas.

---

[📑 Volver al índice general](../README.md)  |  [← Anterior](09-vpn-wireguard.md)  |  [Siguiente →](11-suricata-deteccion.md)