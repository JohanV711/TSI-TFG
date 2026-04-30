from pydantic import BaseModel, EmailStr
from uuid import UUID
from typing import Optional

# Esquema para los datos de entrada (Registro)
class UserCreate(BaseModel):
    email: EmailStr
    password: str

# Esquema para la respuesta de usuario (Segura)
class UserResponse(BaseModel):
    user_id: UUID
    email: EmailStr
    is_active: bool

    class Config:
        from_attributes = True

# --- NUEVOS ESQUEMAS PARA EL LOGIN ---

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None