#Este archivo donde se gestiona la autenticación de usuarios y el ciclo de vida de las sesiones.
#Se definen los endpoints(rutas URL y sus métodos POST, PUT, etc que sirve para comunicar el cliente con el servidor)
#Aqui se usan muchos de los ficheros que se han ido construyendo.

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from .. import crud, schemas
from ..database import get_db
from ..criptography import create_access_token, verify_password, decode_access_token
from ..dependencies import get_current_active_user
from .. import models

router=APIRouter()
bearer_scheme= HTTPBearer(auto_error=True)

#Registro de usuarios.
@router.post("/register",response_model=schemas.UserResponse,status_code=status.HTTP_201_CREATED,summary="Registro usuario")
def register(user_data: schemas.UserCreate, db:Session=Depends(get_db)):
    #Se comprueba si el email ya existe.
    existing_user=crud.get_user_by_email(db, email=user_data.email)
    if existing_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No se puede completar el registro, verifica los datos introducidos.") #no dar detalles específicos por seguridad en detail.
    
    #Se crea el usuario si todo es correcto llamando al fichero crud.py.
    new_user=crud.create_user(db=db, email=user_data.email, password=user_data.password)
    return new_user

#Inicio de sesión.
@router.post("/login", response_model=schemas.Token, summary="Inicio de sesión")
def login(credentials: schemas.LoginRequest, db: Session=Depends(get_db)):
    #se comprueba que existe el usuario en la base de datos y se autentica gracias a métodos de crud.py.
    user=crud.authenticate_user(db, email=credentials.email, password=credentials.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Email o contraseña incorrectos.", headers={"WWW-Authenticate":"Bearer"})
    #Si el usuario es correcto se genera un token con  su JWT.
    access_token, jti=create_access_token(subject=str(user.user_id))

    #Se devuelve el token al cliente que esté haciendo peticiones a la API para que el frontend guarde ese token y lo use en cada petición para no tener que iniciar sesión a cada rato.
    return {"access_token": access_token, "token_type":"bearer"}

#Cerrar sesión.
@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT, summary="Cierre de sesión")
#Con la parte Depends(get_current_active_user) le decimos que solo alguien que ya está logueado puede cerrar sesión.
def logout(credentials: HTTPAuthorizationCredentials=Depends(bearer_scheme), db: Session=Depends(get_db), current_user: models.User=Depends(get_current_active_user)):
    #Decodificamos el token que envía el usuario para comprobar sus datos.
    payload=decode_access_token(credentials.credentials)
    jti=payload.get("jti")
    expires_at=datetime.fromtimestamp(payload.get("exp"), tz=timezone.utc)
    #Añadimos el token a la blacklist de tokens para que ya no se pueda volver a iniciar sesión con refrescar la página o si alguien lo roba después del logout no podrá entrar.
    crud.add_token_to_blacklist(db=db, jti=jti, user_id=current_user.user_id, expires_at=expires_at)

#Prueba. Devuelve los datos del usuario autenticado.
@router.get("/me", response_model=schemas.UserResponse, summary="Usuario autenticado.")
def get_me(current_user: models.User = Depends(get_current_active_user)):
    return current_user

