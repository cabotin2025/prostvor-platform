<?php
require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

try {
    $headers = getallheaders();
    $token = null;
    
    if (isset($headers['Authorization'])) {
        $authHeader = $headers['Authorization'];
        if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
            $token = $matches[1];
        }
    }
    
    if (!$token) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Token not provided']);
        exit;
    }
    
    // Верифицируем токен
    $decoded = JWT::decode($token, JWT_SECRET, ['HS256']);
    
    // Получаем статус пользователя
    $stmt = $pdo->prepare("
        SELECT s.status 
        FROM actor_current_statuses acs
        JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
        WHERE acs.actor_id = ?
    ");
    
    $stmt->execute([$decoded->user_id]);
    $status = $stmt->fetch(PDO::FETCH_COLUMN);
    
    echo json_encode([
        'success' => true,
        'message' => 'Token is valid',
        'user_id' => $decoded->user_id,
        'username' => $decoded->username,
        'global_status' => $status,
        'locality_id' => $decoded->locality_id ?? null
    ]);
    
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Invalid token: ' . $e->getMessage()]);
}