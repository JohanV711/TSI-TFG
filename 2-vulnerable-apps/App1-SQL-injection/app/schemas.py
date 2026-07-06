from pydantic import BaseModel, Field, field_validator
import re

# Esquema para formatear la respuesta del servidor al cliente
class NotaResponse(BaseModel):
    estudiante: str
    asignatura: str
    nota: float

    class Config:
        from_attributes = True

# Esquema seguro con validador de expresiones regulares (Mitigación)
class ConsultaNotaRequest(BaseModel):
    expediente: str

    @field_validator("expediente")
    @classmethod
    def validar_formato_expediente(cls, v):
        v = v.strip()
        # Regla de negocio: El expediente debe ser estrictamente una 'E' seguida de 6 números
        if not re.match(r"^E\d{6}$", v):
            raise ValueError("Formato de expediente inválido. Debe ser tipo E123456.")
        return v