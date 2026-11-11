# UD6 (Python) — Gunicorn + Flask de laboratorio, con PyMySQL para hablar con MariaDB. IAW ASIR 2.º
FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir flask==3.0.3 gunicorn==23.0.0 pymysql==1.1.1
EXPOSE 8000
