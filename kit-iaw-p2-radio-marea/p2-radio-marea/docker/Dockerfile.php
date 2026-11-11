# UD6 (PHP-FPM) — PHP 8.3 FPM de laboratorio, IAW ASIR 2.º
# Imagen oficial + la extensión pdo_mysql (para hablar con MariaDB) + procps.
FROM php:8.3-fpm
RUN apt-get update && apt-get install -y --no-install-recommends procps nano \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install pdo_mysql
# OPcache viene activo y mira si cambiaste un .php cada 2 s: en el laboratorio, en cada petición (lo de la UD4)
RUN echo 'opcache.revalidate_freq = 0' > /usr/local/etc/php/conf.d/zz-lab.ini
