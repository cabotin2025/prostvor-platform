<?php
// ==================== CORS НАСТРОЙКИ ====================
// Разрешаем запросы с localhost:80 (ваш фронтенд)
header("Access-Control-Allow-Origin: http://localhost");
// Разрешаем запросы с localhost без порта (на всякий случай)
header("Access-Control-Allow-Origin: http://localhost:80");
// Или разрешить все для разработки (не для продакшена!)
// header("Access-Control-Allow-Origin: *");

header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Access-Control-Allow-Credentials: true");
header("Access-Control-Max-Age: 86400"); // 24 часа

// Для preflight OPTIONS запросов
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}
// ==================== КОНЕЦ CORS ====================

// api/auth/login.php - рабочая версия аутентификации
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../lib/Database.php';
require_once __DIR__ . '/../../config/jwt.php';

// Устанавливаем заголовки JSON с поддержкой кириллицы
header('Content-Type: application/json; charset=utf-8');

// Получаем данные
$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !isset($input['email']) || !isset($input['password'])) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'Требуется email и пароль'
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

try {
    $email = trim($input['email']);
    $password = $input['password'];
    
    // 1. Ищем пользователя по email
    $user = Prostvor\Database::fetchOne("
        SELECT 
            a.actor_id,
            a.nickname,
            a.actor_type_id,
            at.type as actor_type,
            p.email,
            p.name,
            p.last_name,
            ac.password_hash
        FROM persons p
        JOIN actors a ON p.actor_id = a.actor_id
        JOIN actor_types at ON a.actor_type_id = at.actor_type_id
        LEFT JOIN actor_credentials ac ON a.actor_id = ac.actor_id
        WHERE p.email = :email 
        AND p.deleted_at IS NULL 
        AND a.deleted_at IS NULL
        LIMIT 1
    ", ['email' => $email]);
    
    if (!$user) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'error' => 'Пользователь не найден'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // 2. Проверяем пароль
    $password_valid = false;
    
    // Вариант A: Проверка через функцию authenticate_user (если существует)
    try {
        $auth_result = Prostvor\Database::fetchOne(
            "SELECT * FROM authenticate_user(:email, :password)",
            ['email' => $email, 'password' => $password]
        );
        
        if ($auth_result) {
            $password_valid = true;
            // Обновляем данные пользователя из результата функции
            $user = array_merge($user, $auth_result);
        }
    } catch (Exception $e) {
        // Функция не существует или ошибка - пробуем другие способы
    }
    
    // Вариант B: Проверка через таблицу actor_credentials
    if (!$password_valid && isset($user['password_hash'])) {
        if (password_verify($password, $user['password_hash'])) {
            $password_valid = true;
        }
    }
    
    // Вариант C: Тестовый пароль для разработки
    if (!$password_valid && APP_ENV === 'development') {
        $test_passwords = [
            'admin123' => 'admin@example.com',
            'test123' => 'test@example.com',
            'password' => 'user@example.com'
        ];
        
        foreach ($test_passwords as $test_pass => $test_email) {
            if ($email === $test_email && $password === $test_pass) {
                $password_valid = true;
                break;
            }
        }
    }
    
    if (!$password_valid) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'error' => 'Неверный пароль'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // 3. Получаем текущий статус пользователя
    $status = Prostvor\Database::fetchOne("
        SELECT ast.status
        FROM actor_current_statuses acs
        JOIN actor_statuses ast ON acs.actor_status_id = ast.actor_status_id
        WHERE acs.actor_id = :actor_id
        ORDER BY acs.created_at DESC
        LIMIT 1
    ", ['actor_id' => $user['actor_id']]);
    
    // 3.1 Получаем все статусы пользователя
    $all_statuses = Prostvor\Database::fetchAll("
        SELECT ast.status
        FROM actor_current_statuses acs
        JOIN actor_statuses ast ON acs.actor_status_id = ast.actor_status_id
        WHERE acs.actor_id = :actor_id
        ORDER BY acs.created_at DESC
    ", ['actor_id' => $user['actor_id']]);
    
    // 4. Генерируем JWT токен
    $token = JWTManager::generateToken($user['actor_id'], $user['email']);
    
    // 5. Формируем ответ
    $response = [
        'success' => true,
        'message' => 'Аутентификация успешна',
        'token' => $token,
        'user' => [
            'actor_id' => $user['actor_id'],
            'nickname' => $user['nickname'],
            'email' => $user['email'],
            'name' => $user['name'] ?? '',
            'last_name' => $user['last_name'] ?? '',
            'actor_type' => $user['actor_type'],
            'status' => $status['status'] ?? 'Участник ТЦ',
            'additional_statuses' => array_column($all_statuses, 'status')
        ],
        'permissions' => [
            'can_create_projects' => true,
            'can_manage_users' => in_array($status['status'] ?? '', ['Руководитель ТЦ', 'Куратор направления']),
            'can_view_all_projects' => true
        ]
    ];
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Ошибка сервера',
        'message' => $e->getMessage(),
        'trace' => APP_ENV === 'development' ? $e->getTraceAsString() : null
    ], JSON_UNESCAPED_UNICODE);
}