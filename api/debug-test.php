<?php
// /api/debug-test.php
header('Content-Type: application/json; charset=utf-8');

// Самый простой возможный ответ
$response = ['success' => true, 'test' => 'ok'];
echo json_encode($response);
exit;
?>