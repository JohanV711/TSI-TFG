import uuid
import os
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from uuid import UUID
from PIL import Image
import io

from .. import crud, schemas, models
from ..database import get_db
from ..dependencies import get_current_active_user
from ..configuration import settings

router = APIRouter()
# Tamaño máximo del thumbnail en píxeles.
THUMBNAIL_SIZE = (300, 300)

def _validate_upload(file: UploadFile) -> bytes:
    if file.content_type not in settings.ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,detail=f"Tipo de archivo no permitido. Tipos aceptados: {', '.join(settings.ALLOWED_IMAGE_TYPES)}")

    content = file.file.read()
    max_bytes = settings.MAX_FILE_SIZE * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,detail=f"El archivo supera el tamaño máximo permitido de {settings.MAX_FILE_SIZE} MB.")

    try:
        image = Image.open(io.BytesIO(content))
        image.verify() #detecta ficheros corruptos o falsificados.
    except Exception:
        raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,detail="El archivo no es una imagen válida.")

    return content

def _save_files(content: bytes, mime_type: str) -> tuple[str, str]:
    extension_map = {
        "image/jpeg": ".jpg",
        "image/jpg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp"
    }
    extension = extension_map.get(mime_type, ".jpg")
    #Nombre único generado por el backend - nunca el nombre del usuario.
    file_name = f"{uuid.uuid4()}{extension}"
    thumb_name = f"thumb_{file_name}"
    file_path = os.path.join(settings.UPLOAD_DIR, file_name)
    thumb_path = os.path.join(settings.UPLOAD_DIR, thumb_name)
    # Guardar fichero original.
    with open(file_path, "wb") as f:
        f.write(content)
    # Generar y guardar thumbnail.
    image = Image.open(io.BytesIO(content))
    image.thumbnail(THUMBNAIL_SIZE)
    image.save(thumb_path)
    return file_path, thumb_path

@router.get("",response_model=list[schemas.PhotoResponse],summary="Listar fotos de un álbum")
def get_photos(album_id: UUID,db: Session = Depends(get_db),current_user: models.User = Depends(get_current_active_user)):
    album = crud.get_album_by_id(db=db, album_id=album_id)
    if not album or album.user_id != current_user.user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,detail="Álbum no encontrado.")
    return crud.get_photos_by_album(db=db, album_id=album_id)

@router.post("",response_model=schemas.PhotoResponse,status_code=status.HTTP_201_CREATED,summary="Subir foto a un álbum")
def upload_photo(album_id: UUID,title: str = None,file: UploadFile = File(...),db: Session = Depends(get_db),current_user: models.User = Depends(get_current_active_user)):
    # Verificar propiedad del álbum.
    album = crud.get_album_by_id(db=db, album_id=album_id)
    if not album or album.user_id != current_user.user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,detail="Álbum no encontrado.")
    # Validar fichero.
    content = _validate_upload(file)
    # Guardar fichero y thumbnail.
    file_path, thumb_path = _save_files(content, file.content_type)
    # Persistir metadatos.
    photo = crud.create_photo(db=db,album_id=album_id,user_id=current_user.user_id,file_path=file_path,thumbnail_path=thumb_path,title=title,file_size=len(content),mime_type=file.content_type)
    return photo

@router.get("/{photo_id}",response_model=schemas.PhotoResponse,summary="Obtener metadatos de una foto")
def get_photo(photo_id: UUID,db: Session = Depends(get_db),current_user: models.User = Depends(get_current_active_user)):
    photo = crud.get_photo_by_id(db=db, photo_id=photo_id)
    if not photo or photo.user_id != current_user.user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,detail="Foto no encontrada.")
    return photo

@router.get("/{photo_id}/file",summary="Servir fichero de imagen")
def serve_photo(photo_id: UUID,db: Session = Depends(get_db)):
    photo = crud.get_photo_by_id(db=db, photo_id=photo_id)
    if not photo or photo.user_id != current_user.user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,detail="Foto no encontrada.")
    if not os.path.exists(photo.file_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,detail="Fichero no encontrado en el servidor.")
    return FileResponse(path=photo.file_path,media_type=photo.mime_type,filename=f"{photo.photo_id}{os.path.splitext(photo.file_path)[1]}")

@router.get("/{photo_id}/thumbnail",summary="Servir thumbnail de imagen")
def serve_thumbnail(photo_id: UUID, db: Session = Depends(get_db)):
    photo = crud.get_photo_by_id(db=db, photo_id=photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Foto no encontrada en BD")
    if not photo.thumbnail_path or not os.path.exists(photo.thumbnail_path):
        print(f"DEBUG: No encuentro el archivo en: {photo.thumbnail_path}")
        raise HTTPException(status_code=404, detail=f"Archivo físico no encontrado en {photo.thumbnail_path}")

    return FileResponse(path=photo.thumbnail_path, media_type=photo.mime_type)

@router.delete("/{photo_id}",status_code=status.HTTP_204_NO_CONTENT,summary="Eliminar foto")
def delete_photo(photo_id: UUID,db: Session = Depends(get_db),current_user: models.User = Depends(get_current_active_user)):
    photo = crud.get_photo_by_id(db=db, photo_id=photo_id)
    if not photo or photo.user_id != current_user.user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,detail="Foto no encontrada.")
    # Eliminar ficheros físicos antes de eliminar el registro.
    for path in [photo.file_path, photo.thumbnail_path]:
        if path and os.path.exists(path):
            os.remove(path)
    crud.delete_photo(db=db, photo=photo)