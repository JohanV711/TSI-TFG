from sqlalchemy import Column, Integer, String, Text
from .database import Base

class Comentario(Base):
    __tablename__ = "comentarios"

    id = Column(Integer, primary_key=True, index=True)
    usuario = Column(String(50), nullable=False)
    contenido = Column(Text, nullable=False)