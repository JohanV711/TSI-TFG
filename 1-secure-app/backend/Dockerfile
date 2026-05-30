# STAGE 1: Builder.
FROM python:3.12-slim AS builder
WORKDIR /build

#Se copia el archivo requirements.txt dentro del directorio actual de la imagen del contenedor.
COPY requirements.txt .

#Se instalan las dependencias necesarias dentro de la imagen
#Importante: se usa --user para que se instale en /root/.local
RUN pip install --user --no-cache-dir -r requirements.txt

# STAGE 2. Final.
#Imagen ligera de PYhton 3.12, menos superficie de ataque y menos tamaño.
FROM python:3.12-slim

#Directorio de trabajo dentro del contenedor que se cree con esta imagen.
WORKDIR /app

#(Actualización) Actualizar paquetes del SO del contenedor para solucionar CVEs de Trivy..
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

#Docker por defecto usa usuarios root para correr los procesos (UID 0) dentro de un contenedor.
#Este usuario tiene privilegios y si alguien consiguiera entrar con él podría comprometer la seguridad.
#Por esa razón se va a crear un usuario sin privilegios de admin para que su intevención en el contenedor sea limitada.
#Principio de mínimo privilegio de OWASP.
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

#Docker build multi-stage aqui, se copian SÓLO los paquetes instalados desde el builder.
# Los paquetes instalados con --user se guardan en .local
COPY --from=builder /root/.local /home/appuser/.local

#Se copia todo el contenido que hay en la carpeta backend/app/ a la carpeta app/ de la imagen del contenedor.
#Cambiamos el propietario de los archivos al usuario no privilegiado.
COPY --chown=appuser:appgroup ./app ./app

#Carpeta de uploads con permisos correctos.
RUN mkdir -p /app/uploads && chown -R appuser:appgroup /app/uploads

#Configuración de entorno, los paquetes vana  estar en el entorno personal del usuario, por tanto
#hay que decirle a Python dónde encontrar esos paquetes.
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONPATH=/home/appuser/.local/lib/python3.12/site-packages

#A partir de aqui, el usuario no root será con el que se ejecute el contenedor.
USER appuser

#CMD se usa para definir el comando que se escribirá por defecto al iniciar el contenedor.
#En este caso, como se va a usar Uvicorn que sirve como servidor backend rápido, usamos el siguiente comando:
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]          
#reload se mantiene sólo en desarrollo, en producci´pon se quitaría.
#Con ese comando le decimos al contenedor que esuchce en todas sus interfaces de la red 
#interna de docker y sea accesible por el puerto 8000 a otros contenedores que estén en la misma red.
