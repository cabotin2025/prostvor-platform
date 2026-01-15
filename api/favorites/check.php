<?php
// /api/favorites/check.php
header('Content-Type: application/json; charset=utf-8');

require_once $_SERVER['DOCUMENT_ROOT'] . '/config/database.php';

$entity_type = $_GET['entity_type'] ?? '';
$entity_id = $_GET['entity_id'] ?? 0;

echo json_encode([
    'success' => true,
    'is_favorite' => false,
    'entity_type' => $entity_type,
    'entity_id' => (int)$entity_id,
    'message' => 'Проверка избранного'
], JSON_UNESCAPED_UNICODE);
?>