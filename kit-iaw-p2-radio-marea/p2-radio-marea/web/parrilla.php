<?php
declare(strict_types=1);
// 👀 La parrilla de un día: /parrilla.php?dia=martes. Los programas los da programas() (inc/datos.php).
require __DIR__ . '/inc/cabecera.php';
require_once __DIR__ . '/inc/datos.php';

$dia = $_GET['dia'] ?? 'lunes';
?>
<main>
  <h2>Parrilla del <?= e($dia) ?></h2>
  <p>
  <?php foreach (['lunes', 'martes', 'miercoles', 'jueves', 'viernes'] as $d): ?>
    <a href="?dia=<?= $d ?>"><?= ucfirst($d) ?></a>
  <?php endforeach; ?>
  </p>
  <table>
    <tr><th>Hora</th><th>Programa</th><th>Locutor</th></tr>
  <?php foreach (programas($dia) as $p): ?>
    <tr><td><?= e(substr($p['hora'], 0, 5)) ?></td><td><?= e($p['nombre']) ?></td><td><?= e($p['locutor']) ?></td></tr>
  <?php endforeach; ?>
  </table>
  <p class="nota">Datos: <?= e(origen_datos()) ?></p>
</main>
</body></html>
