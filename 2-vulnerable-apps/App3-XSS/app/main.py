from fastapi import FastAPI, Depends, HTTPException
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from .database import engine, get_db
from . import models, schemas

models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Laboratorio 3: Cross-Site Scripting (XSS Almacenado)",
    description="Simulación de un foro comunitario que almacena y renderiza entradas de texto sin sanitizar."
)

@app.on_event("startup")
def startup_populate():
    db = next(get_db())
    try:
        if not db.query(models.Comentario).first():
            db.add(models.Comentario(usuario="Admin_Foro", contenido="¡Bienvenidos al foro de alumnos del TFG! Dejad vuestros comentarios con respeto."))
            db.commit()
    finally:
        db.close()

# Endpoint 1: Publicar en el foro (Vulnerable porque no filtra ni limpia el contenido)
@app.post("/comentarios", response_model=schemas.ComentarioResponse)
def crear_comentario(request: schemas.ComentarioCreate, db: Session = Depends(get_db)):
    nuevo_comentario = models.Comentario(usuario=request.usuario, contenido=request.contenido)
    db.add(nuevo_comentario)
    db.commit()
    db.refresh(nuevo_comentario)
    return nuevo_comentario

@app.get("/comentarios", response_model=list[schemas.ComentarioResponse])
def listar_comentarios(db: Session = Depends(get_db)):
    return db.query(models.Comentario).all()

@app.get("/foro-web", response_class=HTMLResponse)
def ver_foro_en_navegador(db: Session = Depends(get_db)):
    comentarios = db.query(models.Comentario).all()
    
    html_content = """
    <html>
        <head><title>Foro Universitario Vulnerable</title></head>
        <body style="font-family: Arial, sans-serif; margin: 40px; background-color: #f4f4f9;">
            <h2>🏛️ Tablón de Anuncios del Campus</h2>
            <hr>
    """
    
    for c in comentarios:
        html_content += f"""
        <div style="background: white; padding: 15px; margin-bottom: 10px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <strong>👤 {c.usuario}:</strong>
            <p>{c.contenido}</p>  </div>
        """
        
    html_content += "</body></html>"
    return html_content