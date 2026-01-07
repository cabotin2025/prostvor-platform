<?php
echo "Тестирование защищенного endpoint /api/projects...\n\n";

// 1. Получаем токен
$login_data = json_encode([
    'email' => 'admin@example.com',
    'password' => 'admin123'
]);

$login_context = stream_context_create([
    'http' => [
        'method' => 'POST',
        'header' => 'Content-Type: application/json',
        'content' => $login_data
    ]
]);

echo "1. Аутентификация как администратор...\n";
$login_result = @file_get_contents('http://localhost:8000/api/auth/login', false, $login_context);

if ($login_result === FALSE) {
    echo "❌ Ошибка аутентификации\n";
    exit;
}

$login_response = json_decode($login_result, true);

if (!$login_response['success']) {
    echo "❌ Ошибка: " . ($login_response['error'] ?? 'Unknown') . "\n";
    exit;
}

$token = $login_response['token'];
echo "✅ Токен получен!\n";
echo "   Пользователь: {$login_response['user']['nickname']}\n";
echo "   Email: {$login_response['user']['email']}\n\n";

// 2. Тестируем /api/projects
echo "2. Запрос списка проектов...\n";
$projects_context = stream_context_create([
    'http' => [
        'method' => 'GET',
        'header' => "Authorization: Bearer $token\r\n" .
                   "Content-Type: application/json"
    ]
]);

$projects_result = @file_get_contents('http://localhost:8000/api/projects', false, $projects_context);

if ($projects_result === FALSE) {
    echo "❌ Ошибка при запросе проектов\n";
    $error = error_get_last();
    echo "   Ошибка: " . ($error['message'] ?? 'Unknown') . "\n";
    exit;
}

$projects_response = json_decode($projects_result, true);

if (isset($projects_response['success']) && $projects_response['success']) {
    echo "✅ Успех! Найдено проектов: {$projects_response['count']}\n\n";
    
    if ($projects_response['count'] > 0) {
        echo "Примеры проектов:\n";
        $count = min(3, $projects_response['count']);
        for ($i = 0; $i < $count; $i++) {
            $project = $projects_response['projects'][$i];
            echo ($i + 1) . ". {$project['title']}\n";
            echo "   ID: {$project['project_id']}, Статус: {$project['project_status']}\n";
            if (!empty($project['description'])) {
                echo "   Описание: " . substr($project['description'], 0, 50) . "...\n";
            }
            echo "\n";
        }
    } else {
        echo "ℹ️ Проектов пока нет\n";
    }
} else {
    echo "❌ Ошибка при получении проектов\n";
    echo "   Ответ: " . $projects_result . "\n";
}