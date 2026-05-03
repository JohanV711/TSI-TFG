

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from uuid import UUID
from .. import crud, schemas, models
from ..database import get_db
from ..dependencies import get_current_active_user

router = APIRouter()

@router.get("", response_model=list[schemas.AlbumResponse], summary="Listar álbunes del usuario autenticado.")
def get_albums(db:Session=Depends(get_db), current_user: models.User=Depends(get_current_active_user)):
    return crud.get_albums_by_user(db=db, user_id=current_user.user_id)

@router.post("", response_model=schemas.AlbumResponse, status_code=status.HTTP_201_CREATED, summary="Crear nuevo álbum.")
def create_album(album_data: schemas.AlbumCreate, db: Session= Depends(get_db), current_user: models.User=Depends(get_current_active_user)):
    existing = crud.get_album_by_name(db=db, user_id=current_user.user_id, name=album_data.name)
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya existe un álbum con ese nombre.")

    return crud.create_album(db=db, user_id=current_user.user_id, album_data=album_data)

@router.get("/{album_id}", response_model=schemas.AlbumResponse, summary="Obtener álbum por ID")
def get_album(album_id: UUID, db: Session=Depends(get_db), current_user: models.User=Depends(get_current_active_user)):
    album = crud.get_album_by_id(db=db, album_id=album_id)
    if not album or album.user_id!=current_user.user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Álbum no encontrado.")
    return album

@router.put("/{album_id}", response_model=schemas.AlbumResponse, summary="Actualizar álbum")
def update_album(album_id: UUID, album_data: schemas.AlbumCreate, db: Session=Depends(get_db), current_user: models.User=Depends(get_current_active_user)):
    album = crud.get_album_by_id(db=db, album_id=album_id)
    if not album or album.user_id!=current_user.user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Álbum no encontrado")

    return crud.update_album(db=db, album=album, album_data=album_data)

@router.delete("/{album_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar álbum")
def delete_album(album_id:UUID, db: Session=Depends(get_db), current_user:models.User=Depends(get_current_active_user)):
    album=crud.get_album_by_id(db=db, album_id=album_id)
    if not album or album.user_id != current_user.user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Álbum no encontrado.")
    
    crud.delete_album(db=db, album=album)
    return None
