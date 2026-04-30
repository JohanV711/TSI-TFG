#En este fichero gracias a Pydantic se valida que lo que entra (request) y lo que sale (response) de la API
#tenga el formato correcto que debe. Se podrían definir como "contratos" o "esquemas" de como se deben leer o entregar los datos.
#Es como un filtro de entrada y un filtro de salida limpiando datos malos o evitando que se escape 
#infromación sensible.

from pydantic import BaseModel, EmailStr, field_validator
from uuid import UUID
from datetime import datetime
from typing import Optional
import re #Librería de expresions regulares de Python.


#======USUARIOS==========

#"Contrato" para cuando alguien se registra.
class UserCreate(BaseModel):
    email: EmailStr     #Comprueba que el email tiene formato (@) y dominio correcto.
    password: str       #&recibirá la contraseña como texto (String).

    @field_validator("password") #Decorador que le dice a Pydantic que antes de pasar el dato debe ejecutarse esta función llamada field_validator
    @classmethod #necesario por Pydantic para que el validador funcione a nivel de clase.
    def password_strength(cls, v):
        #Valida que la contraseña sea segura, mínimo 8 caracteres, una mayúscula, una minúscula
        #y un dígito mínimo.
        if len(v)<8:
            raise ValueError("La contraseña debe tener al menos 8 caracteres.")
        if not re.search(r"[A-Z]", v):
            raise ValueError("La contraseña debe tener al menos una mayúscula.")
        if not re.search(r"[a-z]", v):
            raise ValueError("La contraseña debe tener al menos una minúscula.")
        if not re.search(r"\d", v):
            raise ValueError("La contraseña debe tener al menos un dígito.")
        return v


# Esquema para la respuesta de usuario (Segura), de salida. Es importante tenerlo bien configurado para evitar fugas de infromación.
#No se incluye el campo password_hash.
class UserResponse(BaseModel):
    user_id: UUID
    email: EmailStr
    is_active: bool
    created_at: datetime

    #permite a Pydantic que lea directamente un objeto de SQLAlchemy y lo convierta a este formato UserResponse
    #de forma automática, incluso aunque el objeto original tenga más campos como el que no queríamos incluir password_hash.
    model_config={"from_attributes": True}


#======AUTENTICACIÓN==========

#Solo email y contraseña para inicio de sesión.
class LoginRequest(BaseModel):
    email: EmailStr
    password: str

#Define cómo se va a entregar el token al usuario después del login.
class Token(BaseModel):
    access_token: str
    token_type: str="bearer"

class TokenDatos(BaseModel):
    #este se usará para "leer" lo que hay dentro del token del usuario que esté ya autenticado.
    user_id: str
    jti: str #es único, y en caso de estar en TokenBlacklist se rechaza la petición a este esquema.

#======FOTOS==========

#Principio de mínimo privilegio a la hora de responder.
class PhotoResponse(BaseModel):
    photo_id: UUID
    album_id: UUID
    user_id: UUID
    title: Optional[str]
    file_size: int  #peso de la foto
    mime_type: str  #tipo de archivo (PNG, JPG, etc)
    upload_date: datetime
    
    model_config={"from_attributes": True}
    #Importante no devolver file_path para que no se naveguen por las carpetas del servidor donde se almacenen estas fotos.

#======ÁLBUNES==========

#similar a UserCreate(BaseMoodel).
class AlbumCreate(BaseModel):
    name: str
    description: Optional[str] = None   #El usuario puede omitir la descripción.

    @field_validator("name")
    @classmethod
    def name_not_empty(cls, v):
        v=v.strip() #elimina espacios vacíos al principio y al final para evitar que usuarios creen nombres vacíos.
        if not v:   #Si tras el strip el nombre queda vacío se avisa de que se escriba algún nombre.
            raise ValueError("El nombre del álbum no puede estar vacío.")
        return v

class AlbumResponse(BaseModel):
    album_id: UUID
    user_id: UUID
    name: str
    description: Optional[str]
    created_at: datetime

    model_config={"from_attributes": True}




