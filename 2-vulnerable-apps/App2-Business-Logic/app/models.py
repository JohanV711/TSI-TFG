from sqlalchemy import Column, Integer, String, Float
from .database import Base

class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False)
    puntos = Column(Float, default=100.0) # El usuario empieza con 100 puntos de regalo

class Producto(Base):
    __tablename__ = "productos"

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    precio_real = Column(Float, nullable=False)