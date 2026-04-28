#Fichero crucial para la seguridad OWASP. Gestiona la configuración global de la aplicación.

#Importa BaseSettings que permite leer automáticamente variables de entorno y validarlas según el tipo definido.
from pydantic_settings import BaseSettings, SettingsConfigDict
#Field permite definir validaciones o valores adicionales para variables.
from pydantic import Field

#Clase que define el esquema de configuración. Hereda de BaseSettings.
class Settings(BaseSettings):
    #variables que se leerán del .env gracias a Pydantic de forma segura y automática.
    DATABASE_URL: str
    SECRET_KEY: str

    ALGORITHM: str="HS256"                  #Algoritmo de cifrado para los JWT. HS256 es un estándar común.
    ACCESS_TOKEN_EXPIRE_MINUTES: int=30     #Tiempo de vida de los tokens (30min)

    UPLOAD_DIR:str= "/app/uploads"          #ruta definida donde se almacenarán los archivos que suban los usuarios, en este caso va a ser en el volumen docker /app/uploads
    MAX_FILE_SIZE: int=10                   #Límite de tamaño en MB de los fihceros para evitar ataques DoS.
    ALLOWED_IMAGE_TYPES:list[str]=["image/jpeg", "image/jpg", "image/png", "image/webp"]  #valida que no se suban archivos de tipos maliciosos.

    #Configuración interna de Pydantic para leer lo que necesiten del archivo .env
    model_config= SettingsConfigDict(
        env_file=".env",            #de este archivo se cargarán las variables de entorno para el desarrollo.
        extra="ignore",             #ignora variables extra en el .env que no estén definidas en este fichero configuration.py
        case_sensitive=True         #Diferencia entre minúsculas y mayúsculas.
    )

#Instancia de la clase Settings para que pueda ser importada en otros lugares del proyecto.
settings=Settings()