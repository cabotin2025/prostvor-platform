<?php
// api/ratings/check.php - был 404 ошибка
header('Content-Type: application/json');

try {
    require_once __DIR__ . '/../config/database.php';
    
    // Параметры
    $entity_type = $_GET['entity_type'] ?? '';
    $entity_id = $_GET['entity_id'] ?? 0;
    
    if (empty($entity_type) || $entity_id <= 0) {
        echo json_encode([
            'success' => true,
            'has_rating' => false,
            'message' => 'Параметры не указаны'
        ]);
        exit;
    }
    
    // Временное решение - всегда false
    echo json_encode([
        'success' => true,
        'has_rating' => false,
        'entity_type' => $entity_type,
        'entity_id' => $entity_id
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка: ' . $e->getMessage()
    ]);
}
?>