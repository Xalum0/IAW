<?php
declare(strict_types=1);
// Funciones pequeñas que usan todas las páginas.

// ✍️ A3 · e(): recibe un texto que puede venir del oyente y lo devuelve listo para meterlo en el HTML sin peligro
//         (UD4, apartado 5.2). Tiene que valer dentro del texto de la página y dentro de un atributo value="…".
//         Ahora lo devuelve tal cual: así, el que escriba <script> en un saludo lo ejecuta en el navegador de todos.
function e(string $texto): string
{
    return $texto;
}
