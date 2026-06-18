# 4-insecure-network-lab — Laboratorio de red corporativa insegura

Laboratorio práctico de ciberseguridad que reproduce una arquitectura de red corporativa con **malas prácticas de configuración reales**, desplegada automáticamente con Vagrant + VirtualBox.  
El objetivo es ejecutar y comprender los ataques descritos en el capítulo 7 de la memoria, observando en un entorno controlado las consecuencias de cada error de seguridad.

> **!** Uso exclusivamente educativo en entornos aislados. No conectar a redes de producción.

## Objetivos del bloque

- Simular una topología segmentada (externa, DMZ, interna) gobernada por un firewall que **no filtra ni registra tráfico**.
- Exponer deliberadamente servicios vulnerables (HTTP inseguro, FTP anónimo, Telnet, MySQL sin contraseña, Samba invitado, SSH débil).
- Demostrar ataques reales: reconocimiento, compromiso de la DMZ, pivoting a la red interna, ARP spoofing, captura de credenciales y exfiltración de datos.
- Documentar cada mala práctica, su configuración exacta y la consecuencia directa que habilita el ataque.

## Tecnologías utilizadas

| Componente       | Tecnología                          |
|------------------|-------------------------------------|
| Hipervisor       | VirtualBox 6.1+                     |
| Orquestación     | Vagrant 2.3+                        |
| Firewall         | Ubuntu Server + iptables (sin filtrado real) |
| Atacante         | Kali Linux + XFCE + noVNC           |
| Servidor DMZ     | Ubuntu Server + Apache, vsftpd, Telnet, SSH |
| Servidor interno | Ubuntu Server + MySQL, Samba, SSH   |

## ¿Qué contiene el bloque 4?

- **Vagrantfile** que levanta cuatro VMs interconectadas.
- **scripts/** de aprovisionamiento con todas las configuraciones inseguras.
- **docs/** con la documentación técnica completa del laboratorio.
- **images/** con capturas de pantalla de la topología y los ataques.

## Índice

1. [Introducción y objetivos](docs/01-introduccion-objetivos.md)
2. [Topología y máquinas virtuales](docs/02-topologia-maquinas.md)
3. [Despliegue y acceso](docs/03-despliegue-acceso.md)
4. [Malas prácticas implementadas](docs/04-malas-practicas.md)
5. [Escenarios de ataque](docs/05-escenarios-ataque.md)
6. [Solución de problemas](docs/06-solucion-problemas.md)
7. [Conclusiones](docs/07-conclusiones.md)
8. [Advertencia legal](docs/08-advertencia-legal.md)