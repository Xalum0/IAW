-- ✍️ C1 · Los usuarios de la base de datos de Radio Marea (UD6, apartado 3).
-- Se aplica como root, dentro del servidor de MariaDB, con: ./practica.sh sql
-- Lo puedes aplicar todas las veces que quieras: por eso cada orden empieza con «IF NOT EXISTS» / «IF EXISTS».

-- 👀 Ejemplo: un usuario para las copias de seguridad, que solo lee. Así se crea, y así se le da permiso.
CREATE USER IF NOT EXISTS 'radio_copias'@'%' IDENTIFIED BY 'copia-de-la-marea-2026';
GRANT SELECT ON radio.* TO 'radio_copias'@'%';

-- ✍️ C1.1 · El usuario de la web y de la API: radio_web, con una contraseña larga (la tuya).
--          La web y la API solo LEEN la parrilla y los podcasts: los permisos justos, solo en la base radio.
--          La web y la API están en OTROS ordenadores (php, app), no en el de la base de datos.


-- ✍️ C1.2 · root solo puede entrar desde el propio servidor de la base de datos.


