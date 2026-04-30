from sqlalchemy.orm import Session
from passlib.context import CryptContext
try:
    from . import models, schemas
except ImportError:
    import models, schemas

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_user_by_email(db: Session, email: str):
    """Busca un usuario por su email."""
    return db.query(models.User).filter(models.User.email == email).first()

def create_user(db: Session, email: str, password: str):
    """Crea un usuario con la contraseña hasheada."""
    hashed_password = pwd_context.hash(password)
    db_user = models.User(
        email=email,
        password_hash=hashed_password
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def authenticate_user(db: Session, email: str, password: str):
    """Comprueba si el email existe y la contraseña coincide."""
    user = get_user_by_email(db, email)
    if not user:
        return False
    if not pwd_context.verify(password, user.password_hash):
        return False
    return user