<?php
// Включите отладку
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../../config/database.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

// Простая отладка
$input = file_get_contents('php://input');
error_log("Входной запрос: " . $input);

$data = json_decode($input, true);
error_log("Декодированные данные: " . print_r($data, true));

if (json_last_error() !== JSON_ERROR_NONE) {
    error_log("JSON ошибка: " . json_last_error_msg());
}

// Тестируем конкретного пользователя
try {
    $email = 'cabotin@mail.ru';
    
    $stmt = $pdo->prepare("
        SELECT 
            a.actor_id,
            a.nickname,
            p.email,
            ac.password_hash
        FROM persons p
        JOIN actors a ON p.actor_id = a.actor_id
        LEFT JOIN actor_credentials ac ON a.actor_id = ac.actor_id
        WHERE p.email = :email
    ");
    
    $stmt->execute([':email' => $email]);
    $user = $stmt->fetch();
    
    error_log("Найден пользователь: " . print_r($user, true));
    
    if ($user) {
        error_log("Длина хэша пароля: " . strlen($user['password_hash']));
        error_log("Хэш: " . $user['password_hash']);
        
        // Проверяем пароль 123456
        $test_hash = password_hash('123456', PASSWORD_DEFAULT);
        error_log("Тестовый хэш для 123456: " . $test_hash);
        
        $is_valid = password_verify('123456', $user['password_hash']);
        error_log("Проверка пароля: " . ($is_valid ? 'VALID' : 'INVALID'));
    }
    
    echo json_encode([
        'debug' => true,
        'input' => $input,
        'user_found' => !!$user,
        'has_password' => $user ? !empty($user['password_hash']) : false,
        'password_length' => $user ? strlen($user['password_hash']) : 0
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    error_log("Ошибка: " . $e->getMessage());
    echo json_encode([
        'debug' => true,
        'error' => $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ], JSON_UNESCAPED_UNICODE);
}