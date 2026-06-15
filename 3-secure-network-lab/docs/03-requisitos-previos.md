## 3. Requisitos previos

### 3.1 Software necesario

El laboratorio se despliega y gestiona completamente desde la máquina anfitriona utilizando las siguientes herramientas:

| Software | Versión mínima | Uso |
|----------|:--------------:|-----|
| [VirtualBox](https://www.virtualbox.org/) | 6.1 o superior | Hipervisor que ejecuta todas las máquinas virtuales |
| [Vagrant](https://www.vagrantup.com/) | 2.3 o superior | Orquestador que aprovisiona y configura las MV desde el Vagrantfile |
| Cliente SSH (OpenSSH, PuTTY, etc.) | cualquiera | Acceso por terminal a las MV (opcional, principalmente a `external-kali`) |
| Navegador web moderno | actual, moderna | Acceso a la WebUI de OPNsense, portal web de la DMZ y escritorio noVNC |

**Sistemas operativos anfitriones compatibles:**
- Linux (Ubuntu 22.04/24.04 LTS recomendado)
- Windows 10/11 con VirtualBox y Vagrant instalados
- macOS (Intel y Apple Silicon, este último con limitaciones conocidas en VirtualBox)

No se requieren plugins adicionales de Vagrant, ya que las redes privadas y las redes internas de VirtualBox se definen directamente en el Vagrantfile sin necesidad de extensiones externas.

### 3.2 Recursos hardware recomendados

El despliegue simultáneo de las cuatro máquinas virtuales requiere una cantidad considerable de memoria y CPU. Las cifras que se indican a continuación corresponden a la configuración asignada en el Vagrantfile y a los valores recomendados para un funcionamiento fluido.

| MV | RAM asignada | vCPUs |
|----|:------------:|:-----:|
| opensense | 1500 MB | 1 |
| external-kali | 2560 MB | 2 |
| dmz-server | 612 MB | 1 |
| vlan20-server | 612 MB | 1 |
| **Total asignado** | **5284 MB** | **5** |

**Recomendación para el anfitrión:**
- **RAM total**: mínimo 8 GB; recomendado 16 GB para holgura del sistema operativo anfitrión.
- **CPU**: procesador de 4 núcleos físicos o superior, con soporte de virtualización (Intel VT-x / AMD-V) habilitado en BIOS/UEFI.
- **Disco duro**: aproximadamente 30 GB libres para las MV y las imágenes base descargadas. Se recomienda SSD para tiempos de arranque y provisión aceptables.

Los valores de RAM del laboratorio ya están optimizados para entornos con recursos limitados. Aun así, es posible levantar solo un subconjunto de máquinas mediante comandos `vagrant up opensense dmz-server` donde se levantarían la MV del firewall y el dmz-server por ejemplo.

### 3.3 Puertos y configuración del host

La máquina anfitriona solo expone un puerto hacia el exterior de la infraestructura virtual hacia la máquina anfitriona, destinado al acceso gráfico de `external-kali`. El resto de las comunicaciones se realizan a través de las redes internas de VirtualBox y, en su caso, mediante las VPNs.

**Puerto utilizado en el host:**

| Puerto host | MV destino | Servicio |
|:-----------:|------------|----------|
| **8081** | external-kali | noVNC (escritorio virtual) |

**Cómo acceder al escritorio virtual:**
1. Arrancar `external-kali` con `vagrant up external-kali` (o `vagrant reload external-kali` si ya estaba creada).
2. Esperar a que los servicios `vncserver` y `novnc` terminen de levantarse (el provisionamiento los configura automáticamente).
3. Abrir en el navegador:  
   [http://localhost:8081/vnc.html](http://localhost:8081/vnc.html)
4. La contraseña VNC es `vagrant`.

Este mecanismo utiliza una redirección de puertos definida en el Vagrantfile (`8081:8081`) y websockify redirige del puerto 8081 al servidor VNC local de la MV (puerto 5901). No se necesita ninguna configuración adicional de red en el anfitrión.

**Acceso a la WebUI de OPNsense:**
La gestión del firewall no se expone directamente en el host. Para acceder a la WebUI (https://192.168.10.1) es necesario:
- Conectar primero la VPN de administradores en `external-kali`.
- Acceder a un navegador dentro de `external-kali` e introducir la URL del OPNsense (https://192.168.10.1).
- Aunque aparezca que la web no es segura hay que continuar, dándole a *avanzado* y continuar hacia el portal we.

**Redes internas de VirtualBox:**
El Vagrantfile crea cuatro redes internas que no son accesibles desde el anfitrión salvo que se configure explícitamente un puente o reenvío de puertos adicional. Estas redes son:
- `net-wan`
- `net-dmz`
- `net-gestion`
- `net-lan`


---

[📑 Volver al índice general](../README.md)  |  [← Anterior](02-topologia-red.md)  |  [Siguiente →](04-despliegue-lab.md)