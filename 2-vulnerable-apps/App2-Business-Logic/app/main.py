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

@app.get("/usuario/{usuario_id}")
def obtener_usuario(usuario_id: int, db: Session = Depends(get_db)):
    usuario = db.query(models.Usuario).filter(models.Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {"username": usuario.username, "puntos_disponibles": usuario.puntos}

# ❌ ENDPOINT VULNERABLE
@app.post("/comprar/vulnerable")
def comprar_vulnerable(request: schemas.CompraRequest, db: Session = Depends(get_db)):
    usuario = db.query(models.Usuario).filter(models.Usuario.id == request.usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    # ❌ ERROR CRÍTICO DE LÓGICA DE NEGOCIO:
    # Usamos 'request.precio' (enviado por el usuario) en lugar de buscar 'producto.precio_real' en la base de datos.
    precio_a_cobrar = request.precio

    if usuario.puntos < precio_a_cobrar:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Puntos insuficientes. Necesitas {precio_a_cobrar} y tienes {usuario.puntos}"
        )

    # Restamos el precio (si el precio es negativo, menos por menos es más, ¡así que sumará puntos!)
    usuario.puntos -= precio_a_cobrar
    db.commit()

    return {
        "status": "Compra procesada con éxito",
        "producto_id": request.producto_id,
        "puntos_cobrados": precio_a_cobrar,
        "saldo_restante": usuario.puntos
    }
