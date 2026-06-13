## 7. Pruebas de verificación funcional

Esta sección documenta las pruebas que confirman el comportamiento correcto de la arquitectura de seguridad. Cada escenario incluye los comandos a ejecutar, el resultado esperado y una explicación detallada de por qué se obtiene ese resultado.

### 7.1 Escenario sin VPN — acceso bloqueado desde exterior

**Objetivo:** Verificar que sin túnel VPN activo, `external-kali` no puede acceder a ningún recurso interno salvo al puerto WireGuard de OPNsense.

**Preparación:**

```bash
# Asegurarse de que ninguna VPN está activa
sudo wg-quick down wg-admins 2>/dev/null
sudo wg-quick down wg-users 2>/dev/null
```

**Prueba 1: Conectividad con OPNsense WAN**

```bash
ping -c 3 91.168.50.1
```

**Resultado esperado:** Sin respuesta (100% packet loss).

**Explicación:** La interfaz WAN de OPNsense es accesible desde la red externa porque debe recibir las conexiones entrantes para establecer los túneles WireGuard. El ping no funciona debido a la política de denegación de tráfico entrante al firewall y sin que haya una regla explícita permitiendo tráfico con protocolo ICMP. Se podría agregar una regla en la interfaz WAN permitiendo tráfico ICMP y asi si que se podría hacer ping desde external-kali. Desde OPNsense si que hay ping hacia external-kali debido al comportamiento **stateful** de OPNsense que cuando inicia él el tráfico entonces si tiene permitido aceptar el tráfico de vuelta como respuesta a una petición inicial que hizo.

**Prueba 2: Escaneo de puertos en OPNsense WAN**

```bash
sudo nmap -sS -T4 91.168.50.1
```

**Resultado esperado:** 1000 puertos filtrados (estado `filtered`).

**Explicación:** OPNsense aplica una política de denegación por defecto. Solo los puertos WireGuard (51820 y 51821 UDP) están abiertos, pero `nmap` con `-sS` solo escanea TCP, por lo que todos aparecen como filtrados. Esto confirma que la superficie de ataque está reducida al mínimo.

**Prueba 3: Acceso al portal web DMZ**

```bash
curl --connect-timeout 5 http://172.16.0.10
```

**Resultado esperado:** Timeout o `No route to host`.

**Explicación:** El firewall bloquea todo el tráfico desde WAN hacia la DMZ. La regla por defecto deniega cualquier paquete que no tenga una regla explícita de permiso. Como no hay una regla que permita HTTP desde WAN a DMZ, el tráfico se descarta silenciosamente.

**Prueba 4: Acceso a la base de datos**

```bash
nc -zv 192.168.20.10 3306
```

**Resultado esperado:** Timeout o unknow host.

**Explicación:** Mismo principio que con la DMZ. La VLAN20 es una zona de máxima restricción y no acepta conexiones desde la WAN.

**Prueba 5: Acceso a la WebUI de gestión**

```bash
curl --connect-timeout 5 https://192.168.10.1
```

**Resultado esperado:** Timeout.

**Explicación:** La red de gestión solo es accesible desde la VPN de administradores.

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

**Explicación:** El túnel WireGuard se ha negociado correctamente con OPNsense. El handshake periódico (cada 25 segundos por `PersistentKeepalive`) mantiene la conexión viva.

**Prueba 2: Acceso al portal web DMZ**

```bash
curl http://172.16.0.10
```

**Resultado esperado:** HTML del portal corporativo.

**Explicación:** La regla de firewall que permite tráfico desde `wg-users` (10.10.2.0/24) hacia la DMZ (172.16.0.10) en el puerto 80 está configurada explícitamente.

**Prueba 3: Acceso al listado de empleados**

```bash
curl http://172.16.0.10/empleados
```

**Resultado esperado:** JSON con los datos de empleados.

**Explicación:** La aplicación Flask consulta la base de datos en `vlan20-server` desde el backend (no desde el cliente VPN). El servidor web actúa como intermediario, por lo que el usuario de VPN no necesita acceso directo a la base de datos.

**Prueba 4: Acceso a la base de datos (debe fallar)**

```bash
nc -zv 192.168.20.10 3306
```

**Resultado esperado:** Timeout.

**Explicación:** El firewall bloquea el tráfico desde `wg-users` hacia `vlan20-server`. La regla que permite MySQL solo tiene como origen `dmz-server` (172.16.0.10). Esto implementa el principio de mínimo privilegio: los usuarios estándar no necesitan acceso directo a los servidores de datos.

**Prueba 5: Acceso a la WebUI de OPNsense (debe fallar)**

```bash
curl --connect-timeout 5 https://192.168.10.1
```

**Resultado esperado:** Timeout.

**Explicación:** La red de gestión (VLAN10) está bloqueada para los usuarios de `wg-users`. La administración del firewall es una función sensible que solo debe estar disponible para administradores.

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

**Prueba 2: Acceso al portal web DMZ**

```bash
curl http://172.16.0.10
```

**Resultado esperado:** HTML del portal.

**Explicación:** Los administradores tienen acceso completo a la DMZ, al igual que los usuarios.

**Prueba 3: Acceso a la WebUI de OPNsense**

```bash
curl -k --connect-timeout 5 https://192.168.10.1
```

**Resultado esperado:** HTML de la página de login de OPNsense.

**Explicación:** La regla `VPN_ADMINS → RED_GESTION` permite el acceso. El parámetro `-k` evita la verificación del certificado autofirmado.

**Prueba 4: Acceso SSH a `vlan20-server`**

```bash
nc -zv 192.168.20.10 22
```

**Resultado esperado:** `SSH OK`.

**Explicación:** La regla `VPN_ADMINS → RED_SERVIDORES` permite cualquier tráfico hacia la VLAN20. Los administradores necesitan acceso SSH para tareas de mantenimiento. el firewall permite el acceso al puerto SSH, pero la autenticación la gestiona el servidor — igual que con MariaDB, otra capa de defensa en profundidad

**Prueba 5: Verificación de conectividad TCP a MySQL**

```bash
nc -zv 192.168.20.10 3306
```

**Resultado esperado:** `Connection to 192.168.20.10 3306 port [tcp/mysql] succeeded!`

**Explicación:** El firewall OPNsense permite el tráfico porque existe una regla explícita desde `VPN_ADMINS` hacia `RED_SERVIDORES`. Sin embargo, esto no significa que se pueda consultar la base de datos. El siguiente paso lo demuestra.

**Prueba 6: Intento de consulta MySQL (debe fallar por autenticación)**

```bash
mariadb -h 192.168.20.10 -u webuser -pwebpassword empresa -e "SELECT 1;" 2>&1
```

**Resultado esperado:** `ERROR 1130 (HY000): Host '10.10.1.51' is not allowed to connect to this MariaDB server`

**Explicación fundamental:** Este resultado demuestra la defensa en profundidad. Aunque el firewall permite la conexión a nivel de red, MariaDB tiene su propia capa de control de acceso. El usuario `webuser` fue creado con la restricción `'webuser'@'172.16.0.10'`, lo que significa que solo puede conectarse desde el servidor DMZ. La IP de la VPN de administradores (10.10.1.51) no está autorizada. Un atacante que comprometiera la VPN de administradores aún necesitaría credenciales de base de datos válidas o acceso desde la IP autorizada, añadiendo una barrera adicional.

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
  {"id":1,"nombre":"Johan Vargas","departamento":"Seguridad IT"},
  {"id":2,"nombre":"Cristian Alvarez","departamento":"Desarrollo"},
  ...
]
```

**Explicación:** El portal web ejecuta una consulta MySQL usando las credenciales `webuser` desde la IP `172.16.0.10`, que sí está autorizada en MariaDB. Los datos se devuelven en formato JSON al cliente VPN.

**Prueba 2: Verificación de la conexión MySQL desde `dmz-server`**

```bash
# Acceder por SSH a dmz-server (vagrant ssh o desde VPN admins)
mariadb -h 192.168.20.10 -u webuser -pwebpassword empresa -e "SELECT COUNT(*) FROM empleados;"
```

**Resultado esperado:** `6`

**Explicación:** La conexión se realiza desde la IP autorizada (172.16.0.10). El usuario `webuser` solo tiene permisos de SELECT sobre la tabla `empleados`, cumpliendo el principio de mínimo privilegio también a nivel de base de datos.

**Prueba 3: Intento de acceso desde `dmz-server` a otras tablas**

```bash
mariadb -h 192.168.20.10 -u webuser -pwebpassword empresa -e "SELECT * FROM accesos;"
```

**Resultado esperado:** `ERROR 1142 (42000): SELECT command denied to user 'webuser'@'172.16.0.10' for table 'accesos'`

**Explicación:** Los permisos de `webuser` están limitados explícitamente a la tabla `empleados`. No puede acceder a datos de auditoría ni a otras bases de datos, limitando el impacto de un compromiso del servidor web.

---

### 7.5 Verificación de conectividad entre zonas internas

**Objetivo:** Comprobar que las reglas de firewall entre zonas internas funcionan según lo diseñado: la DMZ puede consultar MySQL en VLAN20, pero no acceder a la red de gestión ni a otros servicios.

**Prueba 1: Conectividad DMZ → VLAN20 (MySQL)**

```bash
# Desde dmz-server
nc -zv 192.168.20.10 3306
```

**Resultado esperado:** Conexión exitosa.

**Explicación:** La regla `DMZ-OUT: Permitir consultas MySQL del servidor web hacia la base de datos` autoriza este tráfico específico.

**Prueba 2: Conectividad DMZ → VLAN20 (otros puertos)**

```bash
# Desde dmz-server
nc -zv 192.168.20.10 22
nc -zv 192.168.20.10 80
```

**Resultado esperado:** Timeout en ambos.

**Explicación:** Solo el puerto 3306 está autorizado desde la DMZ hacia VLAN20. Cualquier otro tráfico es bloqueado por la regla por defecto.

**Prueba 3: Conectividad DMZ → VLAN10 (gestión)**

```bash
# Desde dmz-server
curl --connect-timeout 5 https://192.168.10.1
```

**Resultado esperado:** Timeout.

**Explicación:** La regla `DMZ-BLOCK: Bloquear y registrar tráfico desde DMZ hacia red de gestión` impide explícitamente esta comunicación. Si un atacante compromete el servidor web, no puede saltar a la consola de administración del firewall.

---

### 7.6 Verificación de salida a internet controlada por OPNsense

**Objetivo:** Confirmar que `dmz-server` y `vlan20-server` acceden a internet exclusivamente a través de OPNsense, sin usar la NAT de Vagrant.

**Prueba 1: Ruta por defecto en `dmz-server`**

```bash
# Desde dmz-server
ip route show default
```

**Resultado esperado:** `default via 172.16.0.1 dev enp0s8`

**Explicación:** La ruta por defecto apunta al gateway de la DMZ (OPNsense), no a `10.0.2.2` (NAT de VirtualBox). El script de provisionamiento eliminó la ruta de Vagrant y configuró esta como principal.

**Prueba 2: Salida a internet desde `dmz-server`**

```bash
# Desde dmz-server
curl -s ifconfig.me && echo
```

**Resultado esperado:** IP pública de la interfaz WAN de OPNsense (en el caso del lab sería la IP pública del host).

**Explicación:** El tráfico sale por la interfaz WAN de OPNsense y NATea hacia internet. La IP pública visible es la misma que OPNsense expone hacia el exterior.

**Prueba 3: Traceroute desde `dmz-server`**

```bash
traceroute -n 8.8.8.8
```

**Resultado esperado:** El primer salto es `172.16.0.1`.

**Explicación:** El camino hacia internet pasa obligatoriamente por OPNsense, que actúa como router y firewall.

**Prueba 4: Ruta por defecto en `vlan20-server`**

```bash
# Desde vlan20-server
ip route show default
```

**Resultado esperado:** `default via 192.168.20.1 dev enp0s8`

**Explicación:** Mismo principio que en la DMZ, pero usando el gateway de la VLAN20.

**Prueba 5: Salida a internet desde `vlan20-server`**

```bash
# Desde vlan20-server
curl -s ifconfig.me && echo
```

**Resultado esperado:** IP pública de OPNsense (realmente es la IP pública del host anfitrión).

**Explicación:** Todo el tráfico de la organización sale por el mismo punto, facilitando la monitorización y el control.

**Prueba 6: `external-kali` sin VPN mantiene su propia salida**

```bash
# Desde external-kali con todas las VPNs desactivadas
curl -s ifconfig.me && echo
```

**Resultado esperado:** IP pública de la NAT de Vagrant (diferente a la de OPNsense).

**Explicación:** `external-kali` conserva su interfaz NAT (`eth0`) como ruta por defecto gracias a `never-default` en `eth1`. Esto le permite salir directamente a internet sin pasar por OPNsense, simulando un atacante externo real con su propia conectividad.