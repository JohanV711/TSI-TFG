#Imagen ligera de PYhton 3.12, menos superficie de ataque y menos tamaño.
FROM python:3.12-slim

#Directorio de trabajo dentro del contenedor que se cree con esta imagen.
WORKDIR /app

#Docker por defecto usa usuarios root para correr los procesos (UID 0) dentro de un contenedor.
#Este usuario tiene privilegios y si alguien consiguiera entrar con él podría comprometer la seguridad.
#Por esa razón se va a crear un usuario sin privilegios de admin para que su intevención en el contenedor sea limitada.
#Principio de mínimo privilegio de OWASP.
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

#Se copia el archivo requirements.txt dentro del directorio actual de la imagen del contenedor.
COPY requirements.txt .

#Se instalan las dependencias necesarias dentro de la imagen
RUN pip install --no-cache-dir -r requirements.txt

#Se copia todo el contenido que hay en la carpeta backend/app/ a la carpeta app/ de la imagen del contenedor.
#Cambiamos el propietario de los archivos al usuario no privilegiado.
COPY --chown=appuser:appgroup ./app ./app

#Carpeta de uploads con permisos correctos.
RUN mkdir -p /app/uploads && chown -R appuser:appgroup /app/uploads

#A partir de aqui, el usuario no root será con el que se ejecute el contenedor.
USER appuser

#CMD se usa para definir el comando que se escribirá por defecto al iniciar el contenedor.
#En este caso, como se va a usar Uvicorn que sirve como servidor backend rápido, usamos el siguiente comando:
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
#Con ese comando le decimos al contenedor que esuchce en todas sus interfaces de la red 
#interna de docker y sea accesible por el puerto 8000 a otros contenedores que estén en la misma red.