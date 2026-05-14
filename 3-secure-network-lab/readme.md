# Bloque 3 — Secure Network Lab

Laboratorio de red segura virtualizado con OPNsense como firewall principal, segmentación en DMZ y VLANs, y acceso remoto mediante OpenVPN. Diseñado como contraste positivo del Bloque 4 (Insecure Network Lab), implementando buenas prácticas del Esquema Nacional de Seguridad (ENS).

## Arquitectura

```
[External Kali]─── WAN (91.168.50.0/24) ───[OPNsense Firewall]
                                                 │
                              ┌──────────────────┼──────────────────┐
                              │                  │                  │
                           net-dmz            net-lan           host-only
                        172.16.0.0/24        (trunk)         192.168.56.0/24
                              │                  │                  │
                         [Web Server]     ┌──────┴──────┐      [WebUI mgmt]
                         172.16.0.10   VLAN10        VLAN20
                                     Gestión      Servidores
                                  192.168.10.x   192.168.20.x
                                        │
                                     VLAN30
                                    Invitados
                                  192.168.30.x
```

| Segmento | Red | Propósito |
|---|---|---|
| WAN | 91.168.50.0/24 | Internet simulado |
| DMZ | 172.16.0.0/24 | Servidor web público |
| VLAN10 Gestión | 192.168.10.0/24 | Administración SSH y WebUI |
| VLAN20 Servidores | 192.168.20.0/24 | Backend API + base de datos |
| VLAN30 Invitados | 192.168.30.0/24 | Red aislada sin acceso interno |
| Gestión host-only | 192.168.56.0/24 | Acceso a WebUI durante desarrollo |

## Requisitos del sistema

| Requisito | Mínimo | Recomendado |
|---|---|---|
| RAM | 8 GB | 12 GB |
| CPU | 4 núcleos físicos | 6 núcleos |
| Disco libre | 20 GB | 40 GB |
| Sistema operativo | Windows 10/11, macOS 12+, Ubuntu 20.04+ | — |

> ⚠️ **Nunca uses `sudo vagrant`** en Linux — causa problemas de permisos con VirtualBox.

## Software necesario

- [VirtualBox 7.x](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant 2.4.x](https://developer.hashicorp.com/vagrant/downloads)

**En Linux**, añade tu usuario al grupo vboxusers y reinicia la sesión:
```bash
sudo usermod -aG vboxusers $USER
# Cierra sesión y vuelve a entrar
```

## Instalación

### Paso 1 — Descargar la box de OPNsense

Descarga el archivo `opnsense-25.1-lab.box` desde la página de releases del repositorio:

👉 https://github.com/JohanV711/TSI-TFG/releases/tag/v1.0.0

### Paso 2 — Añadir la box a Vagrant

```bash
vagrant box add snl-opensense/snl-opensense opnsense-25.1-lab.box
```

Esto registra la box localmente. Solo es necesario hacerlo una vez.

### Paso 3 — Clonar el repositorio

```bash
git clone https://github.com/JohanV711/TSI-TFG.git
cd TSI-TFG/3-secure-network-lab
```

### Paso 4 — Levantar el laboratorio

```bash
vagrant up
```

La VM de OPNsense arrancará en 1-2 minutos. Verás algunos warnings de SSH — es normal, OPNsense no usa SSH de Vagrant.

### Paso 5 — Acceder a la WebUI de OPNsense

Abre un túnel SSH en una terminal separada:

**Linux / macOS:**
```bash
ssh -L 8443:192.168.56.10:443 localhost -p 22 -N
```

```bash
ssh -L 8443:192.168.56.10:443 usuario@ip_srvidor_remoto -p 22 -N
```

**Windows (PowerShell):**
```powershell
ssh -L 8443:192.168.56.10:443 localhost -p 22 -N
```

Abre el navegador en: `https://localhost:8443`

| Campo | Valor |
|---|---|
| Usuario | `root` |
| Contraseña | `opnsense` |

> ⚠️ El certificado SSL es autofirmado — acepta la advertencia del navegador.

## Uso del laboratorio

### Comandos básicos

```bash
# Levantar el lab
vagrant up

# Apagar el lab
vagrant halt

# Destruir y recrear desde cero
vagrant destroy -f && vagrant up

# Ver estado de las VMs
vagrant status
```

### Acceso a OPNsense por consola

Si la WebUI no responde, puedes acceder a la consola de OPNsense directamente:

```bash
VBoxManage controlvm snl-opensense screenshotpng /tmp/screen.png
```

Desde el menú de consola puedes:
- Opción 2: Cambiar IP de una interfaz
- Opción 3: Resetear contraseña de root
- Opción 8: Acceder al shell

### Recuperar acceso a la WebUI

Si después de aplicar cambios en OPNsense pierdes acceso a la WebUI, ejecuta:

```bash
~/recover-opnsense.sh
```

O manualmente:

```bash
VBoxManage controlvm snl-opensense keyboardputscancode 1c 9c
sleep 2
VBoxManage controlvm snl-opensense keyboardputstring "8"
VBoxManage controlvm snl-opensense keyboardputscancode 1c 9c
sleep 5
VBoxManage controlvm snl-opensense keyboardputstring "pfctl -d && sysrc pf_enable=NO && route add -net 192.168.56.0/24 -interface em4 && echo OK"
VBoxManage controlvm snl-opensense keyboardputscancode 1c 9c
```

## Credenciales por defecto

| Sistema | Usuario | Contraseña |
|---|---|---|
| OPNsense WebUI | `root` | `opnsense` |
| OPNsense SSH | `root` | `opnsense` |

> 🔒 Cambia estas credenciales si vas a usar el lab en un entorno no controlado.

## Estructura de archivos

```
3-secure-network-lab/
├── Vagrantfile              # Definición de las VMs
├── scripts/
│   └── opnsense/
│       └── opnsense-bootstrap.sh  # Script histórico de construcción de la box
└── readme.md                # Este archivo
```

## Notas técnicas

- La box `snl-opensense/snl-opensense` contiene OPNsense 25.1.12 preinstalado sobre FreeBSD 14.1
- El firewall pf está configurado para permitir acceso a la WebUI desde la interfaz de gestión (em4)
- Las interfaces de red se asignan en este orden: em0 NAT Vagrant, em1 WAN, em2 LAN trunk, em3 DMZ, em4 gestión host-only
- Para acceso remoto mediante OpenVPN, consulta la sección correspondiente de la memoria del TFG