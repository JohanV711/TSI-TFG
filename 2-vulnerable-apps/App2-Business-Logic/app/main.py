from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy.orm import Session
from .database import engine, get_db
from . import models, schemas

# Creamos las tablas automáticamente
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Laboratorio 2: Fallo en la Lógica de Negocio",
    description="Simulación de una tienda virtual que confía ciegamente en los precios enviados por el cliente."
)

# Inicializamos datos de prueba si la base de datos está vacía
@app.on_event("startup")
def startup_populate():
    db = next(get_db())
    try:
        if not db.query(models.Usuario).first():
            # Creamos un usuario de prueba con 100 puntos
            db.add(models.Usuario(id=1, username="alumno_tfg", puntos=100.0))
            # Creamos un producto exclusivo que el usuario NO debería poder pagar
            db.add(models.Producto(id=1, nombre="PlayStation 5", precio_real=500.0))
            db.commit()
    finally:
        db.close()

#Obtiene la información y los puntos de un usuario específico
@app.get("/usuario/{usuario_id}")
def obtener_usuario(usuario_id: int, db: Session = Depends(get_db)):
    usuario = db.query(models.Usuario).filter(models.Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {"username": usuario.username, "puntos_disponibles": usuario.puntos}

#Endpoint de compra vulnerable a manipulación de precios
@app.post("/comprar/vulnerable")
def comprar_vulnerable(request: schemas.CompraRequest, db: Session = Depends(get_db)):
    usuario = db.query(models.Usuario).filter(models.Usuario.id == request.usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    #Fallo de lógica: se confía en el precio enviado por el cliente en lugar del precio real de la base de datos
    precio_a_cobrar = request.precio

    if usuario.puntos < precio_a_cobrar:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Puntos insuficientes. Necesitas {precio_a_cobrar} y tienes {usuario.puntos}"
        )

    #Se resta el saldo. Si el cliente envía un precio negativo, se le sumarán puntos a su cuenta
    usuario.puntos -= precio_a_cobrar
    db.commit()

    #Se devuelve el recibo de la compra
    return {
        "status": "Compra procesada con éxito",
        "producto_id": request.producto_id,
        "puntos_cobrados": precio_a_cobrar,
        "saldo_restante": usuario.puntos
    }
