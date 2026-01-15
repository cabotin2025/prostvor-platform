<?php
// /api/favorites/count.php
header('Content-Type: application/json; charset=utf-8');

require_once $_SERVER['DOCUMENT_ROOT'] . '/config/database.php';

echo json_encode([
    'success' => true,
    'count' => 0,
    'message' => 'Счетчик избранного'
], JSON_UNESCAPED_UNICODE);
?>