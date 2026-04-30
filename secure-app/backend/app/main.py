from fastapi import FastAPI, Depends, HTTPException, status, Form
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import jwt # python-jose

try:
    from . import models, database, schemas, crud
except ImportError:
    import models, database, schemas, crud

# CONFIGURACIÓN SEGURIDAD JWT
SECRET_KEY = "MI_LLAVE_SECRETA_PARA_EL_TFG" # Hay que cmbiarla luego por algo mas complejo
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

app = FastAPI(title="Secure App API")

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_access_token(data: dict):
    """Genera el token firmado con tiempo de expiración."""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

@app.get("/", tags=["General"])
def read_root():
    return {"message": "API de Secure App funcionando"}

# --- REGISTRO ---
@app.post("/register", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED, tags=["Autenticación"])
def register_user(
    email: str = Form(..., json_schema_extra={"example": ""}), #Formato de salida en app
    password: str = Form(..., json_schema_extra={"example": ""}),
    db: Session = Depends(get_db)
):
    db_user = crud.get_user_by_email(db, email=email)
    if db_user:
        raise HTTPException(status_code=400, detail="El email ya está registrado.")
    return crud.create_user(db=db, email=email, password=password)

# --- LOGIN (GENERACIÓN DE TOKEN) ---
@app.post("/token", response_model=schemas.Token, tags=["Autenticación"])
def login_for_access_token(
    email: str = Form(..., json_schema_extra={"example": ""}),
    password: str = Form(..., json_schema_extra={"example": ""}),
    db: Session = Depends(get_db)
):
    """
    Verifica credenciales y devuelve un Token JWT para usar en otras rutas.
    """
    user = crud.authenticate_user(db, email, password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"}, #Bearer es como un rol que si tiene el token sabe que es seguro y no necesita autenticarse todo el rato
        )
    
    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer"}
# ruta para ver los usuarios
@app.get("/users/")
def get_users(db: Session = Depends(get_db)):
    users = db.query(models.User).all()
    return users