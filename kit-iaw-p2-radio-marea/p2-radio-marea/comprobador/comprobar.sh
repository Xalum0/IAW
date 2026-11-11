#!/usr/bin/env bash
# Comprobador de la Práctica 2 de IAW (Radio Marea). Se lanza con: ./practica.sh comprobar [A|B|C]
# La web y la API se comprueban con curl DESDE «cliente», como un oyente, pasando por Nginx. La base de datos, como root
# DENTRO de su servidor. Las copias, desde «admin» (el ordenador del administrador).
# No da la solución: dice qué caso falla, qué ha salido y, si es una trampa conocida, cuál es.
# Las pruebas son del profesor: se corrige con esta copia original, así que cambiarla no sirve de nada.
set -u   # sin pipefail: «… | grep -q» corta la tubería al encontrar y daría falsos fallos
cd "$(dirname "$0")/.."
SOLO=$(tr '[:lower:]' '[:upper:]' <<<"${1:-}")
URL=https://radio.iaw.local
ROOTPW=raiz-de-la-practica
export YO="${YO:-$(id -u):$(id -g)}"

V=$'\e[32m'; R=$'\e[31m'; A=$'\e[33m'; G=$'\e[90m'; N=$'\e[1m'; X=$'\e[0m'
case "$SOLO" in ""|A|B|C) ;; *) echo "Uso: ./practica.sh comprobar [A|B|C]"; exit 1 ;; esac

# ── Acceso a los contenedores ────────────────────────────────────────────────
web()    { docker compose exec -T cliente curl -sk --max-time 12 "$@" 2>/dev/null; }     # como un oyente, por Nginx
codigo() { web -o /dev/null -w '%{http_code}' "$@"; }
cabeceras() { web -o /dev/null -D - "$@" | tr -d '\r'; }
sql()    { docker compose exec -T db mariadb -uroot -p"$ROOTPW" -N -B -e "$1" 2>/dev/null; }   # como root, en localhost
envvar() { sed -n "s/^$1=//p" servidor/radio.env 2>/dev/null | tail -1 | tr -d '\r'; }
# ¿Se ejecutan ya los .php? (sin el A1.1, el resto de la web no se puede comprobar)
PHP_VA=-1
php_va() {
    [ "$PHP_VA" = -1 ] && { web "$URL/salud.php" | grep -q 'PHP-FPM responde · PHP [0-9]' && PHP_VA=1 || PHP_VA=0; }
    [ "$PHP_VA" = 1 ] || MSG="Primero el A1.1: los .php todavía no se ejecutan en PHP-FPM."
    [ "$PHP_VA" = 1 ]
}
error_api() { grep -E 'Error|error:|KeyError|pymysql' logs/gunicorn-errores.log 2>/dev/null | grep -v '\[INFO\]' | tail -1 | cut -c1-170; }

# ── 0 · Que esté arrancado, y aplicar tus cambios (igual que ./practica.sh recargar) ──
if ! docker compose ps --status running -q cliente 2>/dev/null | grep -q .; then
    echo "${R}✘ La práctica no está arrancada.${X} Primero: ${N}./practica.sh arrancar${X}"; exit 1
fi
NGINX_OK=1
if ! salida=$(docker compose exec -T nginx nginx -t 2>&1); then
    NGINX_OK=0
    echo "${R}✘ radio.conf tiene un error y Nginx no lo acepta (nginx -t):${X}"
    grep -E 'emerg|error' <<<"$salida" | sed 's/^/    /'
    echo "  ${A}💡 La línea viene al final («radio.conf:NN»). Suele ser un ; que falta o una llave { } sin cerrar.${X}"
    echo "  ${G}Nginx sigue funcionando con la configuración de ANTES: lo de abajo no ve tu último cambio.${X}"
else
    docker compose exec -T nginx nginx -s reload >/dev/null 2>&1
fi
DESDE=$(date +%s)
docker compose restart php app >/dev/null 2>&1
API_OK=0
for _ in $(seq 1 24); do
    [ "$(docker compose exec -T nginx curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://app:8000/api/salud 2>/dev/null)" = 200 ] && { API_OK=1; break; }
    sleep 0.5
done
if [ "$API_OK" = 0 ]; then
    echo "${R}✘ La API no arranca después de reiniciarla.${X} Esto dice Python (docker compose logs app):"
    docker compose logs --no-log-prefix --since "$DESDE" app 2>&1 | grep -vE '\[INFO\]|<frozen|^Traceback' | tail -n 5 | sed 's/^/    /'
    echo "  ${A}💡 La última línea dice qué pasa y la de «File …, line NN», dónde. ¿KeyError: 'SECRET_KEY'? Falta en radio.env (B2).${X}"
fi
[ "$NGINX_OK" = 1 ] && echo "${G}→ nginx -t ✔ · Nginx recargado · PHP y la API reiniciados (lo mismo que ./practica.sh recargar)${X}"

# ── Resultados ────────────────────────────────────────────────────────────────
ok=0; total=0; bok=0; btot=0; primero_dado=0; ejemplos=0
MSG=""; TRAMPA=""; ACTUAL=""
declare -A EMPEZAR=(
  [A1.1]="En radio.conf, una location para lo que acaba en .php (con ~), y dentro las líneas del apartado 2.1 de la UD4. El contenedor de PHP se llama php."
  [A1.2]="La directiva index dice qué fichero buscar cuando piden una carpeta (/)."
  [A1.3]="Dentro de la location de los .php: try_files \$uri =404; (si el fichero no existe, ni se le pregunta a PHP)."
  [A2.1]="servidor/php/produccion.ini: las directivas del apartado 6 de la UD4. Después, ./practica.sh recargar."
  [A2.2]="display_errors, log_errors y error_log = /var/log/radio/php-errores.log"
  [A2.3]="disable_functions = … con las seis funciones separadas por comas, sin espacios."
  [A3.1]="En inc/util.php, e() tiene que devolver el texto escapado: la función de la UD4 que convierte < en &lt;."
  [A3.2]="La misma función escapa también las comillas (\" → &quot;). Mira sus parámetros en el apartado 5.2 de la UD4."
  [A4.1]="Una location exacta (=) para /diagnostico.php con deny all;"
  [A4.2]="Una location de prefijo para /inc/ que gane a las expresiones regulares (^~), con deny all;"
  [B1.1]="En radio.conf, location /api/ { proxy_pass http://app:8000; … } (UD5, apartado 2.1)."
  [B1.2]="Las tres líneas proxy_set_header del apartado 2.1 de la UD5: Host, X-Forwarded-For y X-Forwarded-Proto."
  [B2.1]="Al principio de estudio(): if \"locutor\" not in session: return jsonify({…}), 401"
  [B2.2]="app.secret_key = os.environ[\"SECRET_KEY\"], y en radio.env una SECRET_KEY generada con secrets.token_hex(32) (UD5, 7.3)."
  [B2.3]="Si la llave sigue siendo «cambiame», cualquiera fabrica pulseras. Cámbiala por la del entorno (B2.2)."
  [B3.1]="workers = 2 × CPU + 1, con las CPU del servidor de producción (3), no las de tu ordenador."
  [B4.1]="@app.route(\"/api/podcasts/<int:id>\") y una función que recorre leer_podcasts() buscando ese id."
  [B4.2]="Si el bucle no lo encuentra: return jsonify({\"error\": \"No existe ese podcast\"}), 404"
  [B4.3]="Una ruta sin methods= solo acepta GET (y HEAD). No añadas POST."
  [C1.1]="En sql/usuarios.sql, copia el ejemplo 👀 de radio_copias y cámbialo: nombre, contraseña. ¿Qué permisos necesita para solo leer? Después: ./practica.sh sql"
  [C1.2]="DROP USER IF EXISTS y el root que entra desde cualquier sitio: 'root'@'%'."
  [C2.1]="En servidor/radio.env: DB_USER=radio_web y DB_PASS= la contraseña del C1.1, sin espacios ni comillas."
  [C2.2]="conectar() en web/inc/db.php: \$cfg = leer_env('/etc/radio/radio.env'); el DSN con \$cfg['DB_HOST'] y \$cfg['DB_NAME']… (UD6, 5.1 y 6)."
  [C2.3]="conectar() en app/app.py: pymysql.connect(host=os.environ[\"DB_HOST\"], …) (UD6, 5.2)."
  [C2.4]="Busca las contraseñas en web/ y en app/: no pueden aparecer, ni en un comentario. Solo en radio.env."
  [C3.1]="programas() en web/inc/datos.php: \$st = conectar()->prepare('SELECT … WHERE dia = ? ORDER BY hora'); \$st->execute([\$dia]);"
  [C3.2]="El día va APARTE (el ? y el execute), nunca pegado dentro del SQL."
  [C3.3]="leer_podcasts() en app/app.py: cur.execute(\"… WHERE titulo LIKE %s ORDER BY fecha DESC\", (\"%\" + buscar + \"%\",))"
  [C4.1]="Los cinco pasos de servidor/copia.sh, como el script del apartado 10.2 de la UD6, pero con COPIAS_USER y COPIAS_PASS. Pruébalo: ./practica.sh copia"
  [C4.2]="El script no lleva contraseñas: las saca de radio.env, que carga con el punto (paso 1)."
)

bloque() {  # bloque X "título"
    cierre_bloque
    ACTUAL=$1
    toca "$1" && { echo; echo "${N}Bloque $1 · $2${X}"; }
}
cierre_bloque() {
    if [ -n "$ACTUAL" ] && toca "$ACTUAL"; then echo "  ${G}— bloque $ACTUAL: $bok de $btot${X}"; fi
    bok=0; btot=0
}
toca() { [ -z "$SOLO" ] || [ "$SOLO" = "$1" ]; }
check() {  # check ID TIPO "nombre" funcion
    local id=$1 tipo=$2 nombre=$3 res=0; shift 3
    toca "$ACTUAL" || return 0
    total=$((total+1)); btot=$((btot+1)); MSG=""; TRAMPA=""
    [ "$tipo" = "👀" ] && ejemplos=$((ejemplos+1))
    if "$@"; then
        res=1; ok=$((ok+1)); bok=$((bok+1)); printf '  %s✔%s %-5s %s %s\n' "$V" "$X" "$id" "$tipo" "$nombre"
    else
        printf '  %s✘%s %-5s %s %s\n' "$R" "$X" "$id" "$tipo" "$nombre"
        [ -n "$MSG" ] && printf '          %s\n' "$MSG"
        [ -n "$TRAMPA" ] && printf '          %s⚠️  Error típico: %s%s\n' "$A" "$TRAMPA" "$X"
        if [ -n "${EMPEZAR[$id]:-}" ] && { [ -n "$SOLO" ] || [ "$primero_dado" = 0 ]; }; then
            printf '          %s💡 Para empezar: %s%s\n' "$A" "${EMPEZAR[$id]}" "$X"
            [ -z "$SOLO" ] && primero_dado=1
        fi
    fi
    [ -n "${RESULTADOS:-}" ] && printf '%s\t%s\t%s\n' "$id" "$tipo" "$res" >> "$RESULTADOS"   # para el corrector del profesor
    return 0
}

# ═════════════ Bloque A · La web en PHP (UD4) ═════════════
a_https() {
    local h; h=$(web -o /dev/null -w '%{http_code} %{redirect_url}' http://radio.iaw.local/parrilla.php)
    MSG="Por HTTP: $h"; [[ $h == "301 https://radio.iaw.local/parrilla.php" ]]
}
a_css() { [ "$(codigo "$URL/estilo.css")" = 200 ]; }
a_php() {
    local c t b
    c=$(codigo "$URL/salud.php"); t=$(web -o /dev/null -w '%{content_type}' "$URL/salud.php"); b=$(web "$URL/salud.php")
    MSG="/salud.php da $c ($t)."
    case "$c" in
        200) grep -q '<?php' <<<"$b" && { MSG="/salud.php se descarga con el código dentro: Nginx no se lo pasa a PHP."; TRAMPA="no hay location ~ \\.php\$, o no casa con la ruta."; return 1; } ;;
        404) grep -q 'File not found' <<<"$b" && TRAMPA="«File not found.» lo dice PHP: no le llega bien la ruta. ¿Falta fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;?" ;;
        502) TRAMPA="502: nadie contesta en fastcgi_pass. ¿El nombre del contenedor (php) y el puerto (9000)? Mira logs/radio_error.log." ;;
    esac
    grep -q 'PHP-FPM responde · PHP [0-9]' <<<"$b"
}
a_portada() {
    local b; b=$(web "$URL/")
    MSG="https://radio.iaw.local/ da $(codigo "$URL/")."
    grep -q '<?php' <<<"$b" && { MSG="La portada se descarga con el código PHP dentro."; return 1; }
    grep -q 'En directo' <<<"$b" || { [ "$(codigo "$URL/")" = 403 ] && TRAMPA="403 en /: Nginx busca index.html, que no existe, y no puede listar la carpeta. La directiva index."; return 1; }
}
a_404() {
    php_va || return 1
    local c b; c=$(codigo "$URL/no-existe.php"); b=$(web "$URL/no-existe.php")
    MSG="/no-existe.php da $c."
    [ "$c" = 404 ] || return 1
    grep -q 'File not found' <<<"$b" && { MSG="Da 404, pero lo dice PHP («File not found.»): Nginx le ha pasado un fichero que no existe."; TRAMPA="falta try_files \$uri =404; dentro de la location de los .php."; return 1; }
    grep -qi 'nginx' <<<"$b"
}
a_expose() {
    php_va || return 1
    local h; h=$(cabeceras "$URL/salud.php" | grep -i '^x-powered-by')
    MSG="La web dice: ${h:-…}"; [ -z "$h" ] && [ "$(codigo "$URL/salud.php")" = 200 ]
}
a_errores() {
    local c b antes
    php_va || return 1
    antes=$({ wc -c < logs/php-errores.log; } 2>/dev/null || echo 0)
    c=$(codigo "$URL/error.php"); b=$(web "$URL/error.php")
    if grep -q 'configuracion-que-no-existe' <<<"$b"; then
        MSG="El oyente ve el error: $(grep -o 'Failed[^<]*' <<<"$b" | head -1 | cut -c1-110)…"; TRAMPA="display_errors = Off (y ./practica.sh recargar: PHP-FPM lee su .ini al arrancar)."; return 1
    fi
    [ "$c" = 500 ] || { MSG="/error.php da $c (tiene que ser 500, sin detalles)."; return 1; }
    sleep 0.3
    tail -c +"$((antes+1))" logs/php-errores.log 2>/dev/null | grep -q 'configuracion-que-no-existe' || { MSG="El oyente no ve el error, pero tampoco está en logs/php-errores.log."; TRAMPA="log_errors = On y error_log = /var/log/radio/php-errores.log (es tu carpeta logs/)."; return 1; }
}
a_disable() {
    php_va || return 1
    local d f falta=""
    d=$(docker compose exec -T php php -r 'echo ini_get("disable_functions");' 2>/dev/null)
    for f in exec shell_exec system passthru proc_open popen; do grep -qE "(^|,) *$f *(,|$)" <<<"$d" || falta="$falta $f"; done
    MSG="disable_functions = «$d». Falta:$falta"; [ -z "$falta" ]
}
a_xss() {
    php_va || return 1
    local b
    b=$(web -G "$URL/saludos.php" --data-urlencode 'nombre=<script>alert(1)</script>' --data-urlencode 'mensaje=5 < 7 y <b>hola</b>')
    if grep -q '<script>alert' <<<"$b"; then MSG="El <script> del nombre llega tal cual al navegador: se ejecutaría."; return 1; fi
    if ! grep -q '&lt;script&gt;' <<<"$b"; then
        MSG="El <script> no se ve, pero tampoco escapado (&lt;script&gt;)."
        grep -q 'alert(1)' <<<"$b" && TRAMPA="strip_tags() BORRA las etiquetas, no las escapa: «5 < 7» también se estropea. Escapar es convertir < en &lt;."
        return 1
    fi
    grep -q '5 &lt; 7 y &lt;b&gt;hola&lt;/b&gt;' <<<"$b" || { MSG="El nombre se escapa, pero el mensaje no sale bien: «$(grep -o '«[^»]*»' <<<"$b" | head -1)»."; return 1; }
}
a_atributo() {
    php_va || return 1
    local b; b=$(web -G "$URL/saludos.php" --data-urlencode 'nombre=Ana" autofocus onfocus="alert(2)' --data-urlencode 'mensaje=hola')
    if grep -q 'onfocus="alert(2)' <<<"$b"; then
        MSG="En value=\"…\" la comilla del nombre cierra el atributo: el oyente puede añadir onfocus=… y ejecutar JavaScript."
        grep -q '\\"' <<<"$b" && TRAMPA="addslashes() pone \\ delante, pero para el HTML la comilla sigue cerrando el atributo."
        return 1
    fi
    grep -q 'Ana&quot; autofocus' <<<"$b" || { MSG="El nombre no sale en el formulario como Ana&quot; autofocus…"; return 1; }
}
a_diag() {
    php_va || return 1
    local c b; c=$(codigo "$URL/diagnostico.php"); b=$(web "$URL/diagnostico.php")
    MSG="/diagnostico.php da $c."
    grep -qi 'phpinfo\|PHP Version' <<<"$b" && TRAMPA="si pusiste «location /diagnostico.php», es de prefijo y la ~ \\.php\$ le gana: con = (exacta) gana siempre."
    [ "$c" = 403 ]
}
a_inc() {
    php_va || return 1
    local c1 c2; c1=$(codigo "$URL/inc/db.php"); c2=$(codigo "$URL/inc/util.php")
    MSG="/inc/db.php da $c1 y /inc/util.php da $c2 (los dos, 403)."
    { [ "$c1" = 200 ] || [ "$c2" = 200 ]; } && TRAMPA="con «location /inc/» (prefijo normal) gana la ~ \\.php\$ y PHP lo ejecuta. Con ^~ el prefijo gana a las ~."
    [ "$c1" = 403 ] && [ "$c2" = 403 ]
}

bloque A "La web en PHP (UD4)"
check A0.1 "👀" "Por HTTP, a HTTPS (301)" a_https
check A0.2 "👀" "Nginx sirve estilo.css por HTTPS" a_css
check A1.1 "✍️" "Los .php se ejecutan en PHP-FPM (salud.php)" a_php
check A1.2 "✍️" "La portada (/) es index.php" a_portada
check A1.3 "✍️" "Un .php que no existe: el 404 de Nginx" a_404
check A2.1 "✍️" "La web no dice qué PHP usa (sin X-Powered-By)" a_expose
check A2.2 "✍️" "El oyente no ve los errores; tú sí, en logs/php-errores.log" a_errores
check A2.3 "✍️" "PHP no puede ejecutar órdenes del sistema (disable_functions)" a_disable
check A3.1 "✍️" "Saludos: lo que escribe el oyente sale escapado" a_xss
check A3.2 "✍️" "Saludos: también dentro de value=\"…\"" a_atributo
check A4.1 "✍️" "diagnostico.php: 403" a_diag
check A4.2 "✍️" "La carpeta inc/: 403" a_inc

# ═════════════ Bloque B · La API en Python (UD5) ═════════════
JAR=/tmp/pulsera-comprobador
b_dentro() { docker compose exec -T nginx curl -s --max-time 5 http://app:8000/api/salud 2>/dev/null | grep -q '"ok": *true'; }
b_salud() {
    local c t b; c=$(codigo "$URL/api/salud"); t=$(web -o /dev/null -w '%{content_type}' "$URL/api/salud"); b=$(web "$URL/api/salud")
    MSG="/api/salud por Nginx da $c ($t)."
    if [ "$c" = 404 ]; then
        if grep -q 'requested URL was not found' <<<"$b"; then TRAMPA="el 404 lo da Flask, no Nginx: le llega otra ruta. ¿proxy_pass con / al final? Así quita el /api/ del principio."
        else TRAMPA="el 404 lo da Nginx: no hay location /api/, o no casa."; fi
    fi
    [ "$c" = 502 ] && TRAMPA="502: nadie contesta en proxy_pass. ¿http://app:8000? Mira logs/radio_error.log."
    [ "$c" = 200 ] && [[ $t == application/json* ]]
}
b_quien() {
    local j ipc ip esq host
    j=$(web "$URL/api/quien"); ipc=$(docker compose exec -T cliente hostname -i 2>/dev/null | awk '{print $1}')
    ip=$(sed -n 's/.*"ip": *"\([^"]*\)".*/\1/p' <<<"$j"); esq=$(sed -n 's/.*"esquema": *"\([^"]*\)".*/\1/p' <<<"$j"); host=$(sed -n 's/.*"host": *"\([^"]*\)".*/\1/p' <<<"$j")
    [ -n "$j" ] || { MSG="/api/quien no contesta (primero el B1.1)."; return 1; }
    MSG="La API cree que: host=$host · ip=$ip · esquema=$esq (el oyente es $ipc, pidió radio.iaw.local y entró por https)."
    [ "$host" = radio.iaw.local ] && [ "$ip" = "$ipc" ] && [ "$esq" = https ]
}
b_puerta() {
    local sin con clave; clave=$(envvar LOCUTOR_CLAVE)
    sin=$(codigo "$URL/api/estudio")
    docker compose exec -T cliente rm -f $JAR >/dev/null 2>&1
    web -c $JAR -o /dev/null -H 'Content-Type: application/json' -d "{\"clave\": \"$clave\", \"nombre\": \"comprobador\"}" "$URL/api/entrar"
    con=$(web -b $JAR -o /dev/null -w '%{http_code}' "$URL/api/estudio")
    MSG="Sin entrar: $sin (tiene que ser 401) · después de entrar: $con (tiene que ser 200)."
    [ "$con" = 500 ] && TRAMPA="500 al usar la sesión: ¿SECRET_KEY vacía en radio.env? Mira ./practica.sh logs."
    [ "$sin" = 401 ] && [ "$con" = 200 ]
}
b_llave() {
    local k; k=$(envvar SECRET_KEY)
    if grep -qE '^[^#]*secret_key *= *["'"'"']' app/app.py; then MSG="En app.py la llave sigue escrita entre comillas."; return 1; fi
    [ ${#k} -ge 32 ] || { MSG="SECRET_KEY en radio.env tiene ${#k} caracteres (mínimo 32, al azar)."; return 1; }
    [ "$k" != cambiame ] && grep -q 'os.environ' <<<"$(grep -E '^[^#]*secret_key' app/app.py)" || { MSG="app.secret_key no sale de os.environ."; return 1; }
}
b_falsa() {
    local pulsera c
    pulsera=$(docker compose exec -T app python3 -c 'from flask import Flask; from flask.sessions import SecureCookieSessionInterface as S
a = Flask("x"); a.secret_key = "cambiame"; print(S().get_signing_serializer(a).dumps({"locutor": "intruso"}))' 2>/dev/null | tr -d '\r')
    c=$(web -o /dev/null -w '%{http_code}' -b "session=$pulsera" "$URL/api/estudio")
    MSG="Con una pulsera fabricada con la llave «cambiame», /api/estudio da $c (tiene que ser 401)."
    [ "$(codigo "$URL/api/estudio")" = 401 ] || { MSG="$MSG Primero cierra la puerta (B2.1)."; return 1; }
    [ "$c" = 401 ]
}
b_workers() {
    local n; n=$(docker compose exec -T app ps -C gunicorn --no-headers 2>/dev/null | wc -l)
    n=$((n-1)); MSG="Gunicorn tiene $n workers (más el proceso jefe)."
    [ "$n" -gt 7 ] && TRAMPA="¿has usado las CPU de tu ordenador (nproc, cpu_count)? Las del servidor de producción son 3."
    [ "$n" = 7 ]
}
b_uno() {
    local c j; c=$(codigo "$URL/api/podcasts/2"); j=$(web "$URL/api/podcasts/2")
    MSG="/api/podcasts/2 da $c: $(tr -d '\n' <<<"$j" | sed 's/<[^>]*>/ /g; s/  */ /g' | cut -c1-120)"
    [ "$c" = 200 ] && grep -q '"id": *2[,}]' <<<"$j" && grep -q '"titulo"' <<<"$j" && ! grep -q '^\[' <<<"$j"
}
b_404() {
    local c t c2; c=$(codigo "$URL/api/podcasts/99"); t=$(web -o /dev/null -w '%{content_type}' "$URL/api/podcasts/99"); c2=$(codigo "$URL/api/podcasts/abc")
    MSG="/api/podcasts/99 da $c ($t) · /api/podcasts/abc da $c2."
    [ "$c" = 200 ] && TRAMPA="un 200 con un error dentro no es un error: el código va después de la coma, jsonify({…}), 404"
    [ "$c" = 500 ] && MSG="$MSG En el log: $(error_api)"
    [ "$c" = 404 ] && [[ $t == application/json* ]] && [ "$c2" = 404 ]
}
b_405() {
    local c; c=$(codigo -X POST "$URL/api/podcasts/2"); MSG="POST /api/podcasts/2 da $c (tiene que ser 405)."
    [ "$c" = 200 ] && TRAMPA="si pones methods=[\"GET\", \"POST\"], aceptas un método que no hace falta."
    [ "$c" = 405 ]
}

bloque B "La API en Python (UD5)"
check B0.1 "👀" "La API responde por dentro (app:8000, sin pasar por Nginx)" b_dentro
check B1.1 "✍️" "/api/ llega a la API a través de Nginx (JSON)" b_salud
check B1.2 "✍️" "La API sabe quién es el oyente: su IP, el nombre y https" b_quien
check B2.1 "✍️" "El estudio: sin pulsera 401, con pulsera 200" b_puerta
check B2.2 "✍️" "La llave de las sesiones, en radio.env (larga), no en app.py" b_llave
check B2.3 "✍️" "Una pulsera fabricada con la llave de antes no sirve" b_falsa
check B3.1 "✍️" "Gunicorn con los workers del servidor de producción" b_workers
check B4.1 "✍️" "/api/podcasts/2: ese podcast, en JSON" b_uno
check B4.2 "✍️" "Un podcast que no existe: 404 en JSON" b_404
check B4.3 "✍️" "POST a un podcast: 405" b_405

# ═════════════ Bloque C · Los datos en MariaDB (UD6) ═════════════
MARCA="Prueba del comprobador $$"
permisos() { sql "SELECT GROUP_CONCAT(PRIVILEGE_TYPE ORDER BY PRIVILEGE_TYPE) FROM information_schema.SCHEMA_PRIVILEGES WHERE GRANTEE = '''$1''@''%''' AND TABLE_SCHEMA='radio'"; }
solo_en_radio() {
    [ "$(sql "SELECT COUNT(*) FROM information_schema.USER_PRIVILEGES WHERE GRANTEE = '''$1''@''%''' AND PRIVILEGE_TYPE<>'USAGE'")" = 0 ] &&
    [ "$(sql "SELECT COUNT(*) FROM information_schema.SCHEMA_PRIVILEGES WHERE GRANTEE = '''$1''@''%''' AND TABLE_SCHEMA<>'radio'")" = 0 ]
}
c_base() { [ "$(sql 'SELECT COUNT(*) FROM radio.programas')" -ge 20 ] 2>/dev/null && [ "$(sql 'SELECT COUNT(*) FROM radio.podcasts')" -ge 6 ] 2>/dev/null; }
c_web() {
    local hosts p
    hosts=$(sql "SELECT GROUP_CONCAT(Host) FROM mysql.user WHERE User='radio_web'")
    if [ -z "$hosts" ] || [ "$hosts" = NULL ]; then MSG="No existe el usuario radio_web. ¿Has aplicado el fichero? ./practica.sh sql"; return 1; fi
    grep -qw '%' <<<"$hosts" || { MSG="radio_web existe, pero desde: $hosts."; TRAMPA="la web y la API están en OTROS ordenadores (php, app): con 'localhost' no pueden entrar. Tiene que ser @'%'."; return 1; }
    solo_en_radio radio_web || { MSG="radio_web tiene permisos fuera de la base radio."; TRAMPA="ON *.* le da permiso en TODAS las bases del servidor. Tiene que ser ON radio.*"; return 1; }
    p=$(permisos radio_web); MSG="radio_web tiene en radio: ${p:-ningún permiso}."
    case ",$p," in *,INSERT,*|*,UPDATE,*|*,DELETE,*|*,DROP,*) TRAMPA="la web y la API solo leen: lo que no necesitan, no se les da (si alguien cuela una orden, no podrá cambiar nada)." ;; esac
    [ "$p" = SELECT ]
}
c_root() { local h; h=$(sql "SELECT GROUP_CONCAT(Host) FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1')"); MSG="root sigue entrando desde: $h"; [ -z "$h" ] || [ "$h" = NULL ]; }
c_env() {
    local u p r; u=$(envvar DB_USER); p=$(envvar DB_PASS)
    grep -qE '^DB_(USER|PASS) +=|^DB_(USER|PASS)= ' servidor/radio.env && { MSG="Hay espacios alrededor del = en radio.env."; TRAMPA="CLAVE=valor, todo junto: el espacio pasa a formar parte del valor."; return 1; }
    [ -n "$u" ] || { MSG="DB_USER está vacío en servidor/radio.env."; return 1; }
    [ "$u" = radio_web ] || { MSG="DB_USER=$u."; TRAMPA="la web y la API entran con SU usuario (radio_web), nunca con root."; return 1; }
    [ -n "$p" ] || { MSG="DB_PASS está vacío en servidor/radio.env."; return 1; }
    r=$(docker compose exec -T admin mariadb -h db -u "$u" -p"$p" radio -N -e 'SELECT 1' 2>&1 | tr -d '\r')
    MSG="Con esos datos, MariaDB dice: $(tr -d '\n' <<<"$r" | cut -c1-150)"; [ "$r" = 1 ]
}
c_php() {
    php_va || return 1
    local b yo; b=$(web "$URL/parrilla.php"); yo=$(grep -o 'Datos: [^<]*' <<<"$b" | head -1 | cut -c1-170)
    MSG="Pie de la parrilla → «${yo:-no sale}»"
    grep -q 'conectada como root' <<<"$b" && TRAMPA="la web entra como root: el usuario sale de radio.env, no escrito en db.php."
    grep -q 'conectada como radio_web@%' <<<"$b"
}
c_py() {
    local j bd; j=$(web "$URL/api/salud"); bd=$(sed -n 's/.*"bd": *"\([^"]*\)".*/\1/p' <<<"$j" | cut -c1-170)
    MSG="/api/salud → bd: «${bd:-no contesta}»"
    grep -q 'KeyError' <<<"$bd" && TRAMPA="os.environ[\"…\"] de una variable que no está en radio.env (o la API no se ha reiniciado: ./practica.sh recargar)."
    [ "$bd" = 'radio_web@%' ]
}
c_secretos() {
    local s v donde=""
    [ "$(sed -n 's/.*"bd": *"\([^"]*\)".*/\1/p' <<<"$(web "$URL/api/salud")")" = 'radio_web@%' ] && web "$URL/parrilla.php" | grep -q 'conectada como radio_web@%' ||
        { MSG="Primero el C2.2 y el C2.3: la web y la API tienen que conectar (sin contraseñas escritas)."; return 1; }
    for v in "$(envvar DB_PASS)" "$(envvar COPIAS_PASS)" "$(envvar SECRET_KEY)" "$(envvar LOCUTOR_CLAVE)" "$ROOTPW"; do
        [ -n "$v" ] || continue
        s=$(grep -rlF -- "$v" web app 2>/dev/null | head -2 | tr '\n' ' '); [ -n "$s" ] && donde="$donde $s"
    done
    MSG="Hay una contraseña escrita en:$donde"; [ -z "$donde" ]
}
c_parrilla() {
    php_va || return 1
    local b n
    sql "INSERT INTO radio.programas (dia, hora, nombre, locutor) VALUES ('martes', '23:59', '$MARCA', 'Comprobador')" >/dev/null
    b=$(web "$URL/parrilla.php?dia=martes"); n=$(grep -c '<tr><td>' <<<"$b")
    sql "DELETE FROM radio.programas WHERE nombre LIKE 'Prueba del comprobador%'" >/dev/null
    grep -q '(prueba)' <<<"$b" && { MSG="La parrilla sigue saliendo de los datos de prueba, no de la tabla programas."; return 1; }
    grep -q 'Uncaught\|Fatal' <<<"$b" && { MSG="La página da un error de PHP."; return 1; }
    MSG="La parrilla del martes tiene $n programas (con el que acabo de añadir, 5) y $(grep -qF "$MARCA" <<<"$b" && echo sí || echo no) sale el nuevo."
    grep -qF "$MARCA" <<<"$b" && [ "$n" = 5 ] && [ "$(grep -o '<tr><td>[0-9:]*' <<<"$b" | tail -1)" = '<tr><td>23:59' ]
}
c_inyeccion() {
    php_va || return 1
    local c b n
    c=$(codigo -G "$URL/parrilla.php" --data-urlencode "dia=lunes' OR '1'='1"); b=$(web -G "$URL/parrilla.php" --data-urlencode "dia=lunes' OR '1'='1"); n=$(grep -c '<tr><td>' <<<"$b")
    MSG="?dia=lunes' OR '1'='1 da $c y enseña $n programas (tiene que dar 200 y 0: no hay un día que se llame así)."
    [ "$n" -ge 20 ] && TRAMPA="inyección SQL: el día va pegado dentro del SQL y el OR '1'='1' trae toda la semana. Va aparte, con ? y execute."
    [ "$c" = 500 ] && TRAMPA="la comilla rompe el SQL: el día va pegado dentro. Va aparte, con ? y execute."
    [ "$c" = 200 ] && [ "$n" = 0 ] && [ "$(web "$URL/parrilla.php?dia=lunes" | grep -c '<tr><td>')" = 4 ]
}
c_api() {
    local j t c
    j=$(web "$URL/api/podcasts"); t=$(web -G "$URL/api/podcasts" --data-urlencode "buscar=faro")
    c=$(codigo -G "$URL/api/podcasts" --data-urlencode "buscar=%' OR '1'='1")
    grep -q '(prueba)' <<<"$j" && { MSG="La API sigue dando los podcasts de prueba, no los de la tabla podcasts."; return 1; }
    MSG="/api/podcasts → $(grep -o '"titulo": *"[^"]*"' <<<"$j" | head -1) … · ?buscar=faro → $(grep -o '"titulo"' <<<"$t" | wc -l) · ?buscar=%' OR '1'='1 → $c"
    [ "$c" = 500 ] && TRAMPA="la comilla rompe el SQL: buscar va pegado dentro (f-string). Va aparte, con %s y una tupla."
    [ "$(grep -o '"titulo"' <<<"$j" | wc -l)" -ge 6 ] || return 1
    grep -q '^\[ *{ *"\(id\|minutos\|programa\|titulo\)"' <<<"$(tr -d '\n' <<<"$j")" || return 1
    grep -o '"titulo": *"[^"]*"' <<<"$j" | head -1 | grep -q '"Atún de almadraba, paso a paso"' || { MSG="$MSG · El primero tiene que ser el más nuevo (ORDER BY fecha DESC)."; return 1; }
    [ "$(grep -o '"titulo"' <<<"$t" | wc -l)" = 1 ] && grep -q 'El faro y sus fareros' <<<"$t" && [ "$c" = 200 ] &&
        [ "$(web -G "$URL/api/podcasts" --data-urlencode "buscar=%' OR '1'='1" | tr -d ' \n')" = '[]' ]
}
c_copia() {
    local f salida n1 n2
    docker compose exec -T admin sh -c 'touch -d "2020-01-01 00:00" /copias/radio-20200101-000000.sql' >/dev/null 2>&1
    salida=$(docker compose exec -T admin timeout 20 sh /srv/servidor/copia.sh </dev/null 2>&1)
    [ $? = 0 ] || { MSG="copia.sh falla: $(tail -1 <<<"$salida" | cut -c1-150)"; grep -q 'denied' <<<"$salida" && TRAMPA="-p\"\$COPIAS_PASS\" va PEGADO a -p, sin espacio; y el usuario es COPIAS_USER."; return 1; }
    f=$(ls -t copias/radio-2*.sql 2>/dev/null | grep -v 20200101 | head -1)
    [ -n "$f" ] || { MSG="No hay ninguna copia nueva en copias/ (radio-AAAAMMDD-HHMMSS.sql)."; return 1; }
    grep -q 'CREATE TABLE `programas`' "$f" && grep -q 'INSERT INTO `podcasts`' "$f" || { MSG="$f no tiene las tablas con sus datos."; return 1; }
    [ -e copias/radio-20200101-000000.sql ] && { MSG="La copia se hace, pero las de más de 7 días no se borran (había una de 2020)."; return 1; }
    sql "DROP DATABASE IF EXISTS radio_prueba; CREATE DATABASE radio_prueba" >/dev/null
    docker compose exec -T db mariadb -uroot -p"$ROOTPW" radio_prueba < "$f" 2>/dev/null
    n1=$(sql 'SELECT COUNT(*) FROM radio.programas'); n2=$(sql 'SELECT COUNT(*) FROM radio_prueba.programas')
    sql "DROP DATABASE IF EXISTS radio_prueba" >/dev/null
    MSG="Restaurada en otra base: $n2 programas (en radio hay $n1)."; [ -n "$n2" ] && [ "$n1" = "$n2" ]
}
c_copia_limpia() {
    local v
    for v in "$(envvar COPIAS_PASS)" "$(envvar DB_PASS)" "$ROOTPW"; do
        [ -n "$v" ] && grep -qF -- "$v" servidor/copia.sh && { MSG="copia.sh lleva una contraseña escrita."; return 1; }
    done
    grep -qE '^[^#]*\. +/srv/servidor/radio\.env' servidor/copia.sh || { MSG="copia.sh no carga /srv/servidor/radio.env (con el punto: . fichero)."; return 1; }
    grep -qE '^[^#]*mysqldump.*COPIAS_USER' servidor/copia.sh || { MSG="mysqldump no entra con \$COPIAS_USER."; TRAMPA="cada uno, lo justo: las copias, con su usuario de solo lectura, no con el de la web ni con root."; return 1; }
    grep -qE '^[^#]*--single-transaction' servidor/copia.sh || { MSG="Falta --single-transaction: la copia bloquearía la web mientras se hace."; return 1; }
}

bloque C "Los datos en MariaDB (UD6)"
check C0.1 "👀" "MariaDB responde: la base radio con la parrilla y los podcasts" c_base
check C1.1 "✍️" "radio_web: solo SELECT en radio.*, desde otros ordenadores" c_web
check C1.2 "✍️" "root solo entra desde el propio servidor (sin root@'%')" c_root
check C2.1 "✍️" "radio.env: radio_web y su contraseña, y funcionan" c_env
check C2.2 "✍️" "La web (PHP) entra en MariaDB como radio_web" c_php
check C2.3 "✍️" "La API (Python) entra en MariaDB como radio_web" c_py
check C2.4 "✍️" "Ninguna contraseña escrita en web/ ni en app/" c_secretos
check C3.1 "✍️" "La parrilla sale de la tabla programas" c_parrilla
check C3.2 "✍️" "La parrilla, a salvo de inyección SQL" c_inyeccion
check C3.3 "✍️" "La API: los podcasts de la tabla, el más nuevo primero, y buscar sin inyección" c_api
check C4.1 "✍️" "copia.sh hace la copia, borra las viejas y la copia se restaura" c_copia
check C4.2 "✍️" "copia.sh: sin contraseñas, con su usuario y sin bloquear" c_copia_limpia
cierre_bloque

echo
if [ -n "$SOLO" ]; then
    echo "${N}Bloque $SOLO: $ok de $total${X}"
else
    echo "${N}Resultado: $ok de $total${X}  ${G}(${ejemplos} son ejemplos 👀 ya resueltos: no cuentan para la nota)${X}"
    [ "$ok" -lt "$total" ] && echo "${G}Para ver un bloque con todas las pistas: ./practica.sh comprobar A (o B, o C)${X}"
fi
[ "$ok" -eq "$total" ]
