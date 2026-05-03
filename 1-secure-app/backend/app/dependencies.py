#Fichero donde se aisla la lógica de autorización para las rutas.
#Ayuda a proteger los endpoints, ya que FastAPI inyecta este código en
#cada endpoint.

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jwt.exceptions import InvalidTokenError

from .database import get_db
from .criptography import decode_access_token
from .crud import get_user_by_id, is_token_in_blacklist
from . import models

#HTTPBearer busca el token en el header de la petición HTTP.
#auto_error=True hace que si el usuario no envía el header, la API le eche directmanete con un
#error 403 (Forbidden) antes de hacer nada.
bearer_scheme=HTTPBearer(auto_error=True)

#Función para validar que quien llama a la API es el usuario correcto.
def get_current_user(credentials: HTTPAuthorizationCredentials=Depends(bearer_scheme),db: Session=Depends(get_db)) -> models.User:
    #Aqui se define una excepción genérica. No se deben dar pistas siguiendo las recomendaciones de OWASP.
    credentials_exception=HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,detail="No autenticado.", headers={"WWW-Authenticate":"Bearer"})

    try:
        #Intentamos decodificar el token.
        payload=decode_access_token(credentials.credentials)

        #Si el token no es auténtico o ha expirado se payload será None.
        if payload is None:
            raise credentials_exception
        user_id: str= payload.get("sub") 
        jti:str=payload.get("jti")

        #Comprobar que no faltan el id del usuario y/o del jwt.
        if user_id is None or jti is None:
            raise credentials_exception

    except InvalidTokenError:
        #Para cualquier manipulación, se lanza el error 401.
        raise credentials_exception

    #Si el token es válido hay que comprobar que que esté en la Blacklist.
    #Si está en Blacklist significa que el usuario hizo logout.
    if is_token_in_blacklist(db, jti):
        raise credentials_exception

    #Comprobamos que el usuario del token existe en la base de datos y que esté activo.
    user=get_user_by_id(db, user_id)
    if user is None or not user.is_active:
        raise credentials_exception

    #Si está todo bien , se devuelve el usuario para el endpoint.
    return user

def get_current_active_user(current_user: models.User = Depends(get_current_user))->models.User:
    #Este es un wrapper de pyhton para usarlo en las rutas e indicar a las rutas que dependen de un usuario activo.
    return current_user