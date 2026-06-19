## 9. VPN WireGuard — comportamiento y verificación

### 9.1 Estado de los túneles y handshake

Una vez activado un túnel, es imprescindible confirmar que el enlace cifrado se ha establecido y que el tráfico está fluyendo. El comando `wg show` proporciona toda la información relevante.

**Verificación del túnel de administradores:**

```bash
sudo wg show wg-admins
```

**Salida típica esperada:**

```text
interface: wg-admins
  public key: <clave_pública_del_cliente> (Ipk4RQjbrZZLMlp44vzT98+LD33CLZwSJ8dcSHdDyFI=)
  private key: (hidden)
  listening port: <puerto_aleatorio>
  fwmark: 0xca6c

peer: tlzDt6npntn7E2TX7MajuUHkNkIAAy8/LoVp/kYJzBo=
  endpoint: 91.168.50.1:51820
  allowed ips: 0.0.0.0/0
  latest handshake: 14 seconds ago
  transfer: 1.23 KiB received, 2.45 KiB sent
  persistent keepalive: every 25 seconds
```

**Campos clave:**

- `latest handshake`: debe mostrar un valor inferior a 2 minutos. Si está ausente o lleva mucho tiempo, el túnel no se ha negociado correctamente. El keepalive cada 25 segundos fuerza el handshake periódico.
- `transfer`: bytes recibidos y enviados > 0. Si ambos son cero, no se ha cursado tráfico real a través del túnel.
- `endpoint`: la IP y puerto del servidor WireGuard en OPNsense (`91.168.50.1:51820` para admins, `:51821` para users).

**Problemas frecuentes y su diagnóstico:**

- Si no hay handshake, comprobar que la MV `external-kali` tiene conectividad con `91.168.50.1` y que el firewall permite UDP en los puertos correspondientes.
- Si el handshake se produce pero `transfer` se mantiene en cero, es posible que el tráfico no esté usando el túnel. Con `AllowedIPs = 0.0.0.0/0`, `wg-quick` añade automáticamente las reglas de enrutamiento necesarias; verificar con `ip rule show`.
- Se recomienda capturar esta salida como evidencia de túnel operativo.

![Salida de `sudo wg show wg-admins`](../images/image5.png)

*Figura 6: Salida de `wg show wg-admins`. Se observa el handshake reciente, la clave pública del peer y los bytes transferidos, confirmando que el túnel está activo y cursando tráfico.*

---

### 9.2 Verificación de cifrado del tráfico en tránsito

WireGuard encapsula todo el tráfico dentro de paquetes UDP cifrados con **ChaCha20** y **Poly1305**. Para comprobar que los datos viajan protegidos por la red, se puede realizar una captura en la interfaz WAN del laboratorio y compararla con una captura en la interfaz virtual del túnel.

**Captura en `external-kali` durante una petición web a través de la VPN:**

```bash
# Terminal 1: activar VPN y generar tráfico
sudo wg-quick up wg-admins
curl http://172.16.0.10

# Terminal 2 (simultáneamente dentro de external-kali pero en otra terminal): capturar en la interfaz que da a la WAN (eth1)
sudo tcpdump -i eth1 -n udp port 51820
```

**Salida esperada en `eth1`:**

```text
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
11:22:33.456789 IP 91.168.50.10.54321 > 91.168.50.1.51820: UDP, length 96
11:22:33.457012 IP 91.168.50.1.51820 > 91.168.50.10.54321: UDP, length 96
...
```

Solo se ven datagramas UDP entre los endpoints del túnel. No aparece ningún paquete HTTP, TCP o DNS en claro. Cada datagrama contiene datos cifrados; su contenido no es legible sin las claves.

**Captura en la interfaz virtual del túnel:**

```bash
# Capturar en la interfaz wg-admins para ver el tráfico ya descifrado
sudo tcpdump -i wg-admins -n tcp port 80
```

Mientras se ejecuta `curl http://172.16.0.10`, se observan paquetes TCP hacia `172.16.0.10.80` perfectamente legibles.

**Explicación:** Esta diferencia no es una contradicción, sino el comportamiento normal de WireGuard. La interfaz `wg-admins` es una interfaz de red virtual que el kernel expone una vez que el tráfico ya ha sido descifrado. Por tanto, dentro de la propia máquina `external-kali` se puede ver el contenido en texto plano, de la misma forma que se vería el tráfico de cualquier interfaz física. Sin embargo, en la captura del segmento WAN (`eth1`) solo se observan datagramas UDP indescifrables. Esto confirma que la comunicación es confidencial e íntegra en el segmento no confiable (la red WAN del laboratorio), cumpliendo con la medida de protección de las comunicaciones del ENS.

---

### 9.3 Diferencia de permisos entre `wg-admins` y `wg-users`

Los dos perfiles de VPN no solo usan claves diferentes, sino que OPNsense les asigna políticas de firewall completamente distintas. La tabla siguiente resume las diferencias verificadas durante las pruebas:

| Acceso | `wg-admins` | `wg-users` | Notas |
|--------|:-----------:|:----------:|-------|
| Portal web DMZ (`172.16.0.10:80`) | ✔ | ✔ | |
| SSH a `dmz-server` (`172.16.0.10:22`) | ✔ (firewall) | ✘ | Requiere clave SSH privada (no contraseña). |
| SSH a `vlan20-server` (`192.168.20.10:22`) | ✔ (firewall) | ✘ | Similar al anterior. |
| MySQL desde el cliente VPN a `vlan20-server` (`3306`) | ✔ (firewall) / ✘ (MariaDB) | ✘ (firewall) | MariaDB rechaza autenticación desde IP no autorizada (error 1130). |
| WebUI OPNsense (`https://192.168.10.1`) | ✔ | ✘ | |
| Salida a Internet | ✔ | ✔ | |
| DNS forzado por OPNsense | ✔ | ✔ | |
| Bloqueo de dominios (Instagram, Facebook) | ✔ | ✔ | |


**Explicación técnica:**

- La regla `VPN_ADMINS → RED_SERVIDORES` permite todo el tráfico hacia VLAN20, mientras que `wg-users` solo tiene una regla específica hacia el puerto 80 de la DMZ.
- **La capa adicional de autenticación en MariaDB** (`webuser@'172.16.0.10'`) **impide** que incluso los administradores de VPN consulten directamente la base de datos sin conectarse antes al servidor DMZ. Esta defensa en profundidad garantiza que un compromiso de las credenciales de VPN no otorgue acceso inmediato a los datos sensibles.
- Estas diferencias se pueden verificar repitiendo las pruebas de la sección 7.2 (`wg-users`) y 7.3 (`wg-admins`).

---

### 9.4 Comportamiento del full-tunnel con `AllowedIPs = 0.0.0.0/0`

Ambos perfiles de WireGuard utilizan `AllowedIPs = 0.0.0.0/0` en el lado del cliente, lo que instruye a `wg-quick` a redirigir todo el tráfico del sistema a través del túnel. Esta configuración se conoce como túnel completo (full-tunnel).

**Cómo funciona técnicamente:**

`wg-quick` no modifica la tabla de enrutamiento principal del sistema. En su lugar, crea una tabla de enrutamiento separada y añade reglas de política de enrutamiento (policy routing) para dirigir el tráfico hacia ella. La verificación correcta se realiza con:

```bash
ip rule show
```

**Salida esperada con VPN activa:**

```text
0:      from all lookup local
32764:  from all lookup main suppress_prefixlength 0
32765:  not from all fwmark 0xca6c lookup 51820
```

- **Regla 32764:** busca en la tabla `main`, pero suprime las rutas con prefijo 0 (la ruta por defecto). De esta forma, las rutas específicas (como la de la red local) se siguen usando desde la tabla principal.
- **Regla 32765:** todo el tráfico que **no** tenga la marca de firewall `0xca6c` (el tráfico que no viene del propio túnel) se enruta usando la tabla `51820`. Esta tabla contiene la ruta `0.0.0.0/0` que envía todo hacia la interfaz virtual `wg-admins`.

---

**Verificación adicional sin VPN:**

```bash
# Desactivar cualquier VPN
sudo wg-quick down wg-admins 2>/dev/null
sudo wg-quick down wg-users 2>/dev/null

# Verificar la ruta por defecto
ip route show default
# Debe mostrar: default via 10.0.2.2 dev eth0
```

---

**Efectos del túnel completo:**

- **Con VPN activa:** todo el tráfico de `external-kali` (web, DNS, etc.) se encapsula y se envía a OPNsense, que aplica sus políticas antes de enviarlo a Internet.
- **Con VPN desactivada:** `external-kali` sale directamente a Internet por su propia NAT (`eth0`), sin pasar por OPNsense. Las políticas de filtrado, DNS forzado y Suricata no se aplican.

---

**Evidencia complementaria de que el túnel está cursando el tráfico:**

- **Bloqueo DNS solo con VPN:** `nslookup instagram.com 8.8.8.8` devuelve `0.0.0.0` con la VPN activa (porque OPNsense fuerza Unbound) y la IP real de Instagram con la VPN desactivada.
- **`sudo wg show`:** muestra `transfer` con bytes recibidos y enviados > 0, confirmando que el túnel transporta datos.

**Implicaciones de seguridad:**

- El modelo full-tunnel garantiza que incluso el tráfico hacia Internet desde el dispositivo del empleado o administrador esté sujeto a las mismas políticas de filtrado y monitorización que si estuviera físicamente en la oficina. 
- Para el laboratorio, permite verificar fácilmente que el DNS forzado, el filtrado de dominios y Suricata se aplican al tráfico del cliente VPN, lo que se comprueba en las secciones 10 y 11.
- Precaución en producción: esta configuración enruta todo el tráfico del cliente hacia la organización, lo que puede generar problemas de rendimiento y consumo de ancho de banda si no se dimensiona adecuadamente. Suele combinarse con una política de split-tunneling para tráfico no sensible, pero aquí se ha empleado full-tunnel por simplicidad y para maximizar el control durante las prácticas.

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="08-control-trafico-firewall.md">← Anterior</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <a href="../README.md">Volver al índice</a>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <a href="10-dns-control-privacidad.md">Siguiente →</a>
    </td>
  </tr>
</table>