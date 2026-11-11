<?php declare(strict_types=1);
// 👀 La cabecera de todas las páginas de la radio. Se incluye con require, nunca se pide desde el navegador (A4).
require_once __DIR__ . '/util.php';
?><!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>Radio Marea · 98.4 FM</title><link rel="stylesheet" href="/estilo.css"></head>
<body><header><h1>📻 Radio Marea <small>98.4 FM</small></h1>
<nav><a href="/">En directo</a> · <a href="/parrilla.php">Parrilla</a> · <a href="/saludos.php">Manda un saludo</a> · <a href="/api/podcasts">Podcasts (API)</a></nav></header>
