<?php
// Минимальная рабочая версия регистрации
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

try {
    $data = json_decode(file_get_contents('php://input'), true);
    
    // Простейшая валидация
    if (empty($data['email']) || empty($data['password']) || empty($data['nickname'])) {
        throw new Exception('Заполните обязательные поля');
    }
    
    // Просто возвращаем успех без сохранения в БД
    echo json_encode([
        'success' => true,
        'message' => 'Регистрация успешна (тестовый режим)',
        'token' => 'temp-token-' . md5($data['email']),
        'actor_id' => rand(1000, 9999),
        'username' => $data['nickname'],
        'global_status' => 'Участник ТЦ'
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}