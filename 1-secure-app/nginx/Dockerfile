FROM node:20-alpine AS frontend-build
WORKDIR /app
COPY frontend/package*.json ./
RUN npm ci 
COPY frontend/ .
RUN npm run build


FROM nginx:stable-alpine

RUN apk add --no-cache openssl && \
    mkdir -p /etc/nginx/certs && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/certs/selfsigned.key \
    -out /etc/nginx/certs/selfsigned.crt \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=TFG/CN=localhost"

#Eliminamos la configuración por defecto.
RUN rm /etc/nginx/conf.d/default.conf

#Copiar la configuración que hemos hecho del archivo nginx/nginx.conf.
COPY nginx/nginx.conf /etc/nginx/conf.d/app.conf

#Copiar el build DE react desde el contenedor de build del frontend
COPY --from=frontend-build /app/dist /usr/share/nginx/html