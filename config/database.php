<?php
/**
 * Конфигурация подключения к базе данных PostgreSQL
 * ПРАВИЛЬНЫЕ НАСТРОЙКИ:
 */

// Включение отображения ошибок
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Параметры подключения ДЛЯ ВАШЕГО СЕРВЕРА
$host = 'localhost';
$port = '5432';
$dbname = 'creative_center_base'; // Ваша реальная база
$username = 'postgres';
$password = '123456'; // ← ВАШ ПАРОЛЬ!

// Для отладки
$development_mode = true;

try {
    // DSN строка
    $dsn = "pgsql:host=$host;port=$port;dbname=$dbname";
    
    // Создаем соединение
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
        PDO::ATTR_PERSISTENT => false
    ]);
    
    // Устанавливаем UTF-8 для PostgreSQL
    $pdo->exec("SET client_encoding TO 'UTF8'");
    
    if ($development_mode) {
        error_log("✅ Database connected: $dbname");
    }
    
} catch (PDOException $e) {
    // Подробная ошибка
    $error_details = [
        'message' => $e->getMessage(),
        'code' => $e->getCode()
    ];
    
    error_log("❌ Database connection failed: " . print_r($error_details, true));
    
    header('Content-Type: application/json; charset=utf-8');
    http_response_code(500);
    
    $error_message = $development_mode 
        ? "Database connection failed: " . $e->getMessage()
        : "Database connection failed";
    
    echo json_encode([
        'success' => false,
        'message' => $error_message,
        'error_details' => $development_mode ? $error_details : null
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

global $pdo;