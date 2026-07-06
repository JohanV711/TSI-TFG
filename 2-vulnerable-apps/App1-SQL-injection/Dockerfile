# Usamos una imagen base estándar de Python
FROM python:3.12

WORKDIR /app

# Copiamos e instalamos las dependencias
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ./app ./app

# Mantenemos el contenedor como ROOT para permitir la escalada en el laboratorio
EXPOSE 8001

# Comando ajustado: Ahora llamamos a "app.main:app" porque el archivo está dentro de la subcarpeta
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]