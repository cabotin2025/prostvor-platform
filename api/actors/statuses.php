<?php
// api/actors/statuses.php - Получение всех статусов актора
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../lib/Database.php';

header('Content-Type: application/json; charset=utf-8');

// Проверка авторизации
$headers = getallheaders();
$token = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : null;

if (!$token) {
    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Требуется авторизация']);
    exit;
}

// Получаем actor_id из токена или запроса
$input = json_decode(file_get_contents('php://input'), true);
$actor_id = $input['actor_id'] ?? null;

if (!$actor_id) {
    // Пробуем получить из токена (упрощенная версия)
    // В реальности нужно декодировать JWT токен
    $actor_id = $_GET['actor_id'] ?? null;
}

if (!$actor_id) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Требуется actor_id']);
    exit;
}

try {
    // Получаем ВСЕ статусы актора
    $statuses = Prostvor\Database::fetchAll("
        SELECT ast.status, acs.created_at
        FROM actor_current_statuses acs
        JOIN actor_statuses ast ON acs.actor_status_id = ast.actor_status_id
        WHERE acs.actor_id = :actor_id
        ORDER BY acs.created_at DESC
    ", ['actor_id' => $actor_id]);
    
    // Также получаем основной статус
    $main_status = Prostvor\Database::fetchOne("
        SELECT ast.status
        FROM actor_current_statuses acs
        JOIN actor_statuses ast ON acs.actor_status_id = ast.actor_status_id
        WHERE acs.actor_id = :actor_id
        ORDER BY acs.created_at DESC
        LIMIT 1
    ", ['actor_id' => $actor_id]);
    
    // Формируем ответ
    $response = [
        'success' => true,
        'actor_id' => $actor_id,
        'statuses' => array_column($statuses, 'status'),
        'main_status' => $main_status['status'] ?? 'Участник ТЦ',
        'detailed_statuses' => $statuses
    ];
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Ошибка получения статусов',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}