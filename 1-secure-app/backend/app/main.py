from fastapi import FastAPI, Depends, HTTPException, status, Form
from fastapi.middleware.cors import CORSMiddleware
from .configuration import settings
from .database import engine
from . import models
from .routers import authentication, albums, photos
import os #para pruebas de Johan, eliminar.

PROXY_PATH=os.getenv("PROXY_ROOT_PATH", "") 

#Esto crea las tablas en caso de que no existan.
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Secure-app API",
    docs_url="/docs", redoc_url="/redoc", #desactivar el SWAGGER en producción.
    root_path=PROXY_PATH #Para servidor remoto de desarrollo , cosas de desarrollo, comentar cuando no se necesite.
    ) 

#CORS permite el origen del frontend.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"], #puerto por defecto de react+vite.
    allow_credentials=True,
    allow_methods=["GET","POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"]
)

app.include_router(authentication.router, prefix="/api/auth", tags=["Autenticación"])
app.include_router(albums.router, prefix="/api/albums", tags=["Álbunes"])
app.include_router(photos.router, prefix="/api/photos", tags=["Fotos"])

@app.get("/", tags=["General"])
def read_root():
    return {"message":"API de secure-app funcionando"}

