<?php
declare(strict_types=1);
// 👀 Una página rota a propósito, para el A2: pide un fichero que no existe.
// Con display_errors = On, el oyente ve la ruta del servidor y el nombre de tus ficheros. Con Off, solo un error 500.
require __DIR__ . '/inc/configuracion-que-no-existe.php';
echo 'Aquí no se llega';
