from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from .database import engine
from . import models
from .routers import notas

# Crear la tabla de calificaciones en la base de datos al arrancar
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Vulnerable-Apps: Laboratorio 1 - SQLi",
    description="Entorno controlado para pruebas de Inyección SQL y análisis de mitigación"
)

# Inclusión de las rutas del laboratorio
app.include_router(notas.router, prefix="/api/v1", tags=["Portal de Notas (SQLi)"])

@app.get("/")
def read_root():
    return {"status": "Laboratorio de SQLi activo y funcionando correctamente"}

