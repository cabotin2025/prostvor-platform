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
        throw new Exception('Authorization token not found');
    }
    
    $decoded = JWT::decode($token, JWT_SECRET, ['HS256']);
    $actor_id = $decoded->user_id;
    
    // Получаем данные пользователя
    $stmt = $pdo->prepare("
        SELECT 
            a.actor_id,
            a.username,
            a.email,
            a.nickname,
            a.actor_type_id,
            at.type as actor_type,
            acs.actor_status_id,
            s.status as global_status,
            al.location_id,
            l.name as locality_name
        FROM actors a
        LEFT JOIN actor_types at ON a.actor_type_id = at.actor_type_id
        LEFT JOIN actor_current_statuses acs ON a.actor_id = acs.actor_id
        LEFT JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
        LEFT JOIN actors_locations al ON a.actor_id = al.actor_id
        LEFT JOIN locations l ON al.location_id = l.id
        WHERE a.actor_id = ? AND a.deleted_at IS NULL
    ");
    
    $stmt->execute([$actor_id]);
    $user_data = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user_data) {
        throw new Exception('User not found');
    }
    
    // Получаем роли пользователя в проектах
    $stmt = $pdo->prepare("
        SELECT 
            p.project_id,
            p.title as project_name,
            par.role_type,
            CASE par.role_type
                WHEN 'leader' THEN 'Руководитель проекта'
                WHEN 'admin' THEN 'Администратор проекта'
                WHEN 'member' THEN 'Участник проекта'
                WHEN 'curator' THEN 'Проектный куратор'
            END as role_name
        FROM project_actor_roles par
        JOIN projects p ON par.project_id = p.project_id
        WHERE par.actor_id = ? AND p.deleted_at IS NULL
    ");
    
    $stmt->execute([$actor_id]);
    $project_roles = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Получаем творческие направления пользователя (для кураторов)
    $stmt = $pdo->prepare("
        SELECT 
            d.direction_id,
            d.name as direction_name
        FROM actors_directions ad
        JOIN directions d ON ad.direction_id = d.direction_id
        WHERE ad.actor_id = ?
    ");
    
    $stmt->execute([$actor_id]);
    $directions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'actor' => $user_data,
        'project_roles' => $project_roles,
        'directions' => $directions
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}