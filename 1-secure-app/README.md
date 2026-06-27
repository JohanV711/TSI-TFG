# Bloque 1 — Secure App

Este directorio alberga el desarrollo técnico del **Bloque 1: Secure-App**, el núcleo defensivo del ecosistema de experimentación de este Trabajo de Fin de Grado.

Consiste en una plataforma web completa y funcional de galería fotográfica construida bajo el paradigma de **Seguridad por Diseño** (*Security by Design*). Actúa como el modelo de "arquitectura de confianza" del proyecto, aplicando barreras de defensa en profundidad en cada una de sus capas:

- **Frontend:** React + Vite + TailwindCSS *(estáticos puros servidos sin intérprete)*.
- **Backend:** FastAPI (Python) *(validación estricta con Pydantic y mitigación de ataques de tiempo)*.
- **Base de Datos:** PostgreSQL 16 *(aislamiento de red, claves UUIDv4 y borrado en cascada)*.
- **Perímetro:** Nginx *(proxy inverso, TLS 1.2/1.3 estricto y cabeceras OWASP)*.

> **Nota sobre la documentación:** El diseño técnico, los diagramas de flujo y la justificación teórica de cada control implementado están desarrollados en la **Memoria Oficial del TFG** (Capítulo 4). Adicionalmente, el propio código fuente de este directorio contiene comentarios explicativos.

---

## 1. Requisitos previos

- **Docker** y **Docker Compose** instalados y corriendo en el equipo anfitrión.

---

## 2. Despliegue de la aplicación

Puedes levantar el proyecto mediante dos vías equivalentes:

### Opción A: Desde la raíz principal del TFG (Recomendado)

```bash
# Estando en /home/mangoadmin/TFG/
make bloque1
```

### Opción B: Manualmente desde este directorio

```bash
# Estando en /home/mangoadmin/TFG/1-secure-app/
docker compose up -d --build
```

---

## 3. Visualización y acceso

Una vez finalizado el proceso de compilación de los contenedores, la plataforma estará disponible en:

- **URL:** `https://localhost`

> **Advertencia del navegador:** Dado que el contenedor de Nginx compila internamente certificados TLS autofirmados para garantizar que el laboratorio sea 100% local y autónomo, el navegador mostrará un aviso de "La conexión no es privada". Es el comportamiento esperado; haz clic en **Configuración avanzada → Acceder a localhost (no seguro)**.

---

## 4. Gestión del ciclo de vida

Para detener la aplicación manteniendo las imágenes y los datos en la base de datos:

```bash
docker compose down
```

Para destruir el laboratorio por completo (borrando volúmenes y reseteando la base de datos al estado inicial de fábrica), ejecuta desde la raíz principal:

```bash
make destroy1
```