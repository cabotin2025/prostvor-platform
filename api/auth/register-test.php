<?php
// Минимальный тестовый endpoint
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

// Просто логируем данные
$data = json_decode(file_get_contents('php://input'), true);
error_log('Регистрация: ' . print_r($data, true));

// Всегда успешный ответ для теста
echo json_encode([
    'success' => true,
    'message' => 'Тест регистрации пройден',
    'token' => 'test-token-' . time(),
    'actor_id' => 999,
    'username' => $data['nickname'] ?? 'testuser'
]);

exit;