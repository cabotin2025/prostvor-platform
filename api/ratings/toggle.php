<?php
// /api/ratings/toggle.php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once $_SERVER['DOCUMENT_ROOT'] . '/config/database.php';

try {
    $input = json_decode(file_get_contents('php://input'), true) ?: [];
    
    $entity_type = $input['entity_type'] ?? '';
    $entity_id = $input['entity_id'] ?? 0;
    $rating_type = $input['rating_type'] ?? 'положительно';
    
    // Тестовый ответ
    $has_rating = rand(0, 1) > 0.5;
    
    echo json_encode([
        'success' => true,
        'has_rating' => $has_rating,
        'action' => $has_rating ? 'added' : 'removed',
        'message' => $has_rating ? 'Оценка добавлена' : 'Оценка удалена',
        'entity_type' => $entity_type,
        'entity_id' => $entity_id,
        'rating_type' => $rating_type
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODEE);
}
?>