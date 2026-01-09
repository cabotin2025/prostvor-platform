<?php
/**
 * Упрощенный рабочий login
 */

// Включите отладку временно
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../../config/database.php';
require_once '../../config/cors.php';

// Подключаем JWT если есть, иначе создаем простой
if (file_exists('../../config/jwt.php')) {
    require_once '../../config/jwt.php';
} else {
    // Простой JWT класс для теста
    class SimpleJWT {
        public static function encode($payload) {
            $header = ['typ' => 'JWT', 'alg' => 'none'];
            $payload['iat'] = time();
            $payload['exp'] = time() + 86400;
            
            $header_encoded = base64_encode(json_encode($header));
            $payload_encoded = base64_encode(json_encode($payload));
            
            return "$header_encoded.$payload_encoded.signature";
        }
    }
}

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// Разрешаем OPTIONS запросы
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Только POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Только POST'], JSON_UNESCAPED_UNICODE);
    exit;
}

try {
    // Получаем данные
    $raw_input = file_get_contents('php://input');
    
    if (empty($raw_input)) {
        throw new Exception('Нет данных');
    }
    
    $data = json_decode($raw_input, true);
    
    if (!$data) {
        throw new Exception('Некорректный JSON');
    }
    
    // Валидация
    if (empty($data['email'])) {
        throw new Exception('Email обязателен');
    }
    
    if (empty($data['password'])) {
        throw new Exception('Пароль обязателен');
    }
    
    $email = trim($data['email']);
    $password = $data['password'];
    
    // Ищем пользователя - УПРОЩЕННЫЙ ЗАПРОС
    $stmt = $pdo->prepare("
        SELECT 
            a.actor_id,
            a.nickname,
            p.email,
            ac.password_hash
        FROM persons p
        JOIN actors a ON p.actor_id = a.actor_id
        LEFT JOIN actor_credentials ac ON a.actor_id = ac.actor_id
        WHERE p.email = ?
        LIMIT 1
    ");
    
    $stmt->execute([$email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        throw new Exception('Пользователь не найден: ' . $email);
    }
    
    // Для отладки
    error_log("User found: " . print_r($user, true));
    
    // Проверяем пароль
    if (empty($user['password_hash'])) {
        // Если нет пароля в базе, используем тестовый
        if ($password === '123456' && $email === 'cabotin@mail.ru') {
            // Пропускаем для теста
            error_log("Используется тестовый пароль для cabotin");
        } else {
            throw new Exception('Пароль не установлен в системе');
        }
    } else {
        // Проверяем хэш
        if (!password_verify($password, $user['password_hash'])) {
            throw new Exception('Неверный пароль');
        }
    }
    
    // Создаем токен
    if (class_exists('JWT')) {
        $token = JWT::encode([
            'user_id' => (int)$user['actor_id'],
            'nickname' => $user['nickname'],
            'email' => $user['email']
        ]);
    } else {
        $token = SimpleJWT::encode([
            'user_id' => (int)$user['actor_id'],
            'nickname' => $user['nickname'],
            'email' => $user['email']
        ]);
    }
    
    // Успешный ответ
    echo json_encode([
        'success' => true,
        'message' => 'Вход выполнен',
        'token' => $token,
        'user' => [
            'actor_id' => (int)$user['actor_id'],
            'nickname' => $user['nickname'],
            'email' => $user['email']
        ]
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    error_log("Login error: " . $e->getMessage());
    
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'error_type' => get_class($e)
    ], JSON_UNESCAPED_UNICODE);
}