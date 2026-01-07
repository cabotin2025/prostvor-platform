<?php
echo "Тестирование endpoint /api/actors...\n\n";

// Используем любого пользователя для теста
$email = 'dev@prostvor.local';
$password = 'developer';

// 1. Аутентификация
$login_data = json_encode(['email' => $email, 'password' => $password]);
$login_context = stream_context_create([
    'http' => [
        'method' => 'POST',
        'header' => 'Content-Type: application/json',
        'content' => $login_data
    ]
]);

echo "1. Аутентификация как $email...\n";
$login_result = @file_get_contents('http://localhost:8000/api/auth/login', false, $login_context);

if ($login_result === FALSE) {
    die("❌ Ошибка аутентификации\n");
}

$login_response = json_decode($login_result, true);
$token = $login_response['token'];

// 2. Тестируем /api/actors
echo "2. Запрос списка участников...\n";
$actors_context = stream_context_create([
    'http' => [
        'method' => 'GET',
        'header' => "Authorization: Bearer $token\r\n" .
                   "Content-Type: application/json"
    ]
]);

$actors_result = @file_get_contents('http://localhost:8000/api/actors', false, $actors_context);

if ($actors_result === FALSE) {
    die("❌ Ошибка при запросе участников\n");
}

$actors_response = json_decode($actors_result, true);

if (isset($actors_response['success']) && $actors_response['success']) {
    echo "✅ Успех! Найдено участников: " . ($actors_response['count'] ?? count($actors_response['actors'] ?? [])) . "\n\n";
    
    if (!empty($actors_response['actors'])) {
        echo "Первые 5 участников:\n";
        $count = min(5, count($actors_response['actors']));
        for ($i = 0; $i < $count; $i++) {
            $actor = $actors_response['actors'][$i];
            echo ($i + 1) . ". {$actor['nickname']} (ID: {$actor['actor_id']})\n";
            if (!empty($actor['email'])) {
                echo "   Email: {$actor['email']}\n";
            }
            echo "\n";
        }
    }
} else {
    echo "❌ Ошибка: " . ($actors_response['error'] ?? 'Unknown') . "\n";
    echo "Полный ответ: $actors_result\n";
}