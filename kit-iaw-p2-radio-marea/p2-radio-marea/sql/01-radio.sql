-- Se ejecuta UNA vez, la primera vez que arranca MariaDB (el volumen «datos» está vacío).
-- La base «radio» ya la crea MARIADB_DATABASE. Aquí: la parrilla de la semana y los podcasts.
-- No lo cambies: lo tuyo va en sql/usuarios.sql (C1).
USE radio;

CREATE TABLE programas (
  id      INT AUTO_INCREMENT PRIMARY KEY,
  dia     VARCHAR(10) NOT NULL,             -- lunes … viernes
  hora    TIME        NOT NULL,
  nombre  VARCHAR(80) NOT NULL,
  locutor VARCHAR(60) NOT NULL
);
INSERT INTO programas (dia, hora, nombre, locutor) VALUES
  ('lunes',     '07:00', 'Despierta, Marea',         'Lola Ruiz'),
  ('lunes',     '10:00', 'La tertulia del muelle',   'Paco Vela'),
  ('lunes',     '13:00', 'Noticias del puerto',      'Redacción'),
  ('lunes',     '22:00', 'Faro de medianoche',       'Toni Ancla'),
  ('martes',    '07:00', 'Despierta, Marea',         'Lola Ruiz'),
  ('martes',    '11:00', 'Cocina de lonja',          'Rocío Sal'),
  ('martes',    '13:00', 'Noticias del puerto',      'Redacción'),
  ('martes',    '18:00', 'Mareas de rock',           'Inés Barca'),
  ('miercoles', '07:00', 'Despierta, Marea',         'Lola Ruiz'),
  ('miercoles', '10:00', 'La tertulia del muelle',   'Paco Vela'),
  ('miercoles', '13:00', 'Noticias del puerto',      'Redacción'),
  ('miercoles', '20:00', 'Deporte de barrio',        'Juanma Remo'),
  ('jueves',    '07:00', 'Despierta, Marea',         'Lola Ruiz'),
  ('jueves',    '11:00', 'Cocina de lonja',          'Rocío Sal'),
  ('jueves',    '13:00', 'Noticias del puerto',      'Redacción'),
  ('jueves',    '18:00', 'Mareas de rock',           'Inés Barca'),
  ('viernes',   '07:00', 'Despierta, Marea',         'Lola Ruiz'),
  ('viernes',   '13:00', 'Noticias del puerto',      'Redacción'),
  ('viernes',   '20:00', 'Deporte de barrio',        'Juanma Remo'),
  ('viernes',   '22:00', 'Faro de medianoche',       'Toni Ancla');

CREATE TABLE podcasts (
  id       INT AUTO_INCREMENT PRIMARY KEY,
  titulo   VARCHAR(120) NOT NULL,
  programa VARCHAR(80)  NOT NULL,
  minutos  INT          NOT NULL,
  fecha    DATE         NOT NULL
);
INSERT INTO podcasts (titulo, programa, minutos, fecha) VALUES
  ('Las corvinas de octubre',             'Cocina de lonja',        28, '2026-10-20'),
  ('Entrevista a la cofradía de pescadores', 'La tertulia del muelle', 52, '2026-10-26'),
  ('Especial rock andaluz',               'Mareas de rock',         58, '2026-10-27'),
  ('El faro y sus fareros',               'Faro de medianoche',     45, '2026-10-29'),
  ('Final del torneo de barrio',          'Deporte de barrio',      40, '2026-10-30'),
  ('Atún de almadraba, paso a paso',      'Cocina de lonja',        31, '2026-11-03');
