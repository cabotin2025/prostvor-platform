<?php
/**
 * Получение данных текущего пользователя - ФИНАЛЬНАЯ ВЕРСИЯ
 * Использует правильную структуру базы данных
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
    $actor_id = $decoded->user_id;
    
    // Получаем полные данные пользователя с учетом типа актора
    $stmt = $pdo->prepare("
        SELECT 
            a.actor_id,
            a.nickname,
            a.account,
            a.actor_type_id,
            a.color_frame,
            a.icon,
            a.keywords,
            
            -- Основные данные в зависимости от типа
            CASE 
                WHEN a.actor_type_id = 1 THEN (
                    SELECT p.name FROM persons p 
                    WHERE p.actor_id = a.actor_id 
                    LIMIT 1
                )
                WHEN a.actor_type_id = 2 THEN (
                    SELECT c.title FROM communities c 
                    WHERE c.actor_id = a.actor_id 
                    LIMIT 1
                )
                WHEN a.actor_type_id = 3 THEN (
                    SELECT o.title FROM organizations o 
                    WHERE o.actor_id = a.actor_id 
                    LIMIT 1
                )
                ELSE a.nickname
            END as display_name,
            
            CASE 
                WHEN a.actor_type_id = 1 THEN (
                    SELECT p.last_name FROM persons p 
                    WHERE p.actor_id = a.actor_id 
                    LIMIT 1
                )
                ELSE ''
            END as last_name,
            
            CASE 
                WHEN a.actor_type_id = 1 THEN (
                    SELECT p.email FROM persons p 
                    WHERE p.actor_id = a.actor_id 
                    LIMIT 1
                )
                WHEN a.actor_type_id = 2 THEN (
                    SELECT c.email FROM communities c 
                    WHERE c.actor_id = a.actor_id 
                    LIMIT 1
                )
                WHEN a.actor_type_id = 3 THEN (
                    SELECT o.email FROM organizations o 
                    WHERE o.actor_id = a.actor_id 
                    LIMIT 1
                )
                ELSE ''
            END as email,
            
            -- Статус
            acs.actor_status_id,
            ast.status as actor_status
            
        FROM actors a
        LEFT JOIN actor_current_statuses acs ON a.actor_id = acs.actor_id
        LEFT JOIN actor_statuses ast ON acs.actor_status_id = ast.actor_status_id
        WHERE a.actor_id = :actor_id
          AND a.deleted_at IS NULL
        LIMIT 1
    ");
    
    $stmt->execute([':actor_id' => $actor_id]);
    $actor_data = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$actor_data) {
        throw new Exception('Пользователь не найден');
    }
    
    // Получаем роли в проектах
    $stmt = $pdo->prepare("
        SELECT 
            p.project_id,
            p.title as project_title,
            par.role_type,
            par.assigned_at
        FROM project_actor_roles par
        JOIN projects p ON par.project_id = p.project_id
        WHERE par.actor_id = :actor_id 
          AND p.deleted_at IS NULL
    ");
    $stmt->execute([':actor_id' => $actor_id]);
    $project_roles = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Формируем ответ
    $response = [
        'success' => true,
        'actor' => [
            'actor_id' => (int)$actor_data['actor_id'],
            'nickname' => $actor_data['nickname'],
            'display_name' => $actor_data['display_name'],
            'last_name' => $actor_data['last_name'],
            'email' => $actor_data['email'],
            'account' => $actor_data['account'],
            'actor_type_id' => (int)$actor_data['actor_type_id'],
            'color_frame' => $actor_data['color_frame'],
            'icon' => $actor_data['icon'],
            'actor_status_id' => $actor_data['actor_status_id'] ? (int)$actor_data['actor_status_id'] : 7,
            'actor_status' => $actor_data['actor_status'] ? $actor_data['actor_status'] : 'Участник ТЦ'
        ],
        'project_roles' => $project_roles
    ];
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}