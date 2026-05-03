#Fichero que tiene las funciones que son necesarias para interactuar con la base de datos a la hora de
#realizar consultas crud (Create, read, update, delete).

from sqlalchemy.orm import Session
from . import models
from .criptography import hash_password, verify_password

#=============Usuarios=================

def get_user_by_email(db: Session, email: str):
    #Busca un usuario por su email. Si no existe devuelve None.
    return db.query(models.User).filter(models.User.email == email).first()

def get_user_by_id(db:Session, user_id):
    #Busca al usuario por su UUID.
    return db.query(models.User).filter(models.User.user_id == user_id).first()

def create_user(db: Session, email: str, password: str):
    #Se crea un usuario nuevo con su contraseña hasheada, cumpliendo asi con OWASP A02 ya que no almacena la contraseña en texto claro.
    hashed_password =hash_password(password)
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
        verify_password("test", "$2b$12$EixZaYVK1fsbw1ZfbX31XePaWxn96p36WQoeG6L6s57WyHYyMBNyG")
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

def is_token_in_blacklist(db: Session, jti: str)->bool:
    #Comprueba si un JWT Id están en la blacklist.
    return db.query(models.TokenBlacklist).filter(models.TokenBlacklist.jti==jti).first() is not None
# ========Albunes=========

def get_albums_by_user(db:Session, user_id):
    return (db.query(models.Album).filter(models.Album.user_id==user_id).order_by(models.Album.created_at.desc()).all())

def get_album_by_id(db:Session, album_id):
    return db.query(models.Album).filter(models.Album.album_id==album_id).first()

def get_album_by_name(db:Session, user_id, name: str):
    return(db.query(models.Album).filter(models.Album.user_id==user_id, models.Album.name==name).first())

def create_album(db:Session, user_id, album_data):
    album=models.Album(user_id=user_id, name=album_data.name.strip(), description=album_data.description)
    db.add(album)
    db.commit()
    db.refresh(album)
    return album
    
def update_album(db: Session, album:models.Album, album_data):
    album.name=album_data.name.strip()
    album.description=album_data.description
    db.commit()
    db.refresh(album)
    return album

def delete_album(db:Session, album: models.Album):
    db.delete(album)
    db.commit()

#==========photos============
def get_photos_by_album(db:Session, album_id):
    return(db.query(models.Photo).filter(models.Photo.album_id==album_id).order_by(models.Photo.upload_date.desc()).all())

def get_photo_by_id(db:Session, photo_id):
    return db.query(models.Photo).filter(models.Photo.photo_id==photo_id).first()

def create_photo(db:Session, album_id, user_id, file_path:str,thumbnail_path: str, title:str, file_size: int, mime_type: str):
    photo=models.Photo(album_id=album_id,user_id=user_id,file_path=file_path, thumbnail_path=thumbnail_path, title=title, file_size=file_size, mime_type=mime_type)
    db.add(photo)
    db.commit()
    db.refresh(photo)
    return photo

def delete_photo(db:Session, photo:models.Photo):
    db.delete(photo)
    db.commit()