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
    // Получаем ID пользователя из токена
    $headers = getallheaders();
    $token = null;
    
    if (isset($headers['Authorization'])) {
        $authHeader = $headers['Authorization'];
        if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
            $token = $matches[1];
        }
    }
    
    if (!$token) {
        // Если нет токена, возвращаем статус гостя
        echo json_encode([
            'success' => true,
            'statuses' => ['Гость'],
            'max_level' => 0,
            'actor_id' => null
        ]);
        exit;
    }
    
    $decoded = JWT::decode($token, JWT_SECRET, ['HS256']);
    $actor_id = $decoded->user_id;
    
    // Получаем текущий статус пользователя
    $stmt = $pdo->prepare("
        SELECT s.status, s.actor_status_id 
        FROM actor_current_statuses acs
        JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
        WHERE acs.actor_id = ?
    ");
    $stmt->execute([$actor_id]);
    $current_status = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // Получаем все доступные статусы для пользователя
    $statuses = [];
    if ($current_status) {
        $statuses[] = $current_status['status'];
        
        // Добавляем дополнительные статусы в зависимости от текущего
        switch($current_status['actor_status_id']) {
            case 7: // Участник ТЦ
                $statuses[] = 'Участник проекта';
                break;
            // Добавьте другие кейсы по необходимости
        }
    }
    
    echo json_encode([
        'success' => true,
        'statuses' => $statuses,
        'current_status' => $current_status,
        'max_level' => $current_status ? $current_status['actor_status_id'] : 0,
        'actor_id' => $actor_id
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}