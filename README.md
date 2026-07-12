# Clonar repositorio

```bash
git clone https://github.com/JohanV711/TSI-TFG.git
```

# Ecosistema de Laboratorios de Ciberseguridad (TFG)

Este repositorio contiene el código fuente, los scripts de automatización y la infraestructura como código del Trabajo de Fin de Grado: **"Desarrollo de un entorno virtualizado multibloque para el aprendizaje práctico de la ciberseguridad basado en contenedores y virtualización"**.

El proyecto se estructura en **cuatro bloques prácticos** diseñados bajo una metodología de **análisis por contraste**. El objetivo es enfrentar entornos que aplican estrictamente el Esquema Nacional de Seguridad (ENS) y el estándar OWASP, contra arquitecturas que reproducen antipatrones de diseño reales.

---

## Estructura de los bloques

| Bloque | Directorio | Dominio principal | Paradigma de despliegue | 
| :--- | :--- | :--- | :--- | 
| **Bloque 1** | [`./1-secure-app/`](./1-secure-app/) | Seguridad de aplicaciones, defensivo | Contenedores (Docker) | 
| **Bloque 2** | [`./2-vulnerable-apps/`](./2-vulnerable-apps/) | Explotación web, OWASP Top 10, ofensivo | Contenedores (Docker) | 
| **Bloque 3** | [`./3-secure-network-lab/`](./3-secure-network-lab/) | Seguridad de red perimetral, defensivo | Virtualización (Vagrant) | 
| **Bloque 4** | [`./4-insecure-network-lab/`](./4-insecure-network-lab/) | Antipatrones y red plana, ofensivo | Virtualización (Vagrant) | 

---

## 1. Programas y requisitos previos

Para garantizar la reproducibilidad de todo el ecosistema, el sistema anfitrión debe contar con las siguientes herramientas instaladas:

- **Git:** control de versiones y clonado del repositorio, se recomienda usar la **terminal Git Bash**.
- **Docker Desktop / Engine** (v24+): motor de contenerización e interfaz Compose para los Bloques 1 y 2.
- **VirtualBox** (v6.1 o v7.0+): hipervisor de tipo 2 para virtualizar las topologías de red de los Bloques 3 y 4.
- **Vagrant** (v2.3+): orquestador de infraestructura como código para instanciar las máquinas virtuales.
- **Make:** herramienta de automatización para ejecutar los comandos del centro de mando global.

> **Nota sobre plugins de red:** Al ejecutar el primer laboratorio de Vagrant, el sistema verificará e instalará automáticamente el plugin `vagrant-none-communicator` requerido por OPNsense.

---

## 2. Centro de mando global

En lugar de requerir comandos extensos y específicos para cada tecnología, la raíz del proyecto incluye un `Makefile` que estandariza el ciclo de vida de los cuatro laboratorios.

Para consultar todos los comandos disponibles se puede ejecutar:

```bash
make help
```

---

## 3. Guía de despliegue por bloque

**No es recomendable desplegar los bloques simultáneamente ya que algunos bloques comparten puertos y consumiría muchos recursos de la máquina anfitriona.**

### Bloque 1: Secure App
- Activar Docker
- **Despliegue:** `make bloque1`  
  Tiempo estimado: ~2 minutos en la primera compilación.
- **Acceso:** abre tu navegador en `https://localhost` o en `http://localhost`en  y acepta el aviso de certificado TLS autofirmado.
- **Más detalles en [`./1-secure-app/README.md`](./1-secure-app/README.md)**
- **Apagado rápido:** `make down1`
- **Destrucción total:** `make destroy1`

### Bloque 2: Vulnerable Apps
- **Estado:** completar.
- **Despliegue:** `make bloque2`

### Bloque 3: Secure Network Lab
- **Despliegue:** `make bloque3`  
  Tiempo estimado: ~20-30 minutos.
- **Acceso y gestión:**
  - Entrar al directorio: `cd 3-secure-network-lab`
  - Acceder a la consola gráfica del atacante (External Kali) vía navegador en `http://localhost:8081/vnc.html` o entrar con `vagrant ssh external-kali` 
    Credenciales y más detalles en el [`README local`](./3-secure-network-lab/readme.md) de la carpeta del bloque 3.
- **Apagado rápido (puede tardar unos minutos):** `make down3`
- **Destrucción total:** `make destroy3`

### Bloque 4: Insecure Network Lab
- **Despliegue:** `make bloque4`  
  Tiempo estimado: ~8-10 minutos.
- **Acceso y auditoría:**
  - Entrar al directorio: `cd 4-insecure-network-lab`
  - Acceder a la consola gráfica del atacante (External Kali) vía navegador en `http://localhost:8082/vnc.html` o entrar con `vagrant ssh external-kali`
    Más detalles en el [`README local`](./4-insecure-network-lab/README.md) de la carpeta del bloque 4.
- **Apagado rápido:** `make down4`
- **Destrucción total:** `make destroy4`


**La documentación académica y técnica completa está disponible en la Memoria del Trabajo de Fin de Grado.**
