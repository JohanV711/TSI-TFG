#!/usr/bin/env bash
#Para introducir datos a los servicios de la MV.
set -euo pipefail

mysql -u root << 'SQL'
CREATE DATABASE IF NOT EXISTS corporativedb;
USE corporativedb;

-- Tabla de empleados con datos personales
CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50),
    full_name VARCHAR(100),
    email VARCHAR(100),
    department VARCHAR(50),
    salary INT
);

INSERT INTO employees (username, full_name, email, department, salary) VALUES
('jmartinez', 'Juan Martínez', 'jmartinez@empresa.local', 'IT', 55000),
('mlopez', 'María López', 'mlopez@empresa.local', 'Finanzas', 72000),
('cgarcia', 'Carlos García', 'cgarcia@empresa.local', 'RRHH', 48000),
('aperez', 'Ana Pérez', 'aperez@empresa.local', 'IT', 61000),
('dfernandez', 'David Fernández', 'dfernandez@empresa.local', 'Finanzas', 68000);

-- Tabla de credenciales en texto plano (mala práctica clásica)
CREATE TABLE IF NOT EXISTS user_credentials (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50),
    password VARCHAR(100), -- sin hash, texto plano
    service VARCHAR(50),
    last_login DATETIME
);

INSERT INTO user_credentials (username, password, service, last_login) VALUES
('admin', 'admin123', 'vpn', '2024-11-01 09:23:00'),
('jmartinez', 'juan2024', 'email', '2024-11-03 14:05:00'),
('mlopez', 'Maria@Finanzas', 'intranet', '2024-10-28 11:30:00'),
('copias', 'backup', 'ftp', '2024-09-15 03:00:00');

-- Tabla de IPs y servicios internos
CREATE TABLE IF NOT EXISTS network_inventory (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hostname VARCHAR(100),
    ip_address VARCHAR(20),
    service VARCHAR(50),
    notes VARCHAR(200)
);

INSERT INTO network_inventory (hostname, ip_address, service, notes) VALUES
('fw-central', '100.70.9.1', 'firewall', 'Puerta de enlace principal'),
('web-dmz', '192.168.57.10', 'http/ftp', 'Servidor web público'),
('srv-interno', '192.168.58.10', 'mysql/smb', 'Servidor interno de datos'),
('srv-backup', '192.168.58.11', 'ftp', 'Servidor de copias de seguridad nocturnas');

SQL

 echo "[internal-server] data completado."

