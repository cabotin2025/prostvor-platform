<?php
/**
 * API для получения статусов пользователя
 */

require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php';

header('Content-Type: application/json; charset=utf-8');

try {
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        $actor_id = $_GET['actor_id'] ?? null;
        $token = null;
        
        // Получаем токен из заголовка
        $headers = getallheaders();
        if (isset($headers['Authorization'])) {
            if (preg_match('/Bearer\s+(\S+)/', $headers['Authorization'], $matches)) {
                $token = $matches[1];
            }
        }
        
        if (!$token && !$actor_id) {
            // Если нет токена и не указан actor_id, возвращаем гостя
            echo json_encode([
                'success' => true,
                'statuses' => ['Гость'],
                'max_level' => 0,
                'current_status' => null
            ], JSON_UNESCAPED_UNICODE);
            exit;
        }
        
        // Если есть токен, получаем данные из него
        if ($token) {
            try {
                $decoded = JWT::decode($token, JWT_SECRET);
                $actor_id = $decoded->user_id;
                
                // Получаем статус пользователя из БД
                $stmt = $pdo->prepare("
                    SELECT 
                        s.status,
                        s.actor_status_id
                    FROM actor_current_statuses acs
                    JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
                    WHERE acs.actor_id = ?
                ");
                $stmt->execute([$actor_id]);
                $current_status = $stmt->fetch(PDO::FETCH_ASSOC);
                
                // Получаем все доступные статусы (все, которые не выше текущего)
                $current_level = $current_status ? $current_status['actor_status_id'] : 7;
                $stmt = $pdo->prepare("
                    SELECT status 
                    FROM actor_statuses 
                    WHERE actor_status_id <= ?
                    ORDER BY actor_status_id
                ");
                $stmt->execute([$current_level]);
                $all_statuses = $stmt->fetchAll(PDO::FETCH_COLUMN);
                
                echo json_encode([
                    'success' => true,
                    'statuses' => $all_statuses,
                    'current_status' => $current_status,
                    'max_level' => $current_level
                ], JSON_UNESCAPED_UNICODE);
                
            } catch (Exception $e) {
                // Если токен невалиден, возвращаем гостя
                echo json_encode([
                    'success' => true,
                    'statuses' => ['Гость'],
                    'max_level' => 0,
                    'current_status' => null
                ], JSON_UNESCAPED_UNICODE);
            }
        } elseif ($actor_id) {
            // Если указан actor_id, получаем его статус
            $stmt = $pdo->prepare("
                SELECT 
                    s.status,
                    s.actor_status_id
                FROM actor_current_statuses acs
                JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
                WHERE acs.actor_id = ?
            ");
            $stmt->execute([$actor_id]);
            $current_status = $stmt->fetch(PDO::FETCH_ASSOC);
            
            $statuses = $current_status ? [$current_status['status']] : ['Участник ТЦ'];
            $max_level = $current_status ? $current_status['actor_status_id'] : 7;
            
            echo json_encode([
                'success' => true,
                'statuses' => $statuses,
                'current_status' => $current_status,
                'max_level' => $max_level
            ], JSON_UNESCAPED_UNICODE);
        }
        
    } else {
        http_response_code(405);
        echo json_encode([
            'success' => false,
            'message' => 'Метод не разрешен'
        ], JSON_UNESCAPED_UNICODE);
    }
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}