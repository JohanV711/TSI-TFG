from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from .configuration import settings
import sys

engine=create_engine(
    settings.DATABASE_URL,
    pool_size=5,
    max_overflow=10,
    pool_timeout=30,
    pool_recycle=3600,
    pool_pre_ping=True,
    echo=False
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base= declarative_base()

def get_db():
    db=SessionLocal()
    try:
        yield db
    finally:
        db.close()

