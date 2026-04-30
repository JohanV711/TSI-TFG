from fastapi import FastAPI, Depends, HTTPException, status, Form
from fastapi.middleware.cors import CORSMiddleware
from .configuration import settings
from .database import engine
from . import models


#Crea las tablas en caso de que no existan.
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Secure-app API",
    docs_url="/docs", redoc_url="/redoc", #desactivar el SWAGGER en producción.
    #root_path="/proxy/8000" #Para servidor remoto de desarrollo, cosas de desarrollo, comentar cuando no se necesite.
    ) 

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

#CORS permite el origen del frontend.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"], #puerto por defecto de react+vite.
    allow_credentials=True,
    allow_methods=["GET","POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"]
)