<?php
/**
 * Основной API для авторизации пользователей
 * РАБОЧАЯ ВЕРСИЯ
 */

// ========== ВСЕ ПОДКЛЮЧЕНИЯ В НАЧАЛЕ ==========
require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php';

// ========== ОТКЛЮЧАЕМ ВЫВОД ОШИБОК ==========
error_reporting(0);
ini_set('display_errors', 0);

// ========== ЗАГОЛОВКИ ==========
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

// ========== ОБРАБОТКА OPTIONS ==========
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ========== СЕССИЯ ДЛЯ REDIRECT ==========
session_start();
if (isset($_SERVER['HTTP_REFERER']) && !empty($_SERVER['HTTP_REFERER'])) {
    $_SESSION['auth_redirect'] = $_SERVER['HTTP_REFERER'];
}

// ========== ОСНОВНАЯ ЛОГИКА ==========
try {
    // Проверяем метод
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Метод не разрешен', 405);
    }
    
    // Получаем данные
    $input = file_get_contents('php://input');
    
    if (empty($input)) {
        throw new Exception('Отсутствуют данные запроса', 400);
    }
    
    $data = json_decode($input, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Некорректный JSON: ' . json_last_error_msg(), 400);
    }
    
    // Валидация
    if (empty($data['email']) || empty($data['password'])) {
        throw new Exception('Заполните email и пароль', 400);
    }
    
    $email = trim($data['email']);
    $password = $data['password'];
    $redirect_url = $data['redirect_url'] ?? ($_SESSION['auth_redirect'] ?? '/index.html');
    
    // Проверяем, что не страница входа
    if (strpos($redirect_url, 'enter-reg.html') !== false) {
        $redirect_url = '/index.html';
    }
    
    // Ищем пользователя
    $stmt = $pdo->prepare("
        SELECT 
            a.actor_id,
            a.nickname,
            a.account,
            a.actor_type_id,
            a.color_frame,
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
        throw new Exception('Пользователь не найден', 401);
    }
    
    if (empty($user['password_hash'])) {
        throw new Exception('Пароль не установлен в системе', 401);
    }
    
    // Проверяем пароль
    if (!password_verify($password, $user['password_hash'])) {
        throw new Exception('Неверный пароль', 401);
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
    
    // ========== УСПЕШНЫЙ ОТВЕТ ==========
    $response = [
        'success' => true,
        'message' => 'Авторизация успешна',
        'redirect_to' => $redirect_url, // ← ДОБАВЛЕНО
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
            'color_frame' => $user['color_frame'] ?? '#4ECDC4', // ← ДОБАВЛЕНО
            'all_statuses' => $all_statuses
        ]
    ];
    
    // Очищаем сессию
    if (isset($_SESSION['auth_redirect'])) {
        unset($_SESSION['auth_redirect']);
    }
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    // ========== ОШИБКА ==========
    http_response_code($e->getCode() ?: 400);
    
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'redirect_to' => '/pages/enter-reg.html' // При ошибке остаемся на странице входа
    ], JSON_UNESCAPED_UNICODE);
}
?>