FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends apache2 \
    && rm -rf /var/lib/apt/lists/*

RUN a2dismod mpm_prefork 2>/dev/null || true
RUN a2dismod mpm_worker 2>/dev/null || true
RUN a2enmod mpm_event

COPY ports.conf /etc/apache2/ports.conf
COPY sites-available/ /etc/apache2/sites-available/
COPY web/ /var/www/

RUN a2dissite 000-default.conf \
    && a2ensite 000-catchall.conf \
    && a2ensite patchesmerch.conf \
    && a2ensite patchesguides.conf \
    && apache2ctl configtest

EXPOSE 8183

CMD ["apachectl", "-D", "FOREGROUND"]
