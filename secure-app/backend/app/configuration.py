from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field

class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str="HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int=30

    UPLOAD_DIR:str= "/app/uploads"
    MAX_FILE_SIZE: int=10
    ALLOWED_IMAGE_TYPES:list[str]=["image/jpeg", "image/jpg", "image/png", "image/webp"]

    model_config= SettingsConfigDict(
        env_file=".env", 
        extra="ignore",
        case_sensitive=True
    )

settings=Settings()