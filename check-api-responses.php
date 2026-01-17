<?php
// check-api-responses.php
echo "<h2>🔍 Проверка ответов API</h2>";

$endpoints = [
    '/api/actors/statuses.php',
    '/api/auth/me.php',
    '/api/auth/check-token.php',
    '/api/projects/index.php'
];

foreach ($endpoints as $endpoint) {
    echo "<h3>Проверка: $endpoint</h3>";
    
    $url = 'http://localhost:8000' . $endpoint;
    
    // Проверяем через file_get_contents
    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => "Accept: application/json\r\n"
        ]
    ]);
    
    $response = @file_get_contents($url, false, $context);
    
    if ($response === false) {
        echo "❌ Не удалось получить ответ<br>";
        continue;
    }
    
    // Проверяем первые 100 символов
    $first100 = substr($response, 0, 100);
    echo "Первые 100 символов: <pre>" . htmlspecialchars($first100) . "</pre>";
    
    // Проверяем, это JSON или HTML?
    if (strpos($response, '<!DOCTYPE') !== false || 
        strpos($response, '<html') !== false ||
        strpos($response, '<br') !== false) {
        echo "⚠️ Ответ содержит HTML! Должен быть JSON<br>";
        
        // Показываем заголовки
        $headers = get_headers($url, 1);
        echo "Заголовки: <pre>";
        print_r($headers);
        echo "</pre>";
    } else {
        // Пробуем декодировать JSON
        $json = json_decode($response);
        if (json_last_error() === JSON_ERROR_NONE) {
            echo "✅ Валидный JSON<br>";
        } else {
            echo "❌ Невалидный JSON: " . json_last_error_msg() . "<br>";
        }
    }
    
    echo "<hr>";
}