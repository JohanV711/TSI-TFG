#Este archivo contiene importantes configuraciones de seguridad, además de que participa en la navegación de los usuarios sin tener que loguearse a cada rato.

import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional

import jwt
from jwt.exceptions import InvalidTokenError, ExpiredSignatureError
from passlib.context import CryptContext

from .configuration import settings

#Instancia de CryptContext de la librería passlib que gestiona cómo debe ser el ciclo de vida de las contraseñas de forma segura.
#"bcryp" es el algoritmo de cifrado muy seguro que añade ruido aleatorio y es lento a propósito por seguridad.
#deprecated="auto" ayuda a dar avisos de forma automática cuando un usuario haga login y tenga un algoritmo de cfirado "viejo".
#bcrypt_rounds indica cuántas veces se ejecuta la función de hashing, indicando el exponente al que se eleva en base 2 (2^12).
pwd_context= CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)

def hash_password(original_password: str)->str:
    #Transforma la contraseña inicial en un hash inentendible.
    return pwd_context.hash(original_password)

def verify_password(original_password: str, hash_password: str)->bool:
    #Compara una contraseña sin cifrar con su contraseña hasheada para comprobar que coincida.
    #Cuando el usuario haga login, se comparará la contraseña que escribió con el hash de la base de datos.
    return pwd_context.verify(original_password, hash_password)

#En esta función se crea el token para que el usuario pueda navegar por la web de forma segura.
def create_access_token(subject: str)->tuple[str, str]:
    #Genera un JWT(Jason Web Token) firmado con HS256.
    jti=str(uuid.uuid4())   #JWT Id único necesario para la TokenBlacklist.
    now=datetime.now(timezone.utc)  #Se marca el momento de creación del token.
    expire= now+timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES) #e establece tiempo de vencimiento también por seguridad.

    #payload o carga útil, es la información que viaja dentro del token.
    payload={
        "sub": subject,     #ID del usuario
        "jti": jti,         #ID del token
        "iat": now,         #Fecha de emisión
        "exp": expire       #Fecha de caducidad.
    }

    #Se firma el token con la SECRET_KEY para que nadie pueda falisificarlo.
    token = jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    #Se devuelven el token y el jti para hacer cosas con ellos.
    return token, jti

def decode_access_token(token: str) -> dict:
    #Función importante que comprueba que el Token es auténtico.
    #Lo decodifica y maneja errores de seguridad.
    try:
        payload=jwt.decode(
            token,
            settings.SECRET_KEY,                #Verifica que la firma sea correcta con SECRET_KEY.
            algorithms=[settings.ALGORITHM],    #Verifica que el token no haya expirado.
            #Se fuerza que el token tenga estos campos si o si, sino podría ser sospechoso.
            options={"require":["sub", "jti", "exp", "iat"]}
            )
        return payload

    except ExpiredSignatureError:
        #Token caducado.
        print("Error, el token ha expirado.")       #REEMPLAZAR por logging en producción
        raise
    
    except InvalidTokenError:
        #en caso de que el token haya sido manipulado.
        print("Error, token inválido o manipulado.")    #REEMPLAZAR por logging en producción
        raise


