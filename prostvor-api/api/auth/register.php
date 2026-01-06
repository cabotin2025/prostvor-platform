<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

require_once '../../includes/Database.php';

// Получаем данные из запроса
$data = json_decode(file_get_contents('php://input'), true);

// Валидация
if (empty($data['email'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Email обязателен'], JSON_UNESCAPED_UNICODE);
    exit;
}

$db = Database::getConnection();

try {
    // Проверяем, какая БД используется
    $driver = $db->getAttribute(PDO::ATTR_DRIVER_NAME);
    
    if ($driver === 'sqlite') {
        // SQLite версия (для тестирования)
        $stmt = $db->prepare("INSERT INTO test_users (email, nickname) VALUES (:email, :nickname)");
        $stmt->execute([
            ':email' => $data['email'],
            ':nickname' => $data['nickname'] ?? $data['email']
        ]);
        
        $userId = $db->lastInsertId();
        
        http_response_code(201);
        echo json_encode([
            'success' => true,
            'message' => 'Тестовая регистрация (SQLite)',
            'driver' => 'sqlite',
            'user' => [
                'id' => $userId,
                'email' => $data['email'],
                'nickname' => $data['nickname'] ?? $data['email']
            ]
        ], JSON_UNESCAPED_UNICODE);
        
    } elseif ($driver === 'pgsql') {
        // PostgreSQL версия (реальная)
        $stmt = $db->prepare("SELECT * FROM register_person(:email, :password, :nickname, :name, :last_name, :location_id)");
        $stmt->execute([
            ':email' => $data['email'],
            ':password' => $data['password'] ?? 'temp123',
            ':nickname' => $data['nickname'] ?? $data['email'],
            ':name' => $data['name'] ?? '',
            ':last_name' => $data['last_name'] ?? '',
            ':location_id' => $data['location_id'] ?? null
        ]);
        
        $result = $stmt->fetch();
        
        if ($result) {
            http_response_code(201);
            echo json_encode([
                'success' => true,
                'message' => $result['message'],
                'driver' => 'pgsql',
                'user' => [
                    'actor_id' => $result['actor_id'],
                    'nickname' => $result['nickname'],
                    'email' => $result['email']
                ]
            ], JSON_UNESCAPED_UNICODE);
        } else {
            http_response_code(400);
            echo json_encode(['error' => 'Ошибка регистрации'], JSON_UNESCAPED_UNICODE);
        }
    }
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Ошибка сервера: ' . $e->getMessage(),
        'driver' => $driver ?? 'unknown'
    ], JSON_UNESCAPED_UNICODE);
}
?>