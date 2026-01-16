<?php
/**
 * Основной API для авторизации пользователей
 * РАБОЧАЯ ВЕРСИЯ
 */

session_start();

// Сохраняем, откуда пришел пользователь
if (isset($_SERVER['HTTP_REFERER']) && !empty($_SERVER['HTTP_REFERER'])) {
    $_SESSION['auth_redirect'] = $_SERVER['HTTP_REFERER'];
} else {
    $_SESSION['auth_redirect'] = '/index.html'; // По умолчанию
}

// ... остальная логика авторизации/регистрации ...

    // При успешной авторизации/регистрации:
    if ($success) {
        // Получаем сохраненный URL для редиректа
        $redirect_url = isset($_POST['redirect_url']) ? $_POST['redirect_url'] : '/index.html';
        
        // Очищаем сессию
        unset($_SESSION['auth_redirect']);
        
        // Возвращаем URL для редиректа
        $redirect_url = isset($_POST['redirect_url']) ? $_POST['redirect_url'] : '/index.html';

            // Проверяем, что это не страница входа
            if (strpos($redirect_url, 'enter-reg.html') !== false) {
                $redirect_url = '/index.html';
            }

            $response = [
                'success' => true,
                'message' => 'Вход выполнен успешно',
                'redirect_to' => $redirect_url, // ← ДОБАВИТЬ ЭТУ СТРОКУ
                'user' => $user,
                'token' => $token
            ];
            echo json_encode($response);
    }

require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

// OPTIONS запрос
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Проверяем метод
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Метод не разрешен'], JSON_UNESCAPED_UNICODE);
    exit;
}

try {
    // Получаем данные
    $input = file_get_contents('php://input');
    
    if (empty($input)) {
        throw new Exception('Отсутствуют данные запроса');
    }
    
    $data = json_decode($input, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Некорректный JSON: ' . json_last_error_msg());
    }
    
    // Валидация
    if (empty($data['email']) || empty($data['password'])) {
        throw new Exception('Заполните email и пароль');
    }
    
    $email = trim($data['email']);
    $password = $data['password'];
    
    // Ищем пользователя
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
            p.location_id,
            ac.password_hash,
            acs.actor_status_id,
            s.status as global_status
        FROM persons p
        INNER JOIN actors a ON p.actor_id = a.actor_id
        LEFT JOIN actor_credentials ac ON a.actor_id = ac.actor_id
        LEFT JOIN actor_current_statuses acs ON a.actor_id = acs.actor_id
        LEFT JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
        WHERE p.email = :email 
          AND a.deleted_at IS NULL
        LIMIT 1
    ");
    
    $stmt->execute([':email' => $email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        throw new Exception('Пользователь не найден');
    }
    
    if (empty($user['password_hash'])) {
        throw new Exception('Пароль не установлен в системе');
    }
    
    // Проверяем пароль
    if (!password_verify($password, $user['password_hash'])) {
        throw new Exception('Неверный пароль');
    }
    
    // Генерируем JWT токен
    $token = JWT::encode([
        'user_id' => (int)$user['actor_id'],
        'nickname' => $user['nickname'],
        'email' => $user['email'],
        'status_id' => (int)($user['actor_status_id'] ?? 7),
        'actor_type_id' => (int)$user['actor_type_id'],
        'location_id' => $user['location_id'] ? (int)$user['location_id'] : null
    ]);
    
    // Получаем все статусы пользователя
    $stmt = $pdo->prepare("
        SELECT status 
        FROM actor_statuses 
        WHERE actor_status_id <= :status_id
        ORDER BY actor_status_id
    ");
    $stmt->execute([':status_id' => $user['actor_status_id'] ?? 7]);
    $all_statuses = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    // Формируем ответ
    $response = [
        'success' => true,
        'message' => 'Авторизация успешна',
        'token' => $token,
        'token_type' => 'Bearer',
        'expires_in' => JWT_EXPIRATION,
        'user' => [
            'actor_id' => (int)$user['actor_id'],
            'nickname' => $user['nickname'],
            'email' => $user['email'],
            'name' => $user['name'],
            'last_name' => $user['last_name'],
            'account' => $user['account'],
            'global_status' => $user['global_status'] ?? 'Участник ТЦ',
            'status_id' => (int)($user['actor_status_id'] ?? 7),
            'location_id' => $user['location_id'] ? (int)$user['location_id'] : null,
            'actor_type_id' => (int)$user['actor_type_id'],
            'all_statuses' => $all_statuses
        ]
    ];
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(400);
    // Получаем redirect URL из запроса
$redirect_url = isset($_POST['redirect_url']) ? $_POST['redirect_url'] : '/index.html';

// Проверяем, что это не страница входа
if (strpos($redirect_url, 'enter-reg.html') !== false) {
    $redirect_url = '/index.html';
}

echo json_encode([
    'success' => true,
    'message' => 'Вход выполнен успешно',
    'redirect_to' => $redirect_url, // ← ДОБАВЬТЕ ЭТУ СТРОКУ
    'user' => $user,
    'token' => $token
    ], JSON_UNESCAPED_UNICODE);
}