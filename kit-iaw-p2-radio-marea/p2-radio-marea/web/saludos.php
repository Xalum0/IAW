<?php
declare(strict_types=1);
// Manda un saludo a la radio: el locutor lo lee en antena. Lo que escribe el oyente se enseña en la página.
// ✍️ A3 · Aquí no hay que cambiar nada: lo arreglas en e() (inc/util.php). Pero mira dónde se usa: en el texto y en value="…".
require __DIR__ . '/inc/cabecera.php';

$nombre  = $_GET['nombre'] ?? '';
$mensaje = $_GET['mensaje'] ?? '';
?>
<main>
  <h2>Manda un saludo</h2>
  <?php if ($nombre !== '' && $mensaje !== ''): ?>
    <p class="nota">📨 Saludo de <b><?= e($nombre) ?></b>: «<?= e($mensaje) ?>». ¡Lo leemos en antena!</p>
  <?php endif; ?>
  <form method="get">
    <label>Tu nombre <input name="nombre" value="<?= e($nombre) ?>"></label>
    <label>Tu saludo <input name="mensaje" size="50"></label>
    <button>Enviar</button>
  </form>
</main>
</body></html>
