# 6. Solución de problemas

Este documento recoge las incidencias más habituales durante el despliegue y uso del laboratorio, junto con su diagnóstico y solución.

---

## 6.1 Error: "The box failed to unpackage improperly... No space left on device"

**Causa**: el disco del servidor donde se ejecuta Vagrant está lleno o casi lleno.

**Solución**: liberar espacio en el host:

```bash
sudo apt clean
sudo apt autoremove --purge -y
sudo journalctl --vacuum-size=200M
```

Verificar el espacio disponible:

```bash
df -h
```

Asegurar al menos 35 GB libres antes de lanzar `vagrant up`.

---

## 6.2 Error: "Could not resolve host: vagrantcloud.com" o timeout al descargar boxes

**Causa**: el servidor no puede resolver los dominios de HashiCorp debido a problemas de DNS del proveedor o de la red.

**Solución temporal** (mientras se lanza el provision):

```bash
sudo nano /etc/hosts
```

Añadir al final:

```text
52.0.5.91 vagrantcloud.com app.vagrantup.com
```

Si el problema persiste, forzar DNS de Cloudflare en el host antes de ejecutar Vagrant:

```bash
sudo systemctl stop systemd-resolved 2>/dev/null || true
sudo rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf
```

---

## 6.3 El script de aprovisionamiento se queda colgado

**Causa más común**: la VM no tiene acceso a Internet a través de la NAT de Vagrant durante la instalación de paquetes.

**Soluciones**:

1. Verificar conectividad NAT desde dentro de la VM:

```bash
vagrant ssh <nombre-vm>
ping 8.8.8.8
```

Si no hay respuesta, revisar que la interfaz NAT (`eth0`) sigue activa y con DHCP.

2. Forzar la resolución DNS dentro de la VM:

Los scripts ya fuerzan `1.1.1.1` al inicio, pero si el problema ocurre antes, se puede añadir manualmente al entrar en la VM:

```bash
sudo rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
sudo apt-get update
```

3. Reintentar el provision de una sola VM:

```bash
vagrant provision <nombre-vm>
```

---

## 6.4 Las VMs no se comunican entre sí

**Síntoma**: los escaneos desde Kali no muestran los servidores o las conexiones entre segmentos fallan.

**Diagnóstico en el firewall**:

```bash
vagrant ssh firewall
cat /proc/sys/net/ipv4/ip_forward
# Debe devolver 1
```

Si devuelve 0, aplicar manualmente:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

Verificar reglas iptables en el firewall:

```bash
sudo iptables -L FORWARD -n -v
```

Deben aparecer las reglas ACCEPT entre las interfaces `eth1`, `eth2` y `eth3`.

Verificar direcciones IP en cada VM:

```bash
ip -br addr
```

Cada máquina debe tener la IP estática asignada en su script de provision. Si una IP no coincide, reejecutar el provision:

```bash
vagrant provision firewall
vagrant provision dmz-server
vagrant provision internal-server
```

---

## 6.5 Error de sintaxis en los scripts (heredocs)

**Síntoma**: fallo durante el provision con mensajes como `unexpected end of file` o `delimiter not found`.

**Causa**: los heredocs (`<< 'EOF'`, `<< 'SQL'`, etc.) requieren que el delimitador de cierre esté **al principio de la línea**, sin espacios ni tabulaciones delante.

**Solución**: revisar el script correspondiente y asegurar que `EOF`, `SQL`, `UNIT`, etc., aparecen exactamente al comienzo de la línea, sin sangría.

---

## 6.6 El escritorio gráfico no carga (noVNC)

**Síntoma**: al abrir `http://localhost:8082/vnc.html` aparece pantalla en blanco, error de conexión o "Failed to connect to server".

**Diagnóstico en `external-kali`**:

```bash
vagrant ssh external-kali

# Verificar que los servicios están corriendo
sudo systemctl status vncserver
sudo systemctl status novnc
```

**Soluciones habituales**:

1. Reiniciar los servicios en orden:

```bash
sudo systemctl restart vncserver
sleep 5
sudo systemctl restart novnc
```

2. Matar procesos VNC previos:

```bash
sudo pkill -9 vnc
sudo pkill -9 websockify
sudo systemctl restart vncserver
sleep 5
sudo systemctl restart novnc
```

3. Verificar que el túnel SSH está activo (si se accede desde un equipo remoto):

El comando `ssh -L 8082:127.0.0.1:8082 ...` debe estar ejecutándose.

Probar con `curl localhost:8082` en el equipo local; debe devolver HTML de noVNC.

4. Verificar que el puerto no está ocupado en el host:

```bash
sudo ss -tlnp | grep 8082
```

Si hay otro proceso usándolo, detenerlo o cambiar el puerto.

5. Si la pantalla VNC se queda en gris o negro, entrar a la VM y comprobar que XFCE arranca correctamente:

```bash
sudo systemctl stop vncserver
sudo -u vagrant vncserver :1 -geometry 1280x800 -depth 24 -localhost no -rfbauth /home/vagrant/.vnc/passwd -xstartup /home/vagrant/.vnc/xstartup
```

Revisar los logs en `/home/vagrant/.vnc/*.log`.

---

## 6.7 Error: "Address already in use" al levantar VNC o noVNC

**Causa**: un proceso anterior de `vncserver` o `websockify` no se cerró correctamente.

**Solución en `external-kali`**:

```bash
# Buscar y matar procesos que ocupen los puertos
sudo fuser -k 5901/tcp
sudo fuser -k 8082/tcp

# Limpiar locks de VNC
sudo rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
sudo rm -rf /home/vagrant/.vnc/*.pid

# Reiniciar servicios
sudo systemctl restart vncserver
sleep 5
sudo systemctl restart novnc
```

---

## 6.8 El firewall detecta las interfaces pero no aplica reglas

**Síntoma**: el provision del `firewall` muestra las interfaces correctamente pero `iptables -L` está vacío después.

**Solución**: reejecutar el provision del firewall:

```bash
vagrant provision firewall
```

Si el problema persiste, entrar a la VM y ejecutar manualmente el script:

```bash
vagrant ssh firewall
sudo /vagrant/scripts/firewall/setup.sh
```

---

## 6.9 Problemas de DNS dentro de las VMs (durante provision)

Los scripts ya fuerzan Cloudflare (`1.1.1.1`) al inicio para prevenir cuelgues. Si aun así alguna VM se queda sin resolución, se puede forzar manualmente dentro de ella:

```bash
sudo rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf
sudo apt-get update
```

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="05-escenarios-ataque.md">← Anterior</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <a href="../README.md">Volver al índice</a>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <a href="07-conclusiones.md">Siguiente →</a>
    </td>
  </tr>
</table>