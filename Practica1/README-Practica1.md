# Práctica 1: servidores, proxies y certificados

En este README dejo las decisiones y las pruebas que hice para levantar los dos sitios con Apache y poner Nginx delante como proxy con TLS.

## Arranque

Desde la carpeta `Practica1`, levanto los servicios con Docker Compose:

```bash
docker compose -f docker-compose.yaml up -d --build
docker compose -f docker-compose.yaml ps
```

Para pararlos:

```bash
docker compose -f docker-compose.yaml down
```

Apache escucha en el puerto `8183`. Nginx recibe el tráfico en los puertos `80` y `443`.

## Decisiones de diseño

Elegí `patchesmerch.local` y `patchesguides.local` porque son dos páginas que creé para un curso: una es una tienda y la otra, una guía. En esta práctica decidí usar PatchesGuides como la marca interna para probar la protección del CSV simulado.

Elegí `mpm_event` para Apache. Me permite atender varias conexiones y manejar mejor las conexiones keep-alive que quedan esperando entre peticiones. Uso dos Virtual Hosts basados en nombre, cada uno con su propio `DocumentRoot`, `ErrorLog` y `CustomLog`.

| Virtual Host | `DocumentRoot` | Registros |
|---|---|---|
| `patchesmerch.local` | `/var/www/patchesmerch` | `patchesmerch-error.log` y `patchesmerch-access.log` |
| `patchesguides.local` | `/var/www/patchesguides` | `patchesguides-error.log` y `patchesguides-access.log` |

Para los nombres que no coinciden con ningún sitio, dejé `000-inicial.conf` como Virtual Host predeterminado. Su `Location /` deniega el acceso, así que un `Host` desconocido recibe `403` en vez de mostrar por accidente la primera marca.

En `patchesguides.local` desactivé los listados de directorios con `Options -Indexes` y bloqueé el archivo simulado `patchesguides-vault.csv` con `Require all denied`.

## Nginx, HTTPS y proxy

Nginx es la entrada pública: redirige HTTP a HTTPS y reenvía las peticiones a Apache por el puerto `8183`. Uso esta línea para que Apache reciba el nombre que pidió el cliente:

```nginx
proxy_set_header Host $host;
```

Elegí una redirección `308` porque indica que es permanente y conserva el método de la petición.

El certificado de laboratorio tiene `patchesmerch.local` como CN y los dos dominios como SAN. Lo generé con una clave ECDSA de curva `secp384r1` (P-384). Como es autofirmado, usé `curl -k` para las pruebas; OpenSSL mostró el aviso correspondiente, aunque la conexión se estableció.

En Nginx permití solo TLS 1.2 y TLS 1.3. Para TLS 1.2 configuré estas suites:

```nginx
ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256';
```

Las elegí porque usan ECDHE para el intercambio de claves, ECDSA para la autenticación del servidor y AES-GCM para cifrar y verificar los datos. En mis pruebas, TLS 1.2 negoció `ECDHE-ECDSA-AES256-GCM-SHA384` y TLS 1.3 negoció `TLS_AES_256_GCM_SHA384`.

También añadí estas cabeceras en HTTPS:

```nginx
add_header Strict-Transport-Security "max-age=15552000" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
```

El HSTS tiene una duración de seis meses. `nosniff` evita que el navegador interprete el contenido con un tipo distinto del indicado y `DENY` impide que la página se muestre dentro de un marco.

## Límite de peticiones

Usé el escenario de la práctica para elegir los valores: `3r/s` como ritmo sostenido y `burst=6` para aceptar un pico breve de hasta seis peticiones por segundo. La zona cuenta las peticiones por dirección IP. Con `nodelay`, las peticiones que caben en la ráfaga se atienden enseguida; al superar el límite, Nginx devuelve `429`. El escenario plantea un scraper con más de 20 peticiones por segundo: a 20 peticiones por segundo, supera en 17 el ritmo sostenido de 3, así que agota rápidamente la ráfaga de 6. En cambio, las seis peticiones por segundo del pico legítimo quedaron permitidas en mi prueba.

```nginx
limit_req_zone $binary_remote_addr zone=patches_by_ip:12m rate=3r/s;

location / {
    limit_req zone=patches_by_ip burst=6 nodelay;
    limit_req_status 429;
    # ... proxy_pass y cabecera Host
}
```

Para repetir las pruebas usé estos comandos:

```bash
bash prueba-rate.sh 6 0.17
time bash prueba-rate.sh 30 0
```

En la primera prueba envié seis peticiones separadas por `0.17` segundos y las seis dieron `200`. En la segunda envié 30 seguidas: tardaron `0,327` segundos, unas 92 peticiones por segundo. Las primeras siete dieron `200` y las otras 23 dieron `429`. En esa ráfaga, la primera petición más las seis de `burst` explican los siete `200` iniciales.

## Pruebas

Hice las pruebas con `curl` y `Host` explícito, sin tocar `/etc/hosts`. Para las pruebas HTTPS usé `--resolve` para apuntar los dominios a `127.0.0.1`.

| Prueba | Resultado |
|---|---|
| Apache: `patchesmerch.local` | `200 OK`, portada correcta |
| Apache: `patchesguides.local` | `200 OK`, portada correcta |
| Apache: `/patchesguides-vault.csv` | `403 Forbidden` |
| Apache: `/materiales/` | `403 Forbidden`, sin listado |
| Apache: `Host` no configurado | `403 Forbidden` desde el Virtual Host predeterminado |
| Nginx: HTTP para los dos dominios | `308 Permanent Redirect` al mismo dominio por HTTPS |
| Nginx: HTTPS para los dos dominios | `200 OK`, con el sitio correcto |

También probé el proxy antes de añadir `proxy_set_header Host $host;`. Apache devolvió `403` porque no podía seleccionar el Virtual Host de la marca con el nombre recibido. Después de añadir la línea, los dos dominios respondieron `200` por HTTPS.

La prueba de cabeceras devolvió:

```text
Strict-Transport-Security: max-age=15552000
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
```

### Salida real de OpenSSL

Ejecuté `openssl s_client` con `-tls1_2` y `-tls1_3`. Este es el fragmento relevante de la salida:

```text
=== -tls1_2 ===
verify error:num=18:self-signed certificate
CONNECTION ESTABLISHED
Protocol version: TLSv1.2
Ciphersuite: ECDHE-ECDSA-AES256-GCM-SHA384
Peer certificate: CN=patchesmerch.local
Verification error: self-signed certificate
Peer Temp Key: X25519, 253 bits
DONE

=== -tls1_3 ===
verify error:num=18:self-signed certificate
CONNECTION ESTABLISHED
Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Peer certificate: CN=patchesmerch.local
Verification error: self-signed certificate
Peer Temp Key: X25519, 253 bits
DONE
```

La verificación da el error 18 porque el certificado es autofirmado. Aun así, en las dos pruebas se estableció la conexión y se negoció el protocolo y la suite indicados.

## Diagnóstico de fallos provocados

| Síntoma observado | Hipótesis inicial | Comando de diagnóstico | Causa y solución |
|---|---|---|---|
| Al cambiar temporalmente el `ServerName` de PatchesGuides, `patchesguides.local` devolvió `403`; el nombre temporal devolvió `200`. | El nombre solicitado no se estaba asociando al Virtual Host de PatchesGuides. | `docker compose -f docker-compose.yaml exec apache apache2ctl -S` y `curl -i -H 'Host: patchesguides.local' http://127.0.0.1:8183/` | El Virtual Host tenía `ServerName patchesguides-diagnostic.local`, así que el nombre original cayó en el Virtual Host predeterminado. Restauré `ServerName patchesguides.local`, reconstruí Apache y comprobé que volvió a dar `200`. |
| Al comentar temporalmente `limit_req`, una ráfaga de 30 peticiones dio 30 respuestas `200`, aunque la zona seguía definida. | La zona estaba creada, pero el límite podía no estar aplicado a las peticiones. | `docker compose -f docker-compose.yaml exec nginx nginx -T` (filtré las líneas `limit_req`) y `time bash prueba-rate.sh 30 0` | `limit_req_zone` solo crea la zona compartida; no aplica el control por sí sola. `nginx -T` mostró la línea `limit_req` comentada. La restauré, reconstruí Nginx y comprobé que la ráfaga volvió a recibir `429`. |

Después de restaurar las dos configuraciones, Apache volvió a servir `patchesguides.local` con `200`; Nginx pasó `nginx -t` y volvió a aplicar el límite.