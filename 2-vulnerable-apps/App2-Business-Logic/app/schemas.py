from pydantic import BaseModel

class CompraRequest(BaseModel):
    usuario_id: int
    producto_id: int
    precio: float