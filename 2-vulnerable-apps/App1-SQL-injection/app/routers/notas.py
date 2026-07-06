from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text

# Corregimos la importación para que busque correctamente en la misma carpeta
from app import models, schemas
from app.database import get_db

router = APIRouter()

# -------------------------------------------------------------
# ❌ ENDPOINT VULNERABLE: Inyección SQL Clásica por Concatenación
# -------------------------------------------------------------
@router.get("/notas/vulnerable", response_model=list[schemas.NotaResponse])
def consultar_notas_vulnerable(expediente: str, db: Session = Depends(get_db)):
    # Peligro: El parámetro 'expediente' ingresa directo a la consulta sin validar ni filtrar
    query_vulnerable = f"SELECT estudiante, asignatura, nota FROM calificaciones WHERE expediente = '{expediente}'"
    
    try:
        # Se ejecuta como texto plano modificando el árbol de sintaxis de la base de datos
        result = db.execute(text(query_vulnerable)).fetchall()
        if not result:
            raise HTTPException(status_code=404, detail="No se encontraron calificaciones.")
        
        return [
            {"estudiante": row[0], "asignatura": row[1], "nota": float(row[2])}
            for row in result
        ]
    except Exception as e:
        # Mala práctica didáctica: Exponer el error crudo del motor SQL al cliente
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Error interno del motor SQL: {str(e)}"
        )

# -------------------------------------------------------------
# ✅ ENDPOINT MITIGADO: Uso correcto del ORM y Validación Pydantic
# -------------------------------------------------------------
@router.get("/notas/seguro", response_model=list[schemas.NotaResponse])
def consultar_notas_seguro(
    request: schemas.ConsultaNotaRequest = Depends(), 
    db: Session = Depends(get_db)
):
    # Al usar el método .filter() del ORM, SQLAlchemy se encarga de parametrizar 
    # y enmascarar de forma segura la entrada del usuario automáticamente
    calificaciones = db.query(models.Calificacion).filter(
        models.Calificacion.expediente == request.expediente
    ).all()
    
    if not calificaciones:
        raise HTTPException(status_code=404, detail="Expediente no encontrado o sin notas.")
        
    return calificaciones