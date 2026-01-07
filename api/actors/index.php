<?php
// api/actors/index.php - получение списка участников
require_once __DIR__ . '/../../middleware/auth.php';

// Проверяем авторизацию
$user = requireAuth();

try {
    // Получаем участников с их типами
    $actors = \Prostvor\Database::fetchAll("
        SELECT 
            a.actor_id,
            a.nickname,
            a.account,
            a.created_at,
            at.type as actor_type,
            p.email,
            p.name,
            p.last_name,
            p.phone_number,
            l.name as location_name
        FROM actors a
        JOIN actor_types at ON a.actor_type_id = at.actor_type_id
        LEFT JOIN persons p ON a.actor_id = p.actor_id AND p.deleted_at IS NULL
        LEFT JOIN locations l ON p.location_id = l.location_id
        WHERE a.deleted_at IS NULL
        ORDER BY a.created_at DESC
        LIMIT 100
    ");
    
    echo json_encode([
        'success' => true,
        'count' => count($actors),
        'actors' => $actors
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Failed to fetch actors',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}