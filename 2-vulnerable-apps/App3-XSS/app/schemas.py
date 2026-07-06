from pydantic import BaseModel

class ComentarioCreate(BaseModel):
    usuario: str
    contenido: str

class ComentarioResponse(BaseModel):
    id: int
    usuario: str
    contenido: str

    class Config:
        from_attributes = True