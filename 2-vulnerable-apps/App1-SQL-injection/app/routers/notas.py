from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from app import models, schemas
from app.database import get_db

router = APIRouter()

#Consulta de notas vulnerable a inyección SQL
@router.get("/notas/vulnerable", response_model=list[schemas.NotaResponse])
def consultar_notas_vulnerable(expediente: str, db: Session = Depends(get_db)):
    #Se concatena la variable directamente en la consulta,
    query_vulnerable = f"SELECT estudiante, asignatura, nota FROM calificaciones WHERE expediente = '{expediente}'"
    
    try:
        # Se ejecuta como texto plano modificando el árbol de sintaxis de la base de datos
        result = db.execute(text(query_vulnerable)).fetchall()
        if not result:
            raise HTTPException(status_code=404, detail="No se encontraron calificaciones.")
            
        #Se formatea y devuelve el resultado
        return [
            {"estudiante": row[0], "asignatura": row[1], "nota": float(row[2])}
            for row in result
        ]
    except Exception as e:
        #Se expone el error interno de la base de datos, lo que supone un riesgo de seguridad
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Error interno del motor SQL: {str(e)}"
        )
#Consulta de notas segura
@router.get("/notas/seguro", response_model=list[schemas.NotaResponse])
def consultar_notas_seguro(
    request: schemas.ConsultaNotaRequest = Depends(), 
    db: Session = Depends(get_db)
):
    #Se usa el ORM de SQLAlchemy para filtrar de forma segura y evitar inyecciones
    calificaciones = db.query(models.Calificacion).filter(
        models.Calificacion.expediente == request.expediente
    ).all()
    
    if not calificaciones:
        raise HTTPException(status_code=404, detail="Expediente no encontrado o sin notas.")
    #Se devuelven las calificaciones validadas    
    return calificaciones
