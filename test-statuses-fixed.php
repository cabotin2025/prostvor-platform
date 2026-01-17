<?php
// test-statuses-fixed.php
echo "<h2>Тестирование исправленного statuses.php</h2>";

// Создаем временную копию с исправлениями
$original = file_get_contents('api/actors/statuses.php');
$fixed = str_replace(
    'require_once \'../../config/database.php\';',
    'require_once \'../../config/database.php\';
require_once \'../../lib/Database.php\';',
    $original
);

$fixed = str_replace('$stmt = $pdo->prepare', '$db = Database::getInstance()->getConnection(); $stmt = $db->prepare', $fixed);
$fixed = str_replace('$pdo->prepare', '$db->prepare', $fixed);

$tempFile = tempnam(sys_get_temp_dir(), 'statuses_');
file_put_contents($tempFile, $fixed);

// Тестируем через веб-сервер
echo "<h3>1. Тест через localhost:</h3>";
$url = 'http://localhost:8000/api/actors/statuses.php';

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Accept: application/json'
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

echo "HTTP Code: $httpCode<br>";
echo "Ответ: <pre>" . htmlspecialchars($response) . "</pre>";

// Проверяем JSON
$json = json_decode($response);
if (json_last_error() === JSON_ERROR_NONE) {
    echo "✅ Валидный JSON<br>";
    
    if (isset($json->data)) {
        echo "✅ Есть поле 'data'<br>";
        echo "Количество элементов в data: " . (is_array($json->data) ? count($json->data) : 'не массив') . "<br>";
    } else {
        echo "⚠️ Нет поля 'data'<br>";
    }
    
    if (isset($json->statuses)) {
        echo "✅ Есть поле 'statuses' (для обратной совместимости)<br>";
    }
} else {
    echo "❌ Невалидный JSON: " . json_last_error_msg() . "<br>";
}

curl_close($ch);

echo "<hr><h3>2. Проверка структуры ответа для фронтенда:</h3>";

// Симулируем запрос фронтенда
$testResponse = json_decode($response, true);
if ($testResponse && isset($testResponse['data'])) {
    echo "Структура поля 'data':<br>";
    if (is_array($testResponse['data']) && count($testResponse['data']) > 0) {
        $firstItem = $testResponse['data'][0];
        echo "<pre>" . print_r($firstItem, true) . "</pre>";
        
        // Проверяем наличие нужных полей
        $requiredFields = ['id', 'name'];
        $missing = [];
        foreach ($requiredFields as $field) {
            if (!isset($firstItem[$field])) {
                $missing[] = $field;
            }
        }
        
        if (empty($missing)) {
            echo "✅ Все необходимые поля присутствуют<br>";
        } else {
            echo "❌ Отсутствуют поля: " . implode(', ', $missing) . "<br>";
        }
    }
}

unlink($tempFile);