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

// api/auth/register.php - регистрация нового пользователя
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../lib/Database.php';
require_once __DIR__ . '/../../config/jwt.php';

header('Content-Type: application/json; charset=utf-8');

// Получаем данные
$input = json_decode(file_get_contents('php://input'), true);

// Проверяем обязательные поля
$required_fields = ['email', 'password', 'nickname', 'name', 'last_name'];
foreach ($required_fields as $field) {
    if (empty($input[$field])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error' => "Missing required field: $field"
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
}

try {
    // Проверяем, не занят ли email
    $existing_user = \Prostvor\Database::fetchOne("
        SELECT email FROM persons WHERE email = :email AND deleted_at IS NULL
    ", ['email' => $input['email']]);
    
    if ($existing_user) {
        http_response_code(409);
        echo json_encode([
            'success' => false,
            'error' => 'Email already registered'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // Генерируем уникальный account
    $account_num = \Prostvor\Database::fetchOne("
        SELECT COALESCE(MAX(CAST(SUBSTRING(account FROM 2) AS INTEGER)), 0) + 1 as next_num
        FROM actors 
        WHERE account ~ '^U[0-9]+$'
    ");
    
    $next_num = $account_num['next_num'] ?? 1;
    $account = 'U' . str_pad($next_num, 11, '0', STR_PAD_LEFT);
    
    // Начинаем транзакцию
    $db = \Prostvor\Database::getConnection();
    $db->beginTransaction();
    
    try {
        // 1. Создаем актора
        $actor_data = [
            'nickname' => $input['nickname'],
            'actor_type_id' => 1, // Человек
            'account' => $account,
            'created_by' => 1,
            'updated_by' => 1
        ];
        
        $stmt = $db->prepare("
            INSERT INTO actors (nickname, actor_type_id, account, created_by, updated_by) 
            VALUES (:nickname, :actor_type_id, :account, :created_by, :updated_by)
            RETURNING actor_id
        ");
        
        $stmt->execute($actor_data);
        $actor_id = $stmt->fetch()['actor_id'];
        
        // 2. Создаем персону
        $person_data = [
            'name' => $input['name'],
            'last_name' => $input['last_name'],
            'email' => $input['email'],
            'actor_id' => $actor_id,
            'location_id' => $input['location_id'] ?? null,
            'created_by' => 1,
            'updated_by' => 1
        ];
        
        $stmt = $db->prepare("
            INSERT INTO persons (name, last_name, email, actor_id, location_id, created_by, updated_by)
            VALUES (:name, :last_name, :email, :actor_id, :location_id, :created_by, :updated_by)
        ");
        $stmt->execute($person_data);
        
        // 3. Создаем учетные данные
        $password_hash = password_hash($input['password'], PASSWORD_BCRYPT);
        $stmt = $db->prepare("
            INSERT INTO actor_credentials (actor_id, password_hash)
            VALUES (:actor_id, :password_hash)
        ");
        $stmt->execute(['actor_id' => $actor_id, 'password_hash' => $password_hash]);
        
        // 4. Устанавливаем статус "Участник ТЦ"
        $stmt = $db->prepare("
            INSERT INTO actor_current_statuses (actor_id, actor_status_id, created_by, updated_by)
            VALUES (:actor_id, 7, 1, 1)
        ");
        $stmt->execute(['actor_id' => $actor_id]);
        
        // Коммитим транзакцию
        $db->commit();
        
        // Генерируем JWT токен
        $token = JWTManager::generateToken($actor_id, $input['email']);
        
        // Успешный ответ
        echo json_encode([
            'success' => true,
            'message' => 'Registration successful',
            'token' => $token,
            'user' => [
                'actor_id' => $actor_id,
                'nickname' => $input['nickname'],
                'email' => $input['email'],
                'name' => $input['name'],
                'last_name' => $input['last_name'],
                'account' => $account,
                'actor_type' => 'Человек',
                'status' => 'Участник ТЦ'
            ]
        ], JSON_UNESCAPED_UNICODE);
        
    } catch (Exception $e) {
        $db->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Registration failed',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}