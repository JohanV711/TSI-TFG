#!/bin/bash
#Crea el rol app_user y su contraseña definidos en .env
#Este fichero se usa para no tener que exponer la contraseña de app_user en init.sql


set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE ROLE ${APP_USER} WITH LOGIN PASSWORD '${APP_USER_PASSWORD}';
EOSQL