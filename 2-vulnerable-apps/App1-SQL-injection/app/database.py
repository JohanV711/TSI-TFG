#Archivo que gestionar la manera en que se debe conectar a SQLAlchemy

#Importa la función para crear el motor de conexión a la base de datos.
#El motoro o engine es el componente que mantiene el pool de conexiones y gestiona la comunicación la base de datos.
import os
from sqlalchemy import create_engine
#Herramientas para gestionar sesiones y modelos ORM.
from sqlalchemy.orm import sessionmaker, declarative_base

#Importa del archivo configuration.py la configuración para obtener las variables de entorno de forma segura del .env.
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://app_user:user_pass_segura@postgres:5432/secure_db")
#Configuración del motor de SQLAlchemy
engine=create_engine(
    DATABASE_URL, #Url de la base de datos extraída del .env de forma segura.
    pool_size=5,           #Número de conexiones que pueden permanecer abiertas a la vez.
    max_overflow=10,       #Conexiones extra por si se llena el pool.
    pool_timeout=30,       #segundos de espera antes de dar error si no hay conexiones disponibles
    pool_recycle=3600,     #recicla conexiones cada 3600s (1 hora) para evitar problemas de conexiones inactivas o cerradas.
    pool_pre_ping=True,    #verifica si la conexión esta activa antes de usarla. Importante en entornos con contenedores o redes.
    echo=False             #Si es True, mostraría todas las consultas SQL por consola (fugas de información), cosa que no es muy seguro ni bien visto.
)

#La fábrica de las sesiones, cada vez que se llame a SessionLocal() se tendrá una nueva sesión de base de datos para usar.
# SQLAlchemy recomienda asociarlo al engine para generar las sesiones conetadas a la base correspondiente.
#autocommit=False no guarda los cambios que se hagan automáticamente, deben confirmarse con commit().
#autoflush=False no manda cambios a la base de datos antes de lo que se debe.
#bind=engine le dice a la sesión a qué base de datos apuntar, a engine, creado en este mismo código como el motor de SQLAlchemy.
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

#Importante. Esta parte crea la clase madre de los modelos models.py.
#Las tabla que se creen (users, photos, etc) van a heredar de esta clase Base, la cual usa SQLAlchemy
#para registrar los modelos y los metadatos de las tabalas.
Base= declarative_base()

#Función que le sirve a FastAPI ya que cada vez que una ruta necesite acceso a la base de datos a través de una petición HTTP se llamará a este método.
def get_db():           
    db=SessionLocal()   #se abre una sesión nueva
    try:
        yield db        #entrega esta sesión a la ruta que la pidió
    finally:            #siempre, si o si
        db.close()      #se debe cerrar la sesión, aunque haya errores, para evitar dejar conexiones abiertas sin necesidad.

