#!/bin/sh
# Arranque del contenedor «app»: carga las variables de servidor/radio.env y arranca Gunicorn con servidor/gunicorn.conf.py.
# Si cambias radio.env, gunicorn.conf.py o app.py: ./practica.sh recargar
set -e
set -a; . /etc/radio/radio.env; set +a
cd /srv/app
exec gunicorn -c /etc/radio/gunicorn.conf.py app:app
