## 4. Despliegue del laboratorio

### 4.1 Clonar el repositorio

El laboratorio se distribuye como parte del repositorio del TFG. El primer paso es clonar el código en la máquina anfitriona:

```bash
git clone https://github.com/JohanV711/TSI-TFG.git
cd TSI-TFG/3-secure-network-lab
```

Dentro de este directorio se encuentran:

- `Vagrantfile` — definición de las máquinas virtuales y sus redes.
- `scripts/` — provisionadores de cada MV.
- `README.md` — esta misma guía.

No se requiere ninguna configuración adicional antes del despliegue. Vagrant descargará automáticamente las boxes necesarias (`snl-opensense/snl-opensense`, `kalilinux/rolling` y `ubuntu/jammy64`) en el primer `vagrant up`.

### 4.2 Levantar las máquinas virtuales

El laboratorio puede levantarse completo o por partes. El comando principal es:

```bash
vagrant up
```

Este comando crea y provisiona las cuatro MV en paralelo, respetando las dependencias de red definidas en el `Vagrantfile`. El proceso completo puede tardar entre 15 y 30 minutos dependiendo de la velocidad de conexión y del hardware del anfitrión.

Si se desea levantar una MV concreta:

```bash
vagrant up opensense
vagrant up dmz-server
vagrant up vlan20-server
vagrant up external-kali
```

**Nota importante:** la primera vez que se ejecuta `vagrant up` para una MV, Vagrant ejecutará el script de provisionamiento correspondiente (`setup.sh` y, en el caso de `external-kali`, también `gui.sh`). Esto configura automáticamente interfaces, rutas, servicios y credenciales. No es necesario ejecutar nada manualmente dentro de las MV para la configuración base.

### 4.3 Orden de arranque recomendado

Aunque Vagrant es capaz de levantar todas las MV en paralelo, se recomienda el siguiente orden para garantizar que los servicios dependientes estén disponibles al finalizar el provisionamiento:

- `opensense` — el firewall debe estar operativo antes que el resto, ya que actúa como gateway y servidor DNS para las demás MV.
- `dmz-server` y `vlan20-server` — estos dos servidores pueden levantarse en cualquier orden una vez que OPNsense está listo. La conexión entre ellos (MariaDB) se establece en el provisionamiento, pero no depende de un orden estricto.
- `external-kali` — la máquina atacante se puede levantar en cualquier momento, pero conviene hacerlo al final para que los servidores internos ya estén totalmente configurados antes de lanzar las pruebas de conectividad.

En la práctica, un simple `vagrant up` lanza las cuatro MV y, aunque los tiempos de provisionamiento pueden solaparse, el resultado final es consistente gracias a las comprobaciones incluidas en los scripts (espera activa de MySQL, reintentos de conexión, etc.).

Para reconstruir una MV desde cero (por ejemplo, si se desea volver al estado inicial de las pruebas):

```bash
vagrant destroy <nombre_mv>
vagrant up <nombre_mv>
```

### 4.4 Verificación inicial de que todo está en pie

Una vez finalizado el provisionamiento, conviene realizar unas comprobaciones rápidas para confirmar que las MV están ejecutándose y los servicios básicos arrancados. 

**Paso 1: Estado de las máquinas virtuales**

```bash
vagrant status
```

Debe mostrar `running` para las cuatro MV.

**Paso 2: Verificar que los servicios escuchan localmente en cada servidor**

Conectarse a `dmz-server` y comprobar que Nginx está activo:

```bash
vagrant ssh dmz-server
systemctl status nginx
curl -s http://127.0.0.1 | head -5
exit
```

Conectarse a `vlan20-server` y comprobar que MariaDB está activo y escucha en su IP interna:

```bash
vagrant ssh vlan20-server
sudo systemctl status mysql
sudo ss -tlnp | grep 3306
```

Debe mostrar `192.168.20.10:3306`, no `127.0.0.1`.

```bash
exit
```

**Paso 3: Escritorio virtual de `external-kali`**

Abrir en el navegador del anfitrión: [http://localhost:8081/vnc.html](http://localhost:8081/vnc.html)

La contraseña VNC por defecto es `vagrant`. Debe aparecer el escritorio XFCE de Kali Linux. Este acceso gráfico confirma que `external-kali` está completamente operativa. También la contraseña de kali-linux para entrar en el entorno virtual es `vagrant`. 

**Paso 4: Interfaces de red esperadas**

Dentro de `external-kali` (vía SSH o terminal VNC), verificar que las interfaces están configuradas:

```bash
ip a | grep -E "eth0|eth1"
```

- `eth0`: NAT propia (`10.0.2.15`).
- `eth1`: red WAN del lab (`91.168.50.10`).

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="03-requisitos-previos.md">← Anterior</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <a href="../README.md">Volver al índice</a>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <a href="05-diferencias-entorno-real.md">Siguiente →</a>
    </td>
  </tr>
</table>