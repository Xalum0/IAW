#!/bin/sh
# Copia de seguridad de la base de datos de Radio Marea (UD6, apartado 10). Se lanza con: ./practica.sh copia
# Corre en «admin», el ordenador del administrador: tu carpeta servidor/ es /srv/servidor y copias/ es /copias.
# En un servidor de verdad la lanzaría cron cada noche: 30 3 * * * /srv/servidor/copia.sh
# Este script va a Git: por eso NO lleva ninguna contraseña escrita.
set -e

# ✍️ C4 · Escribe el script, paso a paso:
#   1. Carga las variables de /srv/servidor/radio.env (así tienes $DB_HOST, $DB_NAME, $COPIAS_USER, $COPIAS_PASS…).
#   2. Una variable FECHA con la fecha y la hora, así: 20261123-033000.
#   3. La copia de la base $DB_NAME con mysqldump, entrando como el usuario de las copias (COPIAS_USER, no radio_web),
#      en /copias/radio-$FECHA.sql. Sin bloquear la web y sin pedir el permiso PROCESS.
#   4. Que no se acumulen: borra las copias radio-*.sql de más de 7 días.
#   5. Que diga qué fichero ha creado.

