import os
import shutil
from fastapi import FastAPI, UploadFile, File, HTTPException

app = FastAPI(
    title="Laboratorio 4: Subida de Archivos Sin Restricciones",
    description="Portal de empleo vulnerable que acepta cualquier tipo de archivo sin validar extensión, tamaño ni nombre."
)

UPLOAD_DIR = "/app/app/archivos_subidos"

@app.get("/")
def read_root():
    return {"status": "Laboratorio de Subida de Archivos Activo en el puerto 8004"}

@app.post("/cv/subir")
def subir_curriculum(file: UploadFile = File(...)):

    nombre_archivo = file.filename
    ruta_destino = os.path.join(UPLOAD_DIR, nombre_archivo)
    
    try:
        with open(ruta_destino, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al guardar: {str(e)}")
        
    return {
        "status": "Archivo subido con éxito",
        "mensaje": f"El archivo se ha guardado en la carpeta pública como: {nombre_archivo}",
        "almacenamiento_destino": ruta_destino
    }

@app.get("/cv/archivos")
def listar_archivos():
    try:
        archivos = os.listdir(UPLOAD_DIR)
        return {"archivos_en_servidor": archivos}
    except Exception as e:
        return {"error": str(e)}