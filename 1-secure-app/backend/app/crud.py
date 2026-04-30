#Fichero que tiene las funciones que son necesarias para interactuar con la base de datos a la hora de
#realizar consultas crud (Create, read, update, delete).

from sqlalchemy.orm import Session
from . import models
from .criptography import hash_password, verify_password


def get_user_by_email(db: Session, email: str):
    #Busca un usuario por su email. Si no existe devuelve None.
    return db.query(models.User).filter(models.User.email == email).first()

def get_user_by_id():
    #Busca al usuario por su UUID.
    return db.query(models.User).filter(models.User.user_id == user_id).first()

def create_user(db: Session, email: str, password: str):
    #Se crea un usuario nuevo con su contraseña hasheada, cumpliendo asi con OWASP A02 ya que no almacena la contraseña en texto claro.
    hashed_password = pwd_context.hash(password)
    db_user = models.User(
        email=email,
        password_hash=hashed_password
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def authenticate_user(db: Session, email: str, password: str):
    #Verifica las credenciales del usuario para autenticarlo. Devuelve False si no existe, True si existe-
    user = get_user_by_email(db, email)
    if not user:
        #Medida de seguridad importante contra ataques de tipo user enumeration timing.
        #Esos ataques consisten en identificar nombres de usuario válidos en un sistema midiendo 
        #las diferencias en los tiempos de respuesta de la aplicación.
        verify_password("test", "7f8a3c9b1d2e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a")
        #Por eso se usa un hash FICTICIO para que si el usuario no existe se tarde lo mismo que si existiera 
        #en el tiempo de respuesta.
        return False
    if not verify_password(password, user.password_hash):
        return False
    if not user.is_active:
        return False

    return user

def add_token_to_blacklist(db: Session, jti: str, user_id, expires_at):
    #Añade un JWT Id a la blacklist para cuando se cierre sesión.
    token = models.TokenBlacklist( #Se crea un objeto nuevo y se le asignan los valores pasados por parámetros.
        jti=jti,    
        user_id=user_id,
        expires_at=expires_at
    )
    db.add(token) 
    db.commit()     #se añade a la base de datos.

def is_token_in_blacklist(db: Sesion, jti: str)->bool:
    #Comprueba si un JWT Id están en la blacklist.
    return db.query(models.TokenBlacklist).filter(
        models.TokenBlacklist.jti==jti
    ).first() is not None


