<?php
require_once '../../config/database.php';
require_once '../../config/cors.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

try {
    $data = json_decode(file_get_contents('php://input'), true);
    
    // Только самые необходимые поля
    if (empty($data['username']) || empty($data['email']) || empty($data['password'])) {
        throw new Exception('Все поля обязательны для заполнения');
    }
    
    // Проверка существования пользователя
    $stmt = $pdo->prepare("SELECT actor_id FROM actors WHERE username = ? OR email = ?");
    $stmt->execute([$data['username'], $data['email']]);
    
    if ($stmt->fetch()) {
        throw new Exception('Пользователь с таким именем или email уже существует');
    }
    
    // Хеширование пароля
    $password_hash = password_hash($data['password'], PASSWORD_DEFAULT);
    
    // Создание аккаунта
    $account_number = 'U' . str_pad(mt_rand(1, 99999999999), 11, '0', STR_PAD_LEFT);
    
    $stmt = $pdo->prepare("
        INSERT INTO actors (username, email, password_hash, actor_type_id, account, created_by, updated_by) 
        VALUES (?, ?, ?, 1, ?, 1, 1)
    ");
    
    $stmt->execute([
        $data['username'],
        $data['email'],
        $password_hash,
        $account_number
    ]);
    
    $actor_id = $pdo->lastInsertId();
    
    // Присваиваем статус "Участник ТЦ"
    $stmt = $pdo->prepare("
        INSERT INTO actor_current_statuses (actor_id, actor_status_id, created_by) 
        VALUES (?, 7, ?)
    ");
    $stmt->execute([$actor_id, $actor_id]);
    
    // Простой токен (без JWT для теста)
    $token = base64_encode(json_encode([
        'user_id' => $actor_id,
        'username' => $data['username']
    ]));
    
    echo json_encode([
        'success' => true,
        'message' => 'Регистрация успешна',
        'token' => $token,
        'actor_id' => $actor_id
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}