# API de Radio Marea: los podcasts y el estudio, en JSON (Flask detrás de Gunicorn, detrás de Nginx).
# Lee su configuración del entorno (servidor/radio.env, al arrancar). Si cambias algo: ./practica.sh recargar
import os

import pymysql
from flask import Flask, abort, jsonify, request, session
from werkzeug.middleware.proxy_fix import ProxyFix

app = Flask(__name__)
app.json.ensure_ascii = False                               # las tildes, tal cual en el JSON
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1)   # 👀 se fía de UNA capa de proxy: nuestro Nginx

# ✍️ B2 · La llave de las sesiones (UD5, apartado 7.3). Así viene: escrita aquí, corta y conocida por todos.
#         Que salga del entorno (SECRET_KEY, en servidor/radio.env). Y si no está, que la API no arranque.
app.secret_key = "cambiame"


# 👀 Datos de prueba, para el bloque B (todavía sin base de datos). En el C3 dejan de usarse.
PODCASTS_DE_PRUEBA = [
    {"id": 1, "titulo": "Las corvinas de octubre (prueba)", "programa": "Cocina de lonja", "minutos": 28},
    {"id": 2, "titulo": "Especial rock andaluz (prueba)", "programa": "Mareas de rock", "minutos": 58},
    {"id": 3, "titulo": "El faro y sus fareros (prueba)", "programa": "Faro de medianoche", "minutos": 45},
]


# ✍️ C2 · La conexión con MariaDB (UD6, apartado 5.2): host, base, usuario y contraseña, del entorno (radio.env).
#         Cada fila, un diccionario. Nada escrito a mano.
def conectar():
    raise RuntimeError("Sin hacer: conectar() (C2)")


# ✍️ C3 · Los podcasts de la tabla podcasts, del más nuevo al más viejo, con id, titulo, programa y minutos.
#         Si buscar no está vacío, solo los que lo llevan en el título (LIKE). Lo escribe el oyente: consulta preparada.
def leer_podcasts(buscar=""):
    return [p for p in PODCASTS_DE_PRUEBA if buscar.lower() in p["titulo"].lower()]


@app.route("/api/salud")
def salud():
    # 👀 Si contesta, Gunicorn funciona. «bd» dice con qué usuario entra la API en MariaDB (o por qué no puede).
    try:
        with conectar() as c, c.cursor() as cur:
            cur.execute("SELECT CURRENT_USER() AS yo")
            bd = cur.fetchone()["yo"]
    except Exception as e:                                  # sin base de datos todavía: la API sigue viva
        bd = f"sin base de datos ({e})"
    return jsonify({"ok": True, "bd": bd})


@app.route("/api/quien")
def quien():
    # 👀 Lo que la API sabe del oyente. Sin las cabeceras X-Forwarded-* de Nginx, cree que el oyente es Nginx y que entró por http.
    return jsonify({"ip": request.remote_addr, "esquema": request.scheme, "host": request.host})


@app.route("/api/podcasts")
def podcasts():
    # 👀 La lista, para la app del móvil: /api/podcasts  o  /api/podcasts?buscar=faro
    return jsonify(leer_podcasts(request.args.get("buscar", "")))


# ✍️ B4 · Un podcast: /api/podcasts/2 (UD5, apartados 5 y 8).
#         - Si existe: ese podcast en JSON (búscalo en lo que da leer_podcasts()).
#         - Si no existe: {"error": "No existe ese podcast"} con un 404, también en JSON.
#         - Solo GET: con cualquier otro método, 405 (eso lo hace Flask solo, si la ruta está bien declarada).
#         - /api/podcasts/abc (no es un número) también es un 404.


@app.route("/api/entrar", methods=["POST"])
def entrar():
    # 👀 El locutor entra con la contraseña del estudio (LOCUTOR_CLAVE, en radio.env) y se lleva la «pulsera» (UD5, apartado 7).
    datos = request.get_json(silent=True) or {}
    if datos.get("clave") != os.environ.get("LOCUTOR_CLAVE"):
        return jsonify({"error": "Contraseña incorrecta"}), 401
    session["locutor"] = datos.get("nombre", "locutor")
    return jsonify({"ok": True, "hola": session["locutor"]})


@app.route("/api/estudio")
def estudio():
    # ✍️ B2 · El panel del estudio: solo para quien ha entrado (lleva la pulsera, es decir, «locutor» en la sesión).
    #         Sin pulsera: {"error": "Primero, POST /api/entrar"} con un 401. Ahora entra cualquiera.
    return jsonify({"locutor": session.get("locutor"), "siguiente": "Noticias del puerto, a las 13:00"})
