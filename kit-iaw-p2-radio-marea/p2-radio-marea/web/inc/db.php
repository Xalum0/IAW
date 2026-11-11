<?php
declare(strict_types=1);
// La conexión con la base de datos de la radio (bloque C). La usa inc/datos.php.

// 👀 Lee un fichero «CLAVE=valor» (el mismo radio.env que usa Python) y lo devuelve como array.
//    Se salta las líneas vacías y los comentarios (#). Ejemplo: leer_env('/etc/radio/radio.env')['DB_NAME'] → 'radio'
function leer_env(string $fichero): array
{
    $cfg = [];
    foreach (file($fichero, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $linea) {
        if (str_starts_with(trim($linea), '#') || !str_contains($linea, '=')) {
            continue;
        }
        [$clave, $valor] = explode('=', $linea, 2);
        $cfg[trim($clave)] = trim($valor);
    }
    return $cfg;
}

// ✍️ C2 · Devuelve una conexión PDO con MariaDB (UD6, apartados 5.1 y 6):
//         - todo sale de /etc/radio/radio.env (es tu servidor/radio.env): host, base, usuario y contraseña;
//         - en el DSN, también charset=utf8mb4;
//         - que lance una excepción si algo falla y que cada fila sea un array con los nombres de las columnas.
//         En este fichero no puede quedar escrita ninguna contraseña.
function conectar(): PDO
{
    throw new RuntimeException('Sin hacer: conectar() (C2)');
}
