<?php
// test-all-problematic-apis.php
echo "<h2>🔍 Тестирование всех проблемных API</h2>";

$apis = [
    [
        'name' => 'auth/me.php',
        'url' => 'http://localhost:8000/api/auth/me.php',
        'headers' => ['Accept: application/json']
    ],
    [
        'name' => 'projects/index.php',
        'url' => 'http://localhost:8000/api/projects/index.php',
        'headers' => ['Accept: application/json']
    ],
    [
        'name' => 'auth/check-token.php',
        'url' => 'http://localhost:8000/api/auth/check-token.php',
        'headers' => ['Accept: application/json']
    ],
    [
        'name' => 'actors/index.php',
        'url' => 'http://localhost:8000/api/actors/index.php',
        'headers' => ['Accept: application/json']
    ]
];

foreach ($apis as $api) {
    echo "<h3>📡 Тестирую: {$api['name']}</h3>";
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $api['url']);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $api['headers']);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $contentType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
    
    echo "HTTP: $httpCode, Content-Type: $contentType<br>";
    
    if ($httpCode !== 200) {
        echo "❌ HTTP код не 200<br>";
    }
    
    // Проверяем первые символы
    $firstChar = substr($response, 0, 1);
    echo "Первый символ ответа: '" . htmlspecialchars($firstChar) . "'<br>";
    
    if ($firstChar === '{' || $firstChar === '[') {
        // Пробуем декодировать JSON
        $json = json_decode($response);
        if (json_last_error() === JSON_ERROR_NONE) {
            echo "✅ Валидный JSON<br>";
            
            // Проверяем структуру
            if (isset($json->data) || isset($json->success)) {
                echo "✅ Правильная структура<br>";
            }
        } else {
            echo "❌ Невалидный JSON: " . json_last_error_msg() . "<br>";
            echo "<details><summary>Ответ (первые 300 символов):</summary><pre>" . 
                 htmlspecialchars(substr($response, 0, 300)) . "</pre></details>";
        }
    } else {
        echo "⚠️ Ответ не JSON (начинается не с '{' или '[')<br>";
        echo "<details><summary>Ответ (первые 300 символов):</summary><pre>" . 
             htmlspecialchars(substr($response, 0, 300)) . "</pre></details>";
        
        // Проверяем на HTML/ошибки PHP
        if (strpos($response, '<') !== false) {
            echo "🔍 Содержит HTML/XML теги<br>";
            
            if (strpos($response, 'error') !== false || 
                strpos($response, 'Warning') !== false ||
                strpos($response, 'Fatal') !== false) {
                echo "⚠️ Содержит ошибки PHP!<br>";
            }
        }
    }
    
    echo "<hr>";
}