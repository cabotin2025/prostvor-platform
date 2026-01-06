<?php
require_once 'includes/Database.php';
$db = Database::getConnection();
$stmt = $db->query("SELECT * FROM test_users");
$users = $stmt->fetchAll();
echo json_encode(['count' => count($users), 'users' => $users], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);