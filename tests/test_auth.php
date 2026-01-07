<?php
// test_auth.php - тест аутентификации
require_once 'config/database.php';
require_once 'lib/Database.php';

header('Content-Type: application/json');

try {
    // Тестируем функцию authenticate_user из вашей БД
    $test_email = 'admin@example.com';
    $test_password = 'admin123'; // Пароль, который вы установили
    
    echo "Тестируем аутентификацию для: $test_email\n\n";
    
    $result = Prostvor\Database::fetchOne(
        "SELECT * FROM authenticate_user(:email, :password)",
        ['email' => $test_email, 'password' => $test_password]
    );
    
    if ($result) {
        echo json_encode([
            'success' => true,
            'message' => 'Аутентификация успешна',
            'user' => $result
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Неверные учетные данные'
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'error' => true,
        'message' => $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
}