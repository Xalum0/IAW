#!/usr/bin/env bash
# Práctica 2 de IAW · Radio Marea. El mando a distancia: no hace falta escribir órdenes de Docker.
#   ./practica.sh arrancar          levanta la radio (la primera vez tarda: descarga y prepara las imágenes)
#   ./practica.sh comprobar [A|B|C] comprueba todo, o solo un bloque, con pistas
#   ./practica.sh recargar          aplica tus cambios: nginx -t + recarga Nginx, reinicia PHP y la API
#   ./practica.sh sql               aplica sql/usuarios.sql como root, dentro del servidor de la base de datos (C1)
#   ./practica.sh mariadb           abre la consola de MariaDB como root, dentro del servidor (para mirar; exit para salir)
#   ./practica.sh copia             lanza servidor/copia.sh en «admin», el ordenador del administrador (C4)
#   ./practica.sh logs              las últimas líneas de los logs (Nginx, PHP y Gunicorn)
#   ./practica.sh parar             lo apaga todo (la base de datos se conserva)
#   ./practica.sh desde-cero        borra la base de datos y la vuelve a crear como al principio (tus ficheros se quedan)
set -uo pipefail
cd "$(dirname "$0")"
V=$'\e[32m'; R=$'\e[31m'; N=$'\e[1m'; X=$'\e[0m'
ROOTPW=raiz-de-la-practica      # la de compose.yaml: solo para el laboratorio
export YO="$(id -u):$(id -g)"   # «admin» trabaja con tu usuario: las copias son tuyas

command -v docker >/dev/null 2>&1 || { echo "${R}✘ No encuentro Docker.${X} Es el mismo de las unidades: instálalo (o arranca Docker Desktop) y vuelve a probar."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "${R}✘ Docker no responde.${X} ¿Está arrancado? (en Linux: sudo systemctl start docker)"; exit 1; }
# La llave del certificado (certs/lab.key) no va a Git: si clonas tu repositorio en otro ordenador, no está.
# Si falta, se hace un certificado de prueba nuevo para *.iaw.local, dentro de Docker (con la misma imagen de Nginx).
certificado() {
  [ -s certs/lab.key ] && [ -s certs/lab.crt ] && return 0
  echo "No está el certificado de prueba (certs/lab.key no viaja con Git). Hago uno nuevo…"
  mkdir -p certs
  docker compose run --rm --no-deps -T --user "$YO" -v "$PWD/certs:/salida" --entrypoint openssl nginx \
    req -x509 -newkey rsa:2048 -nodes -days 365 -keyout /salida/lab.key -out /salida/lab.crt \
    -subj "/C=ES/ST=Cadiz/L=Cadiz/O=IAW-Lab/CN=*.iaw.local" \
    -addext "subjectAltName=DNS:*.iaw.local,DNS:iaw.local" >/dev/null 2>&1 \
    && echo "${V}✔ certs/lab.crt y certs/lab.key nuevos${X} (la llave sigue fuera de Git)" \
    || { echo "${R}✘ No he podido hacer el certificado.${X} Prueba: docker compose build nginx"; exit 1; }
}
esperar_db() { for _ in $(seq 1 60); do docker compose exec -T db healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1 && return 0; sleep 1; done; echo "${R}✘ MariaDB no arranca:${X} docker compose logs db"; exit 1; }

case "${1:-ayuda}" in
  arrancar)
    chmod 777 logs 2>/dev/null       # PHP y Gunicorn escriben sus logs aquí con su propio usuario
    [ -f servidor/radio.env ] || { echo "${R}✘ Falta servidor/radio.env${X} (no viaja con Git: en otro ordenador no está)."
      echo "  Cópialo del kit (servidor/radio.env), rellena otra vez SECRET_KEY, DB_USER y DB_PASS, y después: ./practica.sh sql"; exit 1; }
    certificado
    docker compose up -d --build || exit 1
    esperar_db
    echo
    echo "${V}✔ Radio Marea está en marcha:${X} https://localhost:8452  (el certificado es de prueba: acepta el aviso)"
    echo "  Ahora: ${N}./practica.sh comprobar${X}  (al principio, solo los ejemplos 👀 en verde)" ;;
  comprobar)
    bash comprobador/comprobar.sh "${2:-}" ;;
  recargar)
    docker compose exec -T nginx nginx -t && docker compose exec -T nginx nginx -s reload && echo "${V}✔ Nginx recargado${X}" || exit 1
    docker compose restart php app >/dev/null && echo "${V}✔ PHP y la API reiniciados${X} (si algo no responde: ./practica.sh logs)" ;;
  sql)
    echo "Aplicando sql/usuarios.sql como root…"
    if docker compose exec -T db mariadb -uroot -p"$ROOTPW" < sql/usuarios.sql; then
        echo "${V}✔ Aplicado.${X} Ahora: ./practica.sh comprobar C"
    else
        echo "${R}✘ MariaDB ha parado en el error de arriba${X} («at line NN»: la línea de sql/usuarios.sql). Lo de antes de esa línea sí se ha aplicado."; exit 1
    fi ;;
  mariadb)
    docker compose exec db mariadb -uroot -p"$ROOTPW" radio ;;
  copia)
    docker compose exec -T admin timeout 20 sh /srv/servidor/copia.sh </dev/null
    r=$?; [ $r = 124 ] && echo "${R}✘ copia.sh se ha quedado esperando una contraseña.${X} ¿Carga radio.env? ¿-p\"\$COPIAS_PASS\" va pegado?"
    exit $r ;;
  logs)
    for f in logs/radio_error.log logs/php-errores.log logs/gunicorn-errores.log; do
      [ -s "$f" ] && { echo "${N}── $f${X}"; tail -n 8 "$f"; }
    done
    echo "${N}── docker compose logs app${X}"; docker compose logs --tail 8 app ;;
  parar)
    docker compose down ;;
  desde-cero)
    certificado
    docker compose down -v && docker compose up -d && esperar_db && echo "${V}✔ Base de datos nueva, como al principio.${X} Tus usuarios: ./practica.sh sql" ;;
  *)
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
