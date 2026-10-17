FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/*

COPY sites-available/ /etc/nginx/sites-available/

RUN rm -f /etc/nginx/sites-enabled/default \
    && ln -s /etc/nginx/sites-available/patches-edge.conf /etc/nginx/sites-enabled/patches-edge.conf

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
