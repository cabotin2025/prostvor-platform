<?php
// test-auth-me.php
echo "<h2>Тестирование api/auth/me.php</h2>";

$url = 'http://localhost:8000/api/auth/me.php';

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Accept: application/json',
    'Content-Type: application/json'
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

echo "HTTP Code: $httpCode<br>";
echo "Ответ: <pre>" . htmlspecialchars($response) . "</pre><br>";

// Проверяем что возвращается
if ($response && $response[0] === '{') {
    $json = json_decode($response);
    if (json_last_error() === JSON_ERROR_NONE) {
        echo "✅ Валидный JSON<br>";
    } else {
        echo "❌ Невалидный JSON: " . json_last_error_msg() . "<br>";
        
        // Проверяем первые символы
        echo "Первые 100 символов: <pre>" . htmlspecialchars(substr($response, 0, 100)) . "</pre>";
        
        // Проверяем, не HTML ли это
        if (strpos($response, '<!DOCTYPE') !== false || strpos($response, '<html') !== false) {
            echo "⚠️ Возвращается HTML вместо JSON!<br>";
        }
    }
} else {
    echo "⚠️ Ответ не начинается с '{'<br>";
    echo "Ответ полностью: <pre>" . htmlspecialchars($response) . "</pre>";
}