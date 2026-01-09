<?php
/**
 * Тестовый скрипт с исправлением кодировки
 */

// Прямые настройки
$host = 'localhost';
$port = '5432';
$dbname = 'creative_center_base';
$username = 'postgres';
$password = '123456'; // Ваш пароль

header('Content-Type: application/json; charset=utf-8');

try {
    // Подключаемся без установки кодировки в DSN
    $dsn = "pgsql:host=$host;port=$port;dbname=$dbname";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    
    // Получаем информацию о базе
    $stmt = $pdo->query("SELECT version()");
    $version = $stmt->fetchColumn();
    
    // Проверяем основные таблицы
    $tables = ['actors', 'persons', 'actor_credentials'];
    $results = [];
    
    foreach ($tables as $table) {
        try {
            $stmt = $pdo->query("SELECT COUNT(*) FROM $table");
            $results[$table] = [
                'count' => $stmt->fetchColumn(),
                'exists' => true
            ];
        } catch (Exception $e) {
            $results[$table] = [
                'exists' => false,
                'error' => $e->getMessage()
            ];
        }
    }
    
    // Проверяем русский текст с разными кодировками
    $stmt = $pdo->query("SELECT nickname FROM actors WHERE actor_id = 1");
    $raw_text = $stmt->fetchColumn();
    
    // Пробуем разные кодировки
    $encodings = ['UTF-8', 'Windows-1251', 'CP866', 'KOI8-R', 'ISO-8859-5'];
    $decoded_texts = [];
    
    foreach ($encodings as $encoding) {
        if (mb_check_encoding($raw_text, $encoding)) {
            $decoded_texts[$encoding] = $raw_text;
        } else {
            $decoded = @mb_convert_encoding($raw_text, 'UTF-8', $encoding);
            $decoded_texts[$encoding] = $decoded ?: '(не удалось декодировать)';
        }
    }
    
    echo json_encode([
        'success' => true,
        'message' => '✅ Подключение к базе данных успешно!',
        'database' => $dbname,
        'postgresql_version' => $version,
        'tables' => $results,
        'encoding_test' => [
            'raw_bytes' => bin2hex($raw_text),
            'raw_length' => strlen($raw_text),
            'decoded_versions' => $decoded_texts,
            'likely_encoding' => mb_detect_encoding($raw_text, $encodings)
        ],
        'connection' => [
            'host' => $host,
            'port' => $port,
            'username' => $username,
            'database' => $dbname,
            'status' => 'connected'
        ]
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => '❌ Ошибка подключения к PostgreSQL',
        'error' => $e->getMessage(),
        'error_code' => $e->getCode(),
        'troubleshooting' => [
            '1. Проверьте, запущен ли PostgreSQL: netstat -an | find "5432"',
            '2. Проверьте пароль пользователя postgres',
            '3. Проверьте права доступа к базе creative_center_base',
            '4. Попробуйте подключиться через pgAdmin4 с теми же параметрами'
        ],
        'connection_attempt' => [
            'host' => $host,
            'port' => $port,
            'database' => $dbname,
            'username' => $username
        ]
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
}