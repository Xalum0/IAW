# Configuración de Gunicorn para la API de la radio (UD5, apartado 9.2). Se aplica con: ./practica.sh recargar
bind = "0.0.0.0:8000"
accesslog = "/var/log/radio/gunicorn-acceso.log"
errorlog = "/var/log/radio/gunicorn-errores.log"

# ✍️ B3 · ¿Cuántos workers? El servidor de producción de Radio Marea tiene 3 CPU (no las de tu ordenador).
#         Usa la regla de la UD5 y escribe el número (con un comentario que diga de dónde sale).
workers = 1
