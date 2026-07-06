from sqlalchemy import Column, String, Integer, Float
from .database import Base

class Calificacion(Base):
    __tablename__ = "calificaciones"
    
    id = Column(Integer, primary_key=True, index=True)
    estudiante = Column(String(100), nullable=False)
    expediente = Column(String(50), nullable=False)
    asignatura = Column(String(100), nullable=False)
    nota = Column(Float, nullable=False)