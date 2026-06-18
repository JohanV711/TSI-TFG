# 3-secure-network-lab — Guía práctica de arquitectura de red segura

Laboratorio práctico de ciberseguridad que reproduce una arquitectura de red corporativa segmentada y securizada, desplegada automáticamente con Vagrant + VirtualBox y gobernada por OPNsense como firewall central.  

## Objetivos del bloque

- Implementar una topología de red segmentada en cuatro zonas (WAN, DMZ, VLAN10‑Gestión, VLAN20‑Servidores) con políticas de filtrado por defecto denegatorias.
- Desplegar túneles WireGuard con dos perfiles de privilegio (administradores y usuarios) y verificar el control de acceso a cada segmento.
- Aplicar DNS forzado con filtrado de dominios y cifrado de las consultas salientes mediante DNS over TLS.
- Detectar patrones de ataque con Suricata IDS y garantizar la trazabilidad de eventos mediante logs alineados con el ENS.

## Tecnologías utilizadas

| Componente       | Tecnología                          |
|------------------|-------------------------------------|
| Hipervisor       | VirtualBox 6.1+                     |
| Orquestación     | Vagrant 2.3+                        |
| Firewall / IDS   | OPNsense 25.1 + Suricata            |
| VPN              | WireGuard (wg‑admins / wg‑users)    |
| DNS interno      | Unbound (DNS over TLS, filtrado)    |
| Servidor web     | Nginx + Flask (Python)              |
| Base de datos    | MariaDB 10.6                        |
| Atacante         | Kali Linux (external‑kali + noVNC) |

## ¿Qué contiene el bloque 3?
- configs: contiene
- docs:
- images: 
- scripts:
- Vagrantfile: 


## Índice

1. [Introducción y contexto](docs/01-introduccion-contexto.md)
2. [Topología y arquitectura de red](docs/02-topologia-red.md)
3. [Requisitos previos](docs/03-requisitos-previos.md)
4. [Despliegue del laboratorio](docs/04-despliegue-lab.md)
5. [Diferencias respecto a un entorno real](docs/05-diferencias-entorno-real.md)
6. [Acceso a las máquinas y servicios](docs/06-acceso-servicios.md)
7. [Pruebas de verificación funcional](docs/07-pruebas-funcionales.md)
8. [Control de tráfico por OPNsense](docs/08-control-trafico-firewall.md)
9. [VPN WireGuard — comportamiento y verificación](docs/09-vpn-wireguard.md)
10. [DNS — control y privacidad](docs/10-dns-control-privacidad.md)
11. [Detección de intrusiones con Suricata](docs/11-suricata-deteccion.md)
12. [Logs y trazabilidad ENS](docs/12-logs-trazabilidad-ens.md)
13. [Conclusiones](docs/13-conclusiones.md)