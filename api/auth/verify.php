<?php
/**
 * Проверка JWT токена - ОБНОВЛЕННАЯ ВЕРСИЯ
 */

require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

try {
    $token = null;
    
    // 1. Пробуем получить из GET параметра (для тестов)
    if (isset($_GET['token']) && !empty($_GET['token'])) {
        $token = $_GET['token'];
    }
    // 2. Из заголовка Authorization
    elseif (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $auth_header = $_SERVER['HTTP_AUTHORIZATION'];
        if (preg_match('/Bearer\s+(\S+)/', $auth_header, $matches)) {
            $token = $matches[1];
        }
    }
    // 3. Из POST данных
    elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = file_get_contents('php://input');
        $data = json_decode($input, true);
        if (isset($data['token'])) {
            $token = $data['token'];
        }
    }
    
    if (!$token) {
        // Для отладки: если нет токена, возвращаем информацию
        echo json_encode([
            'success' => false,
            'valid' => false,
            'message' => 'Токен не предоставлен',
            'debug' => [
                'method' => $_SERVER['REQUEST_METHOD'],
                'auth_header' => $_SERVER['HTTP_AUTHORIZATION'] ?? 'не установлен',
                'get_token' => $_GET['token'] ?? 'не установлен'
            ]
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // Декодируем токен
    $decoded = JWT::decode($token, JWT_SECRET);
    
    // Получаем данные пользователя из БД
    $stmt = $pdo->prepare("
        SELECT 
            a.nickname,
            p.email,
            p.name,
            p.last_name,
            acs.actor_status_id,
            s.status as global_status
        FROM actors a
        LEFT JOIN persons p ON a.actor_id = p.actor_id
        LEFT JOIN actor_current_statuses acs ON a.actor_id = acs.actor_id
        LEFT JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
        WHERE a.actor_id = :actor_id
    ");
    
    $stmt->execute([':actor_id' => $decoded->user_id]);
    $user_data = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'valid' => true,
        'message' => 'Токен валиден',
        'user_id' => $decoded->user_id,
        'user' => $user_data,
        'token_data' => $decoded,
        'expires_at' => date('Y-m-d H:i:s', $decoded->exp),
        'expires_in_seconds' => $decoded->exp - time()
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'valid' => false,
        'message' => $e->getMessage(),
        'error_type' => get_class($e)
    ], JSON_UNESCAPED_UNICODE);
}