<?php
declare(strict_types=1);
// De dónde salen los programas. Las páginas solo llaman a programas($dia) y a origen_datos(): no saben si hay base de datos.
require_once __DIR__ . '/db.php';

// 👀 Datos de prueba, para el bloque A (todavía sin base de datos). En el C3 dejan de usarse.
const PARRILLA_DE_PRUEBA = [
    ['dia' => 'lunes',  'hora' => '07:00:00', 'nombre' => 'Despierta, Marea (prueba)',   'locutor' => 'Lola Ruiz'],
    ['dia' => 'lunes',  'hora' => '22:00:00', 'nombre' => 'Faro de medianoche (prueba)', 'locutor' => 'Toni Ancla'],
    ['dia' => 'martes', 'hora' => '18:00:00', 'nombre' => 'Mareas de rock (prueba)',     'locutor' => 'Inés Barca'],
];

// ✍️ C3 · Los programas de ese día, de la tabla programas, ordenados por hora (UD6, apartado 7).
//         El día lo escribe el oyente en la URL (?dia=…): consulta preparada, nunca pegado dentro del SQL.
//         Cada programa, un array con las claves hora, nombre y locutor (las usan index.php y parrilla.php).
function programas(string $dia): array
{
    return array_values(array_filter(PARRILLA_DE_PRUEBA, fn ($p) => $p['dia'] === $dia));
}

// 👀 Para el pie de la parrilla: con qué usuario está conectada la web (o por qué no puede).
function origen_datos(): string
{
    try {
        $yo = conectar()->query('SELECT CURRENT_USER()')->fetchColumn();
        return "MariaDB, conectada como $yo";
    } catch (Throwable $e) {
        return 'sin base de datos (' . $e->getMessage() . ')';
    }
}
