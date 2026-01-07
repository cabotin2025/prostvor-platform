<?php
echo "📊 ИНТЕГРАЦИОННЫЙ ТЕСТ PROSTVOR PLATFORM API\n";
echo "=========================================\n\n";

$base_url = 'http://localhost:8000';
$test_user = ['email' => 'admin@example.com', 'password' => 'admin123'];

// 1. Тест корневого endpoint
echo "1. Тест корневого endpoint (GET /)...\n";
$root_result = @file_get_contents($base_url . '/');
if ($root_result) {
    $root_data = json_decode($root_result, true);
    echo "   ✅ Статус: {$root_data['app']} v{$root_data['version']}\n";
} else {
    echo "   ❌ Ошибка\n";
}

// 2. Тест аутентификации
echo "\n2. Тест аутентификации (POST /api/auth/login)...\n";
$login_data = json_encode($test_user);
$login_context = stream_context_create([
    'http' => [
        'method' => 'POST',
        'header' => 'Content-Type: application/json',
        'content' => $login_data
    ]
]);

$login_result = @file_get_contents($base_url . '/api/auth/login', false, $login_context);
if ($login_result) {
    $login_data = json_decode($login_result, true);
    if ($login_data['success']) {
        $token = $login_data['token'];
        echo "   ✅ Успех! Токен получен\n";
        echo "   👤 Пользователь: {$login_data['user']['nickname']}\n";
    } else {
        echo "   ❌ Ошибка: {$login_data['error']}\n";
    }
} else {
    echo "   ❌ Ошибка подключения\n";
}

// 3. Тест защищенных endpoints
if (isset($token)) {
    echo "\n3. Тест защищенных endpoints...\n";
    
    $auth_header = "Authorization: Bearer $token\r\nContent-Type: application/json";
    
    // Проекты
    $projects_context = stream_context_create(['http' => ['method' => 'GET', 'header' => $auth_header]]);
    $projects_result = @file_get_contents($base_url . '/api/projects', false, $projects_context);
    if ($projects_result) {
        $projects_data = json_decode($projects_result, true);
        echo "   📋 /api/projects: ";
        if (isset($projects_data['success']) && $projects_data['success']) {
            echo "✅ {$projects_data['count']} проектов\n";
        } else {
            echo "❌ {$projects_data['error']}\n";
        }
    }
    
    // Участники
    $actors_context = stream_context_create(['http' => ['method' => 'GET', 'header' => $auth_header]]);
    $actors_result = @file_get_contents($base_url . '/api/actors', false, $actors_context);
    if ($actors_result) {
        $actors_data = json_decode($actors_result, true);
        echo "   👥 /api/actors: ";
        if (isset($actors_data['success']) && $actors_data['success']) {
            echo "✅ " . ($actors_data['count'] ?? '?') . " участников\n";
        } else {
            echo "❌ {$actors_data['error']}\n";
        }
    }
}

echo "\n🎉 ТЕСТИРОВАНИЕ ЗАВЕРШЕНО!\n";