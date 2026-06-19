# 1. Introducción y objetivos

## Propósito del laboratorio

El **Bloque 4 — Insecure Network Lab** constituye la contraparte del bloque 3, que demostraba cómo una arquitectura de red correctamente securizada (firewall con políticas restrictivas, segmentación, VPN, IDS y DNS filtrado) protege los activos corporativos, este laboratorio **reproduce intencionadamente las malas prácticas de configuración más habituales** que se pueden encontrar en entornos profesionales con el fin de mostrar lo que no se debería hacer.

Se trata de un entorno aislado, automatizado con **Vagrant + VirtualBox**, en el que cuatro máquinas virtuales simulan una organización con:

- Un firewall que enruta tráfico pero **no aplica ningún filtrado real**.
- Una DMZ con servicios públicos vulnerables (HTTP inseguro, FTP anónimo, Telnet, phishing).
- Una red interna que almacena datos sensibles y está **totalmente expuesta** debido a la ausencia de segmentación efectiva.

Sobre esta infraestructura, una máquina atacante con Kali Linux ejecuta paso a paso los mismos ataques descritos en la memoria, evidenciando cómo cada mala práctica habilita el siguiente escalón del compromiso.

## Objetivos de aprendizaje

Los objetivos de este laboratorio son:

- Identificar **malas prácticas reales** en firewalls, servidores web, FTP, Telnet, SSH, MySQL y Samba.
- Ejecutar **escaneos de red y enumeración de servicios** con `nmap` y `enum4linux`.
- **Acceder a servicios desprotegidos** (HTTP con directory listing, FTP anónimo, Telnet sin cifrado, MySQL sin contraseña, Samba como invitado).
- Realizar **ARP spoofing** y capturar credenciales en tráfico no cifrado.
- **Pivotar desde la DMZ a la red interna** aprovechando la falta de filtrado del firewall y credenciales reutilizadas.
- **Exfiltrar información sensible** (bases de datos, archivos compartidos) sin activar ningún mecanismo de detección.
- Contrastar cada ataque con la **práctica correcta** que lo habría prevenido, comprendiendo así el valor de las medidas aplicadas en el Bloque 3.

## Metodología

El laboratorio sigue una estrategia de **aprender atacando** (ethical hacking) en un entorno controlado:

- Se parte de una **red completamente desplegada y configurada con las vulnerabilidades activas**.
- Desde la máquina atacante (`external-kali`) se ejecutan **comandos reales de reconocimiento, explotación y post‑explotación**.
- Cada acción exitosa se relaciona directamente con una o varias malas prácticas documentadas.
- El lector puede repetir los escenarios, modificar parámetros y observar el tráfico de red con Wireshark o tcpdump para comprender los protocolos implicados.

Todos los escenarios son autocontenidos y no requieren conectividad a Internet (salvo para la descarga inicial de las boxes de Vagrant).

## Diferencias con el Bloque 3 (red segura)

| Aspecto                  | Bloque 3 (Seguro)                          | Bloque 4 (Inseguro)                          |
|--------------------------|---------------------------------------------|----------------------------------------------|
| **Firewall**             | OPNsense con reglas restrictivas, NAT, logs | Ubuntu + iptables con políticas ACCEPT y sin filtrado real |
| **Segmentación**         | 4 zonas aisladas (WAN, DMZ, VLANs internas) | 3 segmentos conectados sin restricción       |
| **Inspección de tráfico**| Suricata IDS activo, reglas actualizadas    | Sin IDS, sin logging                         |
| **Acceso remoto**        | VPN WireGuard con perfiles diferenciados    | Telnet y SSH con credenciales débiles y sin control |
| **Servicios internos**   | MySQL y Samba con autenticación robusta     | MySQL sin contraseña, Samba como invitado    |
| **Servicios públicos**   | Nginx con cabeceras de seguridad            | Apache con `ServerTokens Full`, directory listing, panel admin sin autenticación |
| **Cifrado**              | DNS over TLS, tráfico VPN cifrado           | Telnet, FTP y HTTP sin cifrado               |
| **Resultado**            | Red resistente a los ataques del capítulo 7 | Red totalmente comprometida en todos los niveles |

## Estructura del laboratorio

El laboratorio se compone de cuatro máquinas virtuales interconectadas mediante redes internas de VirtualBox (`intnet`). La siguiente documentación detalla:

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="../README.md">← Volver al índice</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <span style="color: #666;">·</span>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <a href="02-topologia-maquinas.md">Siguiente →</a>
    </td>
  </tr>
</table>