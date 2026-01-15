<?php
// /api/test-db-connection.php
require_once 'config/database.php';

// Если мы дошли сюда, подключение успешно
echo json_encode([
    'success' => true,
    'message' => 'Database connection successful',
    'timestamp' => date('Y-m-d H:i:s')
]);
?>