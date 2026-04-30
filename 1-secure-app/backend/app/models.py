#Como python no "habla" SQL directamente, hay que usar un ORM (Object RelationalMapping) que ayuda a un lenguaje de programación orientado a objetos a trabajar con bases de datos.
#Por eso este archivo básicamente crea las tablas de la base de datos para que las "entienda" Python.

#Importa la librería uuid para generar indetificadores únicos universales.
import uuid
#Tipos de columnas y restricciones.
from sqlalchemy import Column, String, Boolean, ForeignKey, Integer, Text, DateTime, UniqueConstraint
#Importa el tipo UUID de PostgreSQL.
from sqlalchemy.dialects.postgresql import UUID
#Permite usar funciones SQL como NOW().
from sqlalchemy.sql import func
#Para las relaciones entre tablas.
from sqlalchemy.orm import relationship
#importa la clase Base que definimos en database.py, todas las tablas heredarán de este clase, por eso todas las clases tienen entre paréntesis la palabra Base.
from .database import Base

class User(Base):
    __tablename__="users"
    user_id=Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email=Column(String(255), nullable=False, unique=True)
    password_hash=Column(String(255), nullable=False)
    created_at=Column(DateTime(timezone=True), server_default=func.now())
    is_active=Column(Boolean, default=True)

    albums=relationship("Album", back_populates="owner", cascade="all, delete-orphan")
    photos=relationship("Photo", back_populates="owner", cascade="all, delete-orphan")
    blacklisted_tokens = relationship("TokenBlacklist", back_populates="user", cascade="all, delete-orphan")

class Album(Base):
    __tablename__="albums"
    album_id=Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id=Column(UUID(as_uuid=True), ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    name=Column(String(255), nullable=False)
    description=Column(Text)
    created_at=Column(DateTime(timezone=True), server_default=func.now())

    owner=relationship("User", back_populates="albums")
    photos=relationship("Photo", back_populates="album", cascade="all, delete-orphan")
    __table_args__=(UniqueConstraint('user_id','name', name='_user_album_uc'),)


class Photo(Base):
    __tablename__="photos"
    photo_id=Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    album_id=Column(UUID(as_uuid=True), ForeignKey("albums.album_id",ondelete="CASCADE"), nullable=False)
    user_id=Column(UUID(as_uuid=True), ForeignKey("users.user_id",ondelete="CASCADE"), nullable=False)
    file_path=Column(String(255), nullable= False)
    thumbnail_path=Column(String(500))
    title=Column(String(255))
    file_size=Column(Integer, nullable=False)
    mime_type=Column(String(100), nullable=False)
    upload_date=Column(DateTime(timezone=True), server_default=func.now())

    album=relationship("Album", back_populates="photos")
    owner=relationship("User", back_populates="photos")


class TokenBlacklist(Base):
    __tablename__="token_blacklist"
    jti=Column(String(255), primary_key=True)
    user_id=Column(UUID(as_uuid=True), ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    expires_at=Column(DateTime(timezone=True), nullable=False)

    user=relationship("User", back_populates="blacklisted_tokens")