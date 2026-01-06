<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once '../includes/Database.php';

// Тестируем подключение
$testResult = Database::testConnection();
echo json_encode($testResult, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
?>