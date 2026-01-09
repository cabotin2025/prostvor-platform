<?php
/**
 * Простая проверка токена для фронтенда
 */

require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

// Всегда возвращаем JSON, даже для неавторизованных
try {
    $token = null;
    
    // Пробуем разные способы получить токен
    if (isset($_GET['token'])) {
        $token = $_GET['token'];
    } elseif (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $matches = [];
        if (preg_match('/Bearer\s+(\S+)/', $_SERVER['HTTP_AUTHORIZATION'], $matches)) {
            $token = $matches[1];
        }
    }
    
    if (!$token) {
        echo json_encode([
            'authenticated' => false,
            'message' => 'Не авторизован'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // Проверяем токен
    $decoded = JWT::decode($token, JWT_SECRET);
    
    echo json_encode([
        'authenticated' => true,
        'user_id' => $decoded->user_id,
        'nickname' => $decoded->nickname,
        'email' => $decoded->email,
        'status_id' => $decoded->status_id ?? 7,
        'expires_at' => date('Y-m-d H:i:s', $decoded->exp)
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    echo json_encode([
        'authenticated' => false,
        'message' => 'Токен невалиден: ' . $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}