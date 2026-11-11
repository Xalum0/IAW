<?php
// 👀 Para comprobar que Nginx le pasa los .php a PHP-FPM. No usa la base de datos.
header('Content-Type: text/plain; charset=utf-8');
echo "PHP-FPM responde · PHP " . PHP_MAJOR_VERSION . "\n";
