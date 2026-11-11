<?php
declare(strict_types=1);
// 👀 La portada: qué suena ahora. Si ves este código en el navegador en lugar de la página, Nginx no le pasa los .php a PHP (A1).
require __DIR__ . '/inc/cabecera.php';
require_once __DIR__ . '/inc/datos.php';

$dias = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
$hoy  = $dias[(int) date('N') - 1];
?>
<main>
  <p class="directo">🔴 En directo · <?= e(ucfirst($hoy)) ?>, <?= date('H:i') ?></p>
  <h2>Hoy en Radio Marea</h2>
  <ul>
  <?php foreach (programas($hoy) as $p): ?>
    <li><b><?= e(substr($p['hora'], 0, 5)) ?></b> · <?= e($p['nombre']) ?> <small>con <?= e($p['locutor']) ?></small></li>
  <?php endforeach; ?>
  </ul>
  <p class="nota">Página hecha por PHP <?= PHP_MAJOR_VERSION ?> en el servidor: el oyente solo recibe el HTML.</p>
</main>
</body></html>
