<?php
/**
 * Получение данных текущего пользователя
 */

require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

try {
    // Получаем токен из заголовка
    $token = null;
    $headers = getallheaders();
    
    if (isset($headers['Authorization'])) {
        if (preg_match('/Bearer\s+(\S+)/', $headers['Authorization'], $matches)) {
            $token = $matches[1];
        }
    }
    
    if (!$token) {
        throw new Exception('Требуется авторизация');
    }
    
    // Декодируем токен
    $decoded = JWT::decode($token, JWT_SECRET);
    
    // Получаем полные данные пользователя из БД
    $stmt = $pdo->prepare("
        SELECT 
            a.actor_id,
            a.nickname,
            a.account,
            a.actor_type_id,
            p.person_id,
            p.name,
            p.last_name,
            p.email,
            p.phone_number,
            p.location_id,
            l.name as location_name,
            acs.actor_status_id,
            s.status as global_status,
            s.description as status_description
        FROM actors a
        LEFT JOIN persons p ON a.actor_id = p.actor_id
        LEFT JOIN locations l ON p.location_id = l.location_id
        LEFT JOIN actor_current_statuses acs ON a.actor_id = acs.actor_id
        LEFT JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
        WHERE a.actor_id = :actor_id
          AND a.deleted_at IS NULL
        LIMIT 1
    ");
    
    $stmt->execute([':actor_id' => $decoded->user_id]);
    $user_data = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user_data) {
        throw new Exception('Пользователь не найден');
    }
    
    // Получаем роли в проектах
    $stmt = $pdo->prepare("
        SELECT 
            p.project_id,
            p.title as project_name,
            par.role_type
        FROM project_actor_roles par
        JOIN projects p ON par.project_id = p.project_id
        WHERE par.actor_id = :actor_id 
          AND p.deleted_at IS NULL
    ");
    $stmt->execute([':actor_id' => $decoded->user_id]);
    $project_roles = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'actor' => $user_data,
        'project_roles' => $project_roles,
        'token_data' => $decoded
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}