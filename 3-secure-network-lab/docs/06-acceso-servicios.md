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
**Usuario**:
```bash
root
```
**Contraseña**:
```bash
Contraseniarobustademinimo16caracteres!.
```

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

