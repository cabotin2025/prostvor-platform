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
    $query = $_GET['query'] ?? '';
    
    if (strlen($query) < 2) {
        echo json_encode(['success' => true, 'actors' => []]);
        exit;
    }
    
    // Получаем ID текущего пользователя для проверки прав
    $current_user_id = null;
    try {
        $headers = getallheaders();
        if (isset($headers['Authorization'])) {
            $authHeader = $headers['Authorization'];
            if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
                $token = $matches[1];
                $decoded = JWT::decode($token, JWT_SECRET, ['HS256']);
                $current_user_id = $decoded->user_id;
            }
        }
    } catch (Exception $e) {
        // Пользователь не авторизован - можно искать только публичные данные
    }
    
    // Поиск пользователей
    $search_query = '%' . $query . '%';
    
    $stmt = $pdo->prepare("
        SELECT 
            a.actor_id,
            a.username,
            a.nickname,
            a.email,
            at.type as actor_type,
            s.status as global_status
        FROM actors a
        LEFT JOIN actor_types at ON a.actor_type_id = at.actor_type_id
        LEFT JOIN actor_current_statuses acs ON a.actor_id = acs.actor_id
        LEFT JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
        WHERE a.deleted_at IS NULL 
          AND (a.username LIKE ? OR a.email LIKE ? OR a.nickname LIKE ?)
        ORDER BY a.username
        LIMIT 20
    ");
    
    $stmt->execute([$search_query, $search_query, $search_query]);
    $actors = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Фильтруем конфиденциальные данные в зависимости от прав
    foreach ($actors as &$actor) {
        // Только авторизованные пользователи могут видеть email
        if (!$current_user_id) {
            unset($actor['email']);
        }
        
        // Дополнительные ограничения по статусу
        if ($current_user_id) {
            // Проверяем права текущего пользователя
            $stmt = $pdo->prepare("
                SELECT s.status 
                FROM actor_current_statuses acs
                JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
                WHERE acs.actor_id = ?
            ");
            $stmt->execute([$current_user_id]);
            $current_user_status = $stmt->fetch(PDO::FETCH_COLUMN);
            
            // Только Руководитель ТЦ, Куратор направления, Руководитель проекта видят полные контакты
            if (!in_array($current_user_status, ['Руководитель ТЦ', 'Куратор направления', 'Руководитель проекта'])) {
                unset($actor['email']);
            }
        }
    }
    
    echo json_encode([
        'success' => true,
        'actors' => $actors,
        'count' => count($actors)
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}