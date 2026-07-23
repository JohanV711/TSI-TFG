# 6. Conclusiones y advertencia legal

## 6.1 Conclusiones

El **Bloque 4 — Insecure Network Lab** ha demostrado de forma práctica que un conjunto de malas prácticas de configuración, aparentemente aisladas, se encadenan para permitir el compromiso total de una infraestructura corporativa.

### 6.1.1 Resumen del compromiso

Partiendo de una máquina atacante externa, se ha conseguido:

1. **Reconocer** todos los servicios y hosts de la DMZ y la red interna mediante escaneos no detectados.
2. **Acceder a la DMZ** a través de HTTP inseguro, FTP anónimo y Telnet sin cifrado, obteniendo credenciales y el mapa de red.
3. **Comprometer la red interna** mediante fuerza bruta SSH, acceso sin contraseña a MySQL y Samba como invitado.
4. **Ejecutar ARP spoofing** y capturar tráfico en texto claro sin que el firewall lo impidiera.
5. **Pivotar desde la DMZ** hasta el servidor interno, reutilizando credenciales.
6. **Exfiltrar datos sensibles** (base de datos corporativa, archivos confidenciales) sin generar logs ni alertas.

### 6.1.2 Contraste con el Bloque 3 (red segura)

| Medida de seguridad | Bloque 3 (Seguro) | Bloque 4 (Inseguro) | Efectividad |
|---------------------|-------------------|---------------------|-------------|
| Firewall con filtrado real | OPNsense con reglas restrictivas | iptables con ACCEPT global | Bloquea accesos no autorizados |
| Segmentación efectiva | 4 zonas aisladas con políticas DROP | 3 segmentos sin restricción | Contiene el movimiento lateral |
| IDS/IPS | Suricata activo con reglas | Sin IDS, sin logs | Detecta y alerta de escaneos |
| Cifrado de comunicaciones | WireGuard, DNS over TLS | Telnet, FTP, HTTP sin cifrar | Protege credenciales en tránsito |
| Autenticación robusta | Certificados, contraseñas seguras | Credenciales débiles y texto plano | Impide fuerza bruta y reutilización |
| Seguridad en servicios | MySQL con autenticación, Samba controlado | MySQL sin contraseña, Samba invitado | Protege los datos almacenados |
| Bastionado de servidores | Firewall local (OPNsense), cabeceras seguras | ufw desactivado, ServerTokens Full | Reduce la superficie de exposición |

Cada ataque exitoso del Bloque 4 habría sido **bloqueado o detectado** por al menos una de las medidas implementadas en el Bloque 3.

### 6.1.3 Lecciones aprendidas

- **La seguridad en profundidad no es opcional.** Un solo fallo (firewall sin filtrado) puede ser suficiente para iniciar el compromiso, pero una cadena de fallos lo convierte en inevitable.
- **El principio de mínimo privilegio debe aplicarse siempre.** MySQL sin contraseña, Samba como invitado y paneles de administración sin autenticación son regalos para el atacante.
- **Las credenciales nunca deben almacenarse en texto plano.** Todos los archivos (`passwords.txt`, `credentials.txt`, `config_backup.txt`) actuaron como un mapa del tesoro.
- **El tráfico debe cifrarse.** Telnet, FTP y HTTP permitieron capturar credenciales con un simple `tcpdump`.
- **Sin logs no hay trazabilidad.** La exfiltración de datos pasó completamente desapercibida.
- **La educación y la validación continua de la configuración son la primera línea de defensa.** Muchas de estas malas prácticas existen en entornos reales por desconocimiento, prisas o falta de revisión.

### 6.1.4 Aplicabilidad al TFG

Este bloque proporciona la **evidencia empírica** que respalda el capítulo 7 de la memoria. Los escenarios ejecutados demuestran que las malas prácticas descritas teóricamente en el trabajo tienen consecuencias reales y medibles. Al contrastar ambos laboratorios (Bloque 3 y Bloque 4), el lector puede apreciar el valor tangible de cada medida de seguridad propuesta.

---

## 6.2 Advertencia y limitaciones de uso

### ⚠️ Naturaleza del laboratorio

Este laboratorio contiene **configuraciones deliberadamente inseguras** diseñadas exclusivamente para fines educativos y de investigación en seguridad informática.

### Restricciones de uso

1. **Uso exclusivamente educativo.**
   Este entorno está destinado al aprendizaje de técnicas de seguridad ofensiva y defensiva en el contexto del TFG *"Configuración de redes virtuales seguras con OPNsense"*. No debe utilizarse con otros fines.

2. **Ejecución en entornos aislados.**
   El laboratorio debe desplegarse únicamente en entornos controlados y aislados (VirtualBox con redes internas `intnet`). No debe conectarse a redes de producción, corporativas o domésticas.

3. **No conectar a redes externas.**
   Durante las prácticas, las máquinas virtuales no deben tener acceso a Internet ni a ninguna red externa al laboratorio. La interfaz NAT de Vagrant solo debe usarse durante el aprovisionamiento inicial.

4. **No desplegar en producción.**
   Ninguna de las configuraciones aquí documentadas debe utilizarse en entornos reales. Hacerlo comprometería gravemente la seguridad de los sistemas.

5. **Responsabilidad del usuario.**
   El autor del TFG y la universidad no se hacen responsables del uso indebido de este laboratorio. Quien lo ejecute asume la plena responsabilidad de hacerlo en un entorno apropiado y conforme a la legislación vigente.

6. **Cumplimiento legal.**
   El uso de las técnicas de ataque descritas en este documento contra sistemas sin autorización expresa del propietario es ilegal y puede constituir un delito según el Código Penal español (artículos 197, 264 y concordantes) y legislaciones internacionales.

<br>
<table style="width: 100%; border: none;">
  <tr>
    <td style="text-align: left; border: none; padding: 0;">
      <a href="06-solucion-problemas.md">← Anterior</a>
    </td>
    <td style="text-align: center; border: none; padding: 0;">
      <a href="../README.md">Volver al índice</a>
    </td>
    <td style="text-align: right; border: none; padding: 0;">
      <span style="color: #999;">Fin de la documentación</span>
    </td>
  </tr>
</table>
