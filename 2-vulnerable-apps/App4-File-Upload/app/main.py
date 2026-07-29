import os
import shutil
from fastapi import FastAPI, UploadFile, File, HTTPException

app = FastAPI(
    title="Laboratorio 4: Subida de Archivos Sin Restricciones",
    description="Portal de empleo vulnerable que acepta cualquier tipo de archivo sin validar extensión, tamaño ni nombre."
)

#Directorio donde se guardarán los archivos subidos de forma directa
UPLOAD_DIR = "/app/app/archivos_subidos"

#Comprueba que la API está funcionando correctamente
@app.get("/")
def read_root():
    return {"status": "Laboratorio de Subida de Archivos Activo en el puerto 8004"}

#Endpoint vulnerable. Acepta cualquier archivo sin comprobar su tipo, tamaño o extensión
@app.post("/cv/subir")
def subir_curriculum(file: UploadFile = File(...)):
    
    #Fallo de seguridad: confía ciegamente en el nombre original del archivo, lo que permite ataques de Path Traversal
    nombre_archivo = file.filename
    ruta_destino = os.path.join(UPLOAD_DIR, nombre_archivo)
    
    try:
        #Guarda el archivo directamente en el sistema de ficheros del servidor
        with open(ruta_destino, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al guardar: {str(e)}")
        
    #Se devuelve la ruta exacta de destino, exponiendo la estructura interna de carpetas del servidor    
    return {
        "status": "Archivo subido con éxito",
        "mensaje": f"El archivo se ha guardado en la carpeta pública como: {nombre_archivo}",
        "almacenamiento_destino": ruta_destino
    }

#Endpoint que lista todos los archivos contenidos en el directorio
#esto facilita a un atacante comprobar si su archivo malicioso se ha subido con éxito
@app.get("/cv/archivos")
def listar_archivos():
    try:
        archivos = os.listdir(UPLOAD_DIR)
        return {"archivos_en_servidor": archivos}
    except Exception as e:
        return {"error": str(e)}
