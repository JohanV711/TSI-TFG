## 7. Pruebas de verificación funcional

Esta sección documenta las pruebas que confirman el comportamiento correcto de la arquitectura de seguridad. Cada escenario incluye los comandos a ejecutar, el resultado esperado y una explicación detallada de por qué se obtiene ese resultado.

> **Nota:** Solo debe estar activa una VPN a la vez. Los perfiles `wg-admins` y `wg-users` no pueden convivir porque ambos fuerzan el tráfico por su túnel. Antes de cambiar de perfil, desactiva el actual con `sudo wg-quick down`.

---

### 7.1 Escenario sin VPN — acceso bloqueado desde exterior

**Objetivo:** Verificar que sin túnel VPN activo, `external-kali` no puede acceder a ningún recurso interno salvo al puerto WireGuard de OPNsense.

**Preparación:**

```bash
sudo wg-quick down wg-admins 2>/dev/null
sudo wg-quick down wg-users 2>/dev/null
```

**Prueba 1: Conectividad con OPNsense WAN**

```bash
ping -c 3 91.168.50.1
```

**Resultado esperado:** `100% packet loss` (sin respuesta).

**Explicación:** OPNsense no tiene una regla explícita que permita ICMP entrante en la WAN. La política por defecto deniega todo lo no autorizado. El ping de OPNsense hacia `external-kali` sí funciona por el comportamiento stateful del firewall, que permite respuestas a conexiones iniciadas localmente.

---

**Prueba 2: Escaneo de puertos en OPNsense WAN**

```bash
sudo nmap -sS -T4 91.168.50.1
```

**Resultado esperado:** `1000 puertos TCP filtrados (filtered)`.

**Explicación:** Solo los puertos WireGuard (`51820` y `51821` UDP) están abiertos. `nmap -sS` escanea TCP, por lo que todos aparecen filtrados. Esto confirma la reducida superficie de ataque.

---

**Prueba 3: Acceso al portal web DMZ**

```bash
curl --connect-timeout 5 http://172.16.0.10
```

**Resultado esperado:** Timeout o `No route to host`.

**Explicación:** El firewall bloquea cualquier tráfico desde WAN hacia la DMZ. No existe regla que permita HTTP desde la WAN a la DMZ.

---

**Prueba 4: Acceso a la base de datos**

```bash
nc -zv 192.168.20.10 3306
```

**Resultado esperado:** Timeout. Ctrl+C si no se detiene.

**Explicación:** La VLAN20 no es accesible desde la WAN. El mismo principio de denegación por defecto se aplica.

---

**Prueba 5: Acceso a la WebUI de gestión**

```bash
curl --connect-timeout 5 https://192.168.10.1
```

**Resultado esperado:** Timeout.

**Explicación:** La red de gestión solo es accesible a través de la VPN de administradores.

---

### 7.2 Escenario con `wg-users` — acceso restringido a DMZ

**Objetivo:** Verificar que con la VPN de usuarios activa solo se puede acceder al portal web de la DMZ, pero no a la base de datos ni a la gestión.

**Preparación:**

```bash
sudo wg-quick up wg-users
```

**Prueba 1: Estado del túnel**

```bash
sudo wg show wg-users
```

**Resultado esperado:** `latest handshake` reciente (< 2 minutos), `transfer` con bytes enviados y recibidos > 0.

**Explicación:** El túnel se ha negociado correctamente. El keepalive cada 25 segundos mantiene la conexión.

---

**Prueba 2: Acceso al portal web DMZ**

```bash
curl http://172.16.0.10
```

**Resultado esperado:** HTML del portal corporativo.

**Explicación:** La regla de firewall permite tráfico desde `wg-users` (`10.10.2.0/24`) hacia la DMZ en el puerto 80.

---

**Prueba 3: Acceso al listado de empleados**

```bash
curl http://172.16.0.10/empleados
```

**Resultado esperado:** JSON con datos de empleados.

**Explicación:** La aplicación Flask consulta MariaDB desde el backend (IP `172.16.0.10`). El cliente VPN solo ve el resultado, no accede directamente a la base de datos.

---

**Prueba 4: Acceso a la base de datos (debe fallar)**

```bash
nc -zv 192.168.20.10 3306
```

**Resultado esperado:** Timeout.

**Explicación:** El firewall bloquea el tráfico de `wg-users` hacia VLAN20. La regla que permite MySQL solo tiene como origen `dmz-server` (`172.16.0.10`).

---

**Prueba 5: Acceso a la WebUI de OPNsense (debe fallar)**

```bash
curl --connect-timeout 5 https://192.168.10.1
```

**Resultado esperado:** Timeout.

**Explicación:** La VLAN10 está bloqueada para los usuarios estándar de VPN.

---

### 7.3 Escenario con `wg-admins` — acceso completo a la infraestructura

**Objetivo:** Verificar que la VPN de administradores otorga acceso sin restricciones a todas las zonas internas, pero que MariaDB impone su propia capa de autenticación.

**Preparación:**

```bash
sudo wg-quick down wg-users
sudo wg-quick up wg-admins
```

**Prueba 1: Estado del túnel**

```bash
sudo wg show wg-admins
```

**Resultado esperado:** `latest handshake` reciente, `transfer` > 0.

**Explicación:** Confirmación de que el túnel de administración está operativo.

---

**Prueba 2: Acceso al portal web DMZ**

```bash
curl http://172.16.0.10
```

**Resultado esperado:** HTML del portal.

**Explicación:** Los administradores tienen acceso completo a la DMZ.

---

**Prueba 3: Acceso a la WebUI de OPNsense**

```bash
curl -k --connect-timeout 5 https://192.168.10.1
```

O en `http://localhost:8081/vnc.html` con contraseña `vagrant` cada vez que se solicite credenciales (pulsar en la pantalla si se queda en negro) se puede comprobar con el navegador Firefox a introducir https://192.168.10.1 y aparecerá la interfaz gráfica web de OPNSense. Las credenciales se recuerdan aqui:

```bash
root
```
**Contraseña**:
```bash
Contraseniarobustademinimo16caracteres!.
```

**Resultado esperado:** HTML de la página de login de OPNsense.

**Explicación:** La regla `VPN_ADMINS → RED_GESTION` permite el acceso. `-k` omite la verificación del certificado autofirmado.

---

**Prueba 4: Acceso SSH a `vlan20-server`**

```bash
nc -znv 192.168.20.10 22
```

**Resultado esperado:** `Connection to 192.168.20.10 22 port [tcp/ssh] succeeded!` o `
(UNKNOWN) [192.168.20.10] 3306 (mysql) open`

**Explicación:** La regla `VPN_ADMINS → RED_SERVIDORES` permite el tráfico. El acceso efectivo por SSH requeriría además credenciales válidas (otra capa de defensa).

---

**Prueba 5: Verificación de conectividad TCP a MySQL**

```bash
nc -znv 192.168.20.10 3306
```

**Resultado esperado:** Alguna de estas dos respuestas (ambas equivalentes):

```text
Connection to 192.168.20.10 3306 port [tcp/mysql] succeeded!
```

o bien:

```text
(UNKNOWN) [192.168.20.10] 3306 (mysql) open
```

El mensaje `inverse host lookup failed` que puede aparecer es irrelevante: solo indica que no existe registro DNS inverso para esa IP privada de laboratorio. No afecta al resultado de la prueba.

**Explicación:** El firewall OPNsense permite el tráfico porque existe una regla explícita desde `VPN_ADMINS` hacia `RED_SERVIDORES`. Sin embargo, esto no significa que se pueda consultar la base de datos. El siguiente paso lo demuestra. 

---

**Prueba 6: Intento de consulta MySQL (debe fallar por autenticación)**

```bash
mariadb -h 192.168.20.10 -u webuser -pwebpassword empresa -e "SELECT 1;" 2>&1
```

**Resultado esperado:**

```text
ERROR 2002 (HY000): Received error packet before completion of TLS handshake. The authenticity of the following error cannot be verified: 1130 - Host '10.10.1.51' is not allowed to connect to this MariaDB server
```

**Explicación fundamental:** MariaDB rechaza la conexión antes de completar el handshake TLS, mostrando el error 1130. El mensaje advierte que la autenticidad del error no puede verificarse justamente porque la conexión TLS no llegó a establecerse. El motivo real es que el usuario `webuser` solo puede conectarse desde `172.16.0.10` (dmz-server). La IP de la VPN de administradores (`10.10.1.51`) no está autorizada. Este comportamiento demuestra la defensa en profundidad: aunque el firewall permite el tráfico, la base de datos añade una segunda barrera.

---

### 7.4 Verificación del portal web y consulta a base de datos

**Objetivo:** Confirmar que el portal web en `dmz-server` puede consultar la base de datos en `vlan20-server`, y que esa consulta es la única comunicación permitida entre ambas zonas.

**Prueba 1: Consulta desde el portal web**

```bash
# Desde external-kali con cualquier VPN activa
curl http://172.16.0.10/empleados
```

**Resultado esperado:**

```json
[
  {"departamento":"Seguridad IT", "id":1,"nombre":"Johan Vargas","departamento":"Seguridad IT"},
  {"departamento":"Desarrollo", "id":2,"nombre":"Cristian Alvarez","departamento":"Desarrollo"},
  ...
]
```

**Explicación:** Flask consulta MariaDB usando `webuser` desde la IP autorizada (`172.16.0.10`). Los datos se devuelven en formato JSON al cliente VPN.

---

**Prueba 2: Verificación de la conexión MySQL desde `dmz-server`**

```bash
# Desde dmz-server (vagrant ssh)
mariadb -h 192.168.20.10 -u webuser -pwebpassword empresa -e "SELECT COUNT(*) FROM empleados;"
```

**Resultado esperado:** `6`

**Explicación:** Conexión exitosa desde la IP autorizada. `webuser` solo tiene permiso SELECT sobre la tabla `empleados`.

---

**Prueba 3: Intento de acceso desde `dmz-server` a otras tablas**

```bash
mariadb -h 192.168.20.10 -u webuser -pwebpassword empresa -e "SELECT * FROM accesos;"
```

**Resultado esperado:** `ERROR 1142 (42000): SELECT command denied to user 'webuser'@'172.16.0.10' for table 'accesos'`

**Explicación:** Los permisos de `webuser` están limitados explícitamente a la tabla `empleados`, cumpliendo el principio de mínimo privilegio también a nivel de base de datos.

---

### 7.5 Verificación de conectividad entre zonas internas

**Objetivo:** Comprobar que las reglas de firewall entre zonas internas funcionan según lo diseñado: la DMZ puede consultar MySQL en VLAN20, pero no acceder a la red de gestión ni a otros servicios.

**Prueba 1: Conectividad DMZ → VLAN20 (MySQL)**

```bash
# Desde dmz-server
nc -zv 192.168.20.10 3306
```

**Resultado esperado:** Conexión exitosa.

**Explicación:** La regla que permite consultas MySQL desde la DMZ hacia VLAN20 está activa.

---

**Prueba 2: Conectividad DMZ → VLAN20 (otros puertos)**

```bash
# Desde dmz-server
nc -zv 192.168.20.10 22
nc -zv 192.168.20.10 80
```

**Resultado esperado:**

- Puerto 22: timeout (sin respuesta, requiere Ctrl+C).
- Puerto 80: timeout o `Connection refused`.

**Explicación:** Solo el puerto 3306 está autorizado. Los demás paquetes son descartados (DROP) o rechazados (REJECT) según la acción configurada en la regla de bloqueo, pero en ningún caso se permite la conexión.

---

**Prueba 3: Conectividad DMZ → VLAN10 (gestión)**

```bash
# Desde dmz-server
curl --connect-timeout 5 https://192.168.10.1
```

**Resultado esperado:** Timeout o `No route to host`.


**Explicación:** La regla de bloqueo explícita impide cualquier comunicación desde la DMZ hacia la VLAN de gestión. Si un atacante compromete el servidor web, no puede alcanzar la consola del firewall.

---

### 7.6 Verificación de salida a internet controlada por OPNsense

**Objetivo:** Confirmar que `dmz-server` y `vlan20-server` acceden a internet exclusivamente a través de OPNsense, sin usar la NAT de Vagrant.

> **Nota sobre ICMP:** OPNsense no tiene habilitada una regla que permita tráfico ICMP (ping) desde las redes internas hacia el exterior. Por tanto, **no se debe usar `ping` ni `traceroute` tradicional para verificar conectividad a internet**, ya que ambos dependen de ICMP y fallarán aunque la conexión funcione. La verificación se realiza con `curl`, que utiliza TCP en los puertos 80/443.

> La IP pública que mostrarán los comandos siguientes será la del servidor anfitrión donde se ejecuta VirtualBox, no la de la WAN simulada del laboratorio (`91.168.50.0/24`). Esto es normal porque OPNsense sale a internet real a través de la NAT del host.

---

**Prueba 1: Ruta por defecto en `dmz-server`**

```bash
# Desde dmz-server
ip route show default
```

**Resultado esperado:** `default via 172.16.0.1 dev enp0s8`

**Explicación:** La ruta por defecto apunta al gateway de la DMZ (OPNsense), no a `10.0.2.2` (NAT de VirtualBox).

---

**Prueba 2: Salida a internet desde `dmz-server`**

```bash
# Desde dmz-server
curl -s ifconfig.me && echo
```

**Resultado esperado:** IP pública del host anfitrión.

**Explicación:** El tráfico sale por OPNsense y NATea hacia la red real. Este comando confirma que hay conectividad a internet a través del firewall.

---

**Prueba 3: Ruta por defecto en `vlan20-server`**

```bash
# Desde vlan20-server
ip route show default
```

**Resultado esperado:** `default via 192.168.20.1 dev enp0s8`

**Explicación:** Mismo principio que en la DMZ.

---

**Prueba 4: Salida a internet desde `vlan20-server`**

```bash
# Desde vlan20-server
curl -s ifconfig.me && echo
```

**Resultado esperado:** IP pública del host anfitrión.

**Explicación:** Todo el tráfico de la organización sale por el mismo punto.

---

**Prueba 5: `external-kali` sin VPN mantiene su propia salida**

```bash
# Desde external-kali con todas las VPNs desactivadas
curl -s ifconfig.me && echo
```

**Resultado esperado:** IP pública de la NAT de Vagrant (diferente a la del host anfitrión).

**Explicación:** `external-kali` conserva su interfaz NAT (`eth0`) como ruta por defecto gracias a `never-default` en `eth1`. Esto le permite salir directamente a internet sin pasar por OPNsense, simulando un atacante externo real con su propia conectividad.

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="06-acceso-servicios.md">← Anterior</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <a href="../README.md">Volver al índice</a>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <a href="08-control-trafico-firewall.md">Siguiente →</a>
    </td>
  </tr>
</table>