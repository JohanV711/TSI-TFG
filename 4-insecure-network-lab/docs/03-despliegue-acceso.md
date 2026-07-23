# 3. Despliegue y acceso

## Requisitos previos

Para ejecutar el laboratorio se necesita un equipo (físico o servidor remoto) con los siguientes componentes:

| Requisito | Mínimo | Recomendado |
|-----------|--------|-------------|
| **VirtualBox** | 6.1 | 7.0 o superior |
| **Vagrant** | 2.3 | 2.4 o superior |
| **RAM libre** | 6 GB libres | 8 GB libres |
| **Espacio en disco** | 25 GB libres | 35 GB libres |
| **Conexión a Internet** | Solo durante el primer `vagrant up` | — |

## Despliegue

Los comandos se ejecutan desde el directorio raíz del laboratorio (`4-insecure-network-lab/`). El `Vagrantfile` orquesta las cuatro máquinas virtuales y ejecuta automáticamente todos los scripts de aprovisionamiento que instalan los paquetes y aplican las configuraciones inseguras.

### Primer despliegue

```bash
# Acceder al directorio del laboratorio
cd 4-insecure-network-lab/

# Levantar todas las máquinas (el orden lo gestiona Vagrant)
vagrant up
```
O desde la raíz del repositorio
```bash
#En /TSI-TFG/
make bloque4
```

Durante la primera ejecución, Vagrant descarga las boxes desde HashiCorp Cloud si no están ya en caché (aproximadamente 1.5 GB en total) y ejecuta los provisioners de cada VM. El tiempo estimado es de 15 a 30 minutos, en función de la velocidad de la conexión y del rendimiento del disco.

### Despliegues posteriores

Una vez que las boxes están descargadas y las VMs creadas, los inicios sucesivos tardan entre 2 y 5 minutos:

```bash
vagrant up
```

### Levantar una máquina concreta

Si solo se necesita una VM (por ejemplo, para regenerar la Kali o repetir un ataque):

```bash
vagrant up external-kali
vagrant up internal-server
```

### Estado de las máquinas

```bash
vagrant status
```

Muestra el estado actual (`running`, `poweroff`, `not created`) de cada VM.

### Detener el laboratorio

```bash
vagrant halt          # Apaga todas las VMs conservando los cambios
vagrant destroy -f    # Elimina completamente las VMs (los datos se pierden)
```

## Acceso a las máquinas

### Acceso SSH

Todas las máquinas permiten acceso SSH mediante el usuario `vagrant` (sin contraseña, usando la clave privada de Vagrant):

```bash
vagrant ssh external-kali
vagrant ssh firewall
vagrant ssh dmz-server
vagrant ssh internal-server
```

Para las máquinas Ubuntu, las credenciales inseguras adicionales (`root:root`, `ftpoperator:ftpoperator`) están activas y pueden usarse desde cualquier otra VM del laboratorio, pero no a través del reenvío de puertos de VirtualBox.

### Acceso al escritorio gráfico de Kali

`external-kali` incluye un entorno de escritorio XFCE ligero accesible mediante noVNC desde cualquier navegador, exactamente igual que en el Bloque 3.

### Puertos y redirección

La VM levanta `x11vnc` en el puerto `5900` y noVNC (`websockify`) en el puerto `8082`.

El `Vagrantfile` redirige el puerto `8082` de la VM al puerto `8082` del host mediante `forwarded_port`.

Por tanto, la URL de acceso es:

```text
http://localhost:8082/vnc.html
```
Con la contraseña para noVNC y kali-linux:

```text
vagrant
```
### Verificación del servicio gráfico

Para comprobar que el entorno está activo, se puede entrar por SSH a la Kali y ejecutar:

```bash
vagrant ssh external-kali
sudo systemctl status lightdm x11vnc novnc
```

Si alguno no estuviera corriendo, se pueden reiniciar con:

```bash
sudo systemctl restart lightdm
sleep 5
sudo systemctl restart x11vnc
sudo systemctl restart novnc
```

Una vez abierto el escritorio, el usuario encontrará Firefox, una terminal y las herramientas de ataque preinstaladas listas para ejecutar los escenarios del documento 5.

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="02-topologia-maquinas.md">← Anterior</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <a href="../README.md">Volver al índice</a>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <a href="04-malas-practicas.md">Siguiente →</a>
    </td>
  </tr>
</table>
