<?php
/**
 * Конфигурация подключения к базе данных PostgreSQL
 */
header('Content-Type: application/json; charset=utf-8');

// Отключаем вывод ошибок в браузер
error_reporting(0);
ini_set('display_errors', 0);

// Параметры подключения
$host = 'localhost';
$port = '5432';
$dbname = 'creative_center_base';
$username = 'postgres';
$password = '123456';

try {
    $dsn = "pgsql:host=$host;port=$port;dbname=$dbname";
    
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false
    ]);
    
    $pdo->exec("SET client_encoding TO 'UTF8'");
    
    // Успех - не выводим ничего!
    // Просто оставляем $pdo доступной
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database connection failed',
        'debug' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

global $pdo;
?>