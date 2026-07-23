# 2. Topología y máquinas virtuales

## Diagrama de red

*(`4-insecure-network-lab/images/diagrama-bloque-4.drawio.png`)*

La figura representa los tres segmentos de red del laboratorio, la máquina atacante externa y las dos zonas corporativas (DMZ e interna), todas interconectadas a través de un firewall que **no aplica ningún filtrado real**.

## Redes definidas

| Red | Nombre en VirtualBox | Rango | Descripción |
|------|----------------------|-------|-------------|
| Externa | `net-externa` | `100.70.9.0/24` | Red del atacante. Simula Internet o una red externa sin control. |
| DMZ | `net-dmz` | `192.168.57.0/24` | Zona desmilitarizada expuesta a la red externa. Contiene servicios públicos vulnerables. |
| Interna | `net-interna` | `192.168.58.0/24` | Red corporativa con datos sensibles (MySQL, Samba). No debería ser accesible directamente, pero lo es. |

Las tres redes son de tipo **red interna de VirtualBox (`intnet`)** y no tienen salida a Internet durante las prácticas. La única conectividad externa se produce a través de la interfaz NAT de Vagrant, usada exclusivamente durante el aprovisionamiento inicial para descargar paquetes.

## Máquinas virtuales

| VM | Box | IP | Red | RAM | vCPUs | Rol |
|------|------|------|------|------|------|------|
| `external-kali` | `kalilinux/rolling` | `100.70.9.10` | `net-externa` | 2560 MB | 2 | Atacante externo con escritorio gráfico XFCE |
| `firewall` | `ubuntu/jammy64` | `100.70.9.1` / `192.168.57.1` / `192.168.58.1` | Todas | 512 MB | 1 | Firewall vulnerable (router sin filtrado) |
| `dmz-server` | `ubuntu/jammy64` | `192.168.57.10` | `net-dmz` | 512 MB | 1 | Apache + vsftpd + Telnet + SSH + phishing |
| `internal-server` | `ubuntu/jammy64` | `192.168.58.10` | `net-interna` | 1024 MB | 1 | MySQL + Samba + SSH con datos sensibles |

Todas las máquinas, salvo `external-kali`, usan **Ubuntu Server 22.04 LTS** como sistema base. La atacante se basa en la box oficial de **Kali Linux Rolling**, lo que garantiza que las herramientas de ataque están actualizadas.

## Conectividad entre segmentos

La tabla siguiente resume qué tráfico está permitido según las reglas del firewall. Aunque la política por defecto de `FORWARD` es `DROP`, se han añadido reglas explícitas que habilitan **todo el tráfico entre cualquier par de interfaces**, anulando cualquier posible filtrado.

| Origen | Destino | Permitido | Justificación (mala práctica) |
|--------|---------|-----------|-------------------------------|
| `net-externa` (atacante) | `net-dmz` (DMZ) | Sí | Regla explícita ACCEPT en el firewall |
| `net-externa` (atacante) | `net-interna` (interna) | Sí | Regla explícita ACCEPT — el atacante salta la DMZ |
| `net-dmz` (DMZ) | `net-interna` (interna) | Sí | Regla explícita ACCEPT — la DMZ ve la red corporativa |
| Cualquiera | Internet real | No | El laboratorio no tiene salida a Internet |

El tráfico de retorno también está permitido mediante la regla `ESTABLISHED,RELATED`. En la práctica, el firewall se comporta como un **router puro** sin capacidad de inspección, segmentación ni registro.

### Consecuencias de esta conectividad

- Un atacante en la red externa puede alcanzar **directamente** tanto la DMZ como la red interna, sin necesidad de pivoting previo.
- Una vez comprometida la DMZ, el acceso a la red interna es inmediato gracias a las rutas estáticas configuradas en los servidores.
- No existe ningún mecanismo de detección (ni IDS ni logs de firewall) que alerte sobre el tráfico malicioso.

## Interfaces de red en el firewall

El `firewall` dispone de **tres interfaces de red internas** (además de la NAT de gestión), cada una conectada a un segmento:

| Interfaz (SO) | IP | Segmento | Orden en Vagrant |
|---------------|----|----------|------------------|
| `eth1` | `100.70.9.1/24` | `net-externa` | Primera `private_network` |
| `eth2` | `192.168.57.1/24` | `net-dmz` | Segunda `private_network` |
| `eth3` | `192.168.58.1/24` | `net-interna` | Tercera `private_network` |

El orden es determinista porque se ha forzado el tipo de adaptador de red (`nic_type: "82540EM"`) en el `Vagrantfile`, garantizando que los scripts de aprovisionamiento detectan correctamente cada interfaz mediante su dirección IP y no por su nombre.

## Direccionamiento IP y rutas

Las máquinas no utilizan DHCP en las redes del laboratorio, sino **direccionamiento estático** configurado mediante `netplan` o `nmcli` (en Kali). Cada servidor conoce las rutas hacia los otros segmentos a través del firewall:

- **DMZ server:** rutas hacia `192.168.58.0/24` y `100.70.9.0/24` vía `192.168.57.1`.
- **Internal server:** rutas hacia `192.168.57.0/24` y `100.70.9.0/24` vía `192.168.58.1`.
- **Kali:** rutas hacia `192.168.57.0/24` y `192.168.58.0/24` vía `100.70.9.1`.

Esta configuración de rutas, combinada con la ausencia de filtrado, permite que cualquier máquina pueda alcanzar a cualquier otra directamente, sin restricciones.

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="01-introduccion-objetivos.md">← Anterior</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <a href="../README.md">Volver al índice</a>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <a href="03-despliegue-acceso.md">Siguiente →</a>
    </td>
  </tr>
</table>
