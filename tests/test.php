<?php
// api/test.php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

try {
    require_once '../config/database.php';
    require_once '../lib/Database.php';
    
    $db = Database::getInstance()->getConnection();
    
    $response = [
        'status' => 'success',
        'message' => 'API работает!',
        'database' => [
            'connected' => true,
            'name' => DatabaseConfig::DB_NAME,
            'tables_count' => null
        ],
        'timestamp' => date('Y-m-d H:i:s')
    ];
    
    // Получаем количество таблиц
    $stmt = $db->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'");
    $response['database']['tables_count'] = $stmt->fetchColumn();
    
    echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch(Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ], JSON_PRETTY_PRINT);
}
