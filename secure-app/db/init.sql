-- Archivo para creación y primera configuración de la base de datos de Secure-app
-- Usada por docker compose para desplegar un contenedor PostgreSQL.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users(
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), --La extensión pgcrypto permite usar la función gen_random_uuid para genear UUIDs automáticamente en cada insert.
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS albums(
    album_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), 
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    unique(user_id, name)
);


CREATE TABLE IF NOT EXISTS photos(
    photo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), 
    album_id UUID NOT NULL REFERENCES albums(album_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    file_path VARCHAR(255) NOT NULL,
    thumbnail_path VARCHAR(500),
    title VARCHAR(255),
    file_size INTEGER NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    upload_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS token_blacklist(
    jti VARCHAR(255) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Posible mejora: añadir índices para mejorar rendimiento en caso de que aumente
--significativamente el número de fotos.