<?php
// test-actors-statuses.php
echo "<h2>Тестирование /api/actors/statuses.php</h2>";

// Тестируем напрямую
$url = 'http://localhost:8000/api/actors/statuses.php';

// Вариант 1: Через cURL
echo "<h3>1. Проверка через cURL:</h3>";

if (function_exists('curl_init')) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HEADER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Accept: application/json'
    ]);
    
    $response = curl_exec($ch);
    $header_size = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
    $headers = substr($response, 0, $header_size);
    $body = substr($response, $header_size);
    
    echo "<pre>Заголовки:\n" . htmlspecialchars($headers) . "\n\nТело ответа:\n" . htmlspecialchars($body) . "</pre>";
    
    curl_close($ch);
} else {
    echo "cURL не доступен<br>";
}

// Вариант 2: Через file_get_contents с контекстом
echo "<h3>2. Проверка через file_get_contents:</h3>";

$context = stream_context_create([
    'http' => [
        'method' => 'GET',
        'header' => "Accept: application/json\r\n"
    ]
]);

$response = @file_get_contents($url, false, $context);

if ($response === false) {
    echo "❌ Не удалось получить ответ<br>";
    $error = error_get_last();
    echo "Ошибка: " . $error['message'] . "<br>";
} else {
    // Проверяем первые 500 символов
    echo "<pre>" . htmlspecialchars(substr($response, 0, 500)) . "</pre>";
    
    // Проверяем заголовки
    $headers = $http_response_header;
    echo "<h4>Заголовки ответа:</h4>";
    echo "<pre>";
    foreach ($headers as $header) {
        echo htmlspecialchars($header) . "\n";
    }
    echo "</pre>";
}

// Вариант 3: Прямой запуск файла
echo "<h3>3. Прямое выполнение кода:</h3>";

// Временно убираем session_start() для теста
$code = file_get_contents('api/actors/statuses.php');
$code = str_replace("session_start();", "// session_start(); // закомментировано для теста", $code);
$code = str_replace("if (!isset(\$_SESSION['user_id']))", "if (false) // пропускаем проверку авторизации", $code);

// Создаем временный файл для теста
$tempFile = tempnam(sys_get_temp_dir(), 'test_');
file_put_contents($tempFile, $code);

// Запускаем через CLI
echo "<pre>";
system('php -f "' . $tempFile . '" 2>&1');
echo "</pre>";

unlink($tempFile);