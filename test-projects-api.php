<?php
// test-projects-api.php
echo "<h2>Тестирование api/projects/index.php</h2>";

$url = 'http://localhost:8000/api/projects/index.php';

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Accept: application/json'
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

echo "HTTP Code: $httpCode<br>";
echo "Ответ (первые 500 символов): <pre>" . htmlspecialchars(substr($response, 0, 500)) . "</pre><br>";

// Проверяем Content-Type
$contentType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
echo "Content-Type: $contentType<br>";

// Проверяем JSON
$json = json_decode($response);
if (json_last_error() === JSON_ERROR_NONE) {
    echo "✅ Валидный JSON<br>";
    
    // Проверяем структуру
    if (isset($json->success)) {
        echo "✅ Есть поле 'success'<br>";
    }
    
    if (isset($json->data)) {
        echo "✅ Есть поле 'data'<br>";
    } else {
        echo "⚠️ Нет поля 'data'<br>";
    }
} else {
    echo "❌ Невалидный JSON: " . json_last_error_msg() . "<br>";
    
    // Проверяем на HTML
    if (strpos($response, '<!DOCTYPE') !== false || 
        strpos($response, '<html') !== false ||
        strpos($response, '<br') !== false) {
        echo "⚠️ API возвращает HTML вместо JSON!<br>";
        
        // Ищем возможные причины
        if (strpos($response, 'Parse error') !== false || 
            strpos($response, 'Fatal error') !== false) {
            echo "🔍 Обнаружена ошибка PHP в ответе<br>";
        }
    }
}