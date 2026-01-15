<?php
// /api/ratings/count.php
header('Content-Type: application/json; charset=utf-8');

require_once $_SERVER['DOCUMENT_ROOT'] . '/config/database.php';

$entity_type = $_GET['entity_type'] ?? '';
$entity_id = $_GET['entity_id'] ?? 0;

echo json_encode([
    'success' => true,
    'count' => 0,
    'entity_type' => $entity_type,
    'entity_id' => (int)$entity_id,
    'message' => 'Счетчик оценок'
], JSON_UNESCAPED_UNICODE);
?>