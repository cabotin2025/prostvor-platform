<?php
/**
 * Тестовый скрипт для проверки подключения к базе данных
 */

require_once '../config/database.php';

header('Content-Type: application/json');

try {
    // Проверяем основные таблицы
    $tables_to_check = ['actors', 'persons', 'actor_statuses', 'actor_credentials'];
    $results = [];
    
    foreach ($tables_to_check as $table) {
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM $table");
        $results[$table] = $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    // Получаем информацию о сервере БД
    $server_info = $pdo->getAttribute(PDO::ATTR_SERVER_VERSION);
    $driver_info = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);
    
    echo json_encode([
        'success' => true,
        'message' => '✅ Database connection successful!',
        'database_info' => [
            'server_version' => $server_info,
            'driver' => $driver_info,
            'tables' => $results
        ],
        'connection_details' => [
            'host' => 'localhost',
            'database' => 'creative_center_base',
            'status' => 'connected'
        ]
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => '❌ Database connection failed',
        'error' => $e->getMessage(),
        'error_code' => $e->getCode(),
        'connection_details' => [
            'host' => 'localhost',
            'database' => 'creative_center_base',
            'status' => 'failed'
        ],
        'troubleshooting' => [
            '1. Проверьте, запущен ли сервер PostgreSQL',
            '2. Проверьте правильность имени базы данных',
            '3. Проверьте логин и пароль пользователя БД',
            '4. Проверьте права доступа к базе данных'
        ]
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}