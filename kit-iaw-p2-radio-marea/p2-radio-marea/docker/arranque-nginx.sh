#!/bin/sh
# Arranque del contenedor «nginx»: enlaza el sitio de la radio (servidor/nginx/radio.conf) y arranca Nginx.
set -e
ln -sf /etc/nginx/sites-available/radio.conf /etc/nginx/sites-enabled/radio.conf
exec nginx -g 'daemon off;'
