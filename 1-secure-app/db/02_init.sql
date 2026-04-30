-- Archivo para creación y primera configuración de la base de datos de Secure-app
-- Usada por el docker compose de la carpeta secure-app para desplegar un contenedor PostgreSQL.

--Esto evita que usuarios puedan crear tablas nuevas por accidente o malicia y limpiar permisos previos.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM app_user;

--Extensión para generar UUIDs.
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

-- Conceder permisos mínimos a app_user
GRANT CONNECT ON DATABASE secureapp_db TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;

-- Permisos en las tablas.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE albums TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE photos TO app_user;
GRANT SELECT, INSERT ON TABLE token_blacklist TO app_user;

-- Posible mejora: añadir índices para mejorar rendimiento en caso de que aumente
--significativamente el número de fotos.