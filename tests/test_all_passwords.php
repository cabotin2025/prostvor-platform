<?php
require_once 'config/database.php';
require_once 'lib/Database.php';

echo "Тестирование паролей для существующих пользователей...\n\n";

$test_cases = [
    ['email' => 'admin@example.com', 'password' => 'admin123'],
    ['email' => 'dev@prostvor.local', 'password' => 'developer'],
    ['email' => 'newuser@example.com', 'password' => 'NewPassword123'],
    ['email' => 'seconduser@example.com', 'password' => 'SecondPass456'],
    ['email' => 'success_user@example.com', 'password' => 'SuccessPass123'],
    ['email' => 'test_final@test.com', 'password' => 'TestPassword123']
];

foreach ($test_cases as $test) {
    echo "Тестируем: {$test['email']}... ";
    
    $data = json_encode($test);
    $context = stream_context_create([
        'http' => [
            'method' => 'POST',
            'header' => 'Content-Type: application/json',
            'content' => $data
        ]
    ]);
    
    try {
        $result = file_get_contents('http://localhost:8000/api/auth/login', false, $context);
        $response = json_decode($result, true);
        
        if (isset($response['success']) && $response['success']) {
            echo "✅ УСПЕХ! Токен получен\n";
            echo "   Actor ID: {$response['user']['actor_id']}\n";
            echo "   Токен: " . substr($response['token'], 0, 20) . "...\n";
        } else {
            echo "❌ ОШИБКА: " . ($response['error'] ?? 'Unknown error') . "\n";
        }
    } catch (Exception $e) {
        echo "❌ ОШИБКА запроса: " . $e->getMessage() . "\n";
    }
    
    echo "\n";
}