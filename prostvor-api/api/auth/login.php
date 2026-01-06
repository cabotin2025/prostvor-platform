<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

require_once '../../includes/Database.php';

$data = json_decode(file_get_contents('php://input'), true);

if (empty($data['email']) || empty($data['password'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Email и пароль обязательны']);
    exit;
}

$db = Database::getConnection();

try {
    // Вызываем функцию аутентификации
    $stmt = $db->prepare("SELECT * FROM authenticate_user(:email, :password)");
    $stmt->execute([
        ':email' => $data['email'],
        ':password' => $data['password']
    ]);
    
    $user = $stmt->fetch();
    
    if ($user) {
        // Генерируем токен (можно использовать JWT)
        $token = base64_encode($user['actor_id'] . '_' . time() . '_' . bin2hex(random_bytes(8)));
        
        // Обновляем время последнего входа (добавьте эту функцию в БД)
        $updateStmt = $db->prepare("UPDATE actors SET updated_at = NOW() WHERE actor_id = :id");
        $updateStmt->execute([':id' => $user['actor_id']]);
        
        http_response_code(200);
        echo json_encode([
            'success' => true,
            'token' => $token,
            'user' => [
                'actor_id' => $user['actor_id'],
                'nickname' => $user['nickname'],
                'email' => $user['email'],
                'actor_type' => $user['actor_type'],
                'status' => $user['status'],
                'location_name' => $user['location_name']
            ]
        ]);
    } else {
        http_response_code(401);
        echo json_encode(['error' => 'Неверный email или пароль']);
    }
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Ошибка сервера: ' . $e->getMessage()]);
}
?>