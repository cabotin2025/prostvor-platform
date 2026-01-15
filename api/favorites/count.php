<?php
// api/favorites/count.php
require_once __DIR__ . '/../helpers/auth_check.php';
header('Content-Type: application/json');

$actor_id = getAuthenticatedActorId();

try {
    $sql = "SELECT COUNT(*) as count FROM favorites WHERE actor_id = ?";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$actor_id]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'count' => (int)$result['count']
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка получения счетчика'
    ]);
}
?>