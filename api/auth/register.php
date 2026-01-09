<?php
require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

try {
    $data = json_decode(file_get_contents('php://input'), true);
    
    // Валидация с учетом реальной структуры
    if (empty($data['email']) || empty($data['password']) || empty($data['nickname'])) {
        throw new Exception('Заполните обязательные поля: Email, Пароль и Имя пользователя (nickname)');
    }
    
    // Проверка существования пользователя по email
    $stmt = $pdo->prepare("
        SELECT a.actor_id 
        FROM actors a
        LEFT JOIN persons p ON a.actor_id = p.actor_id
        WHERE p.email = ? OR a.nickname = ?
    ");
    $stmt->execute([$data['email'], $data['nickname']]);
    
    if ($stmt->fetch()) {
        throw new Exception('Пользователь с таким email или именем уже существует');
    }
    
    // Начинаем транзакцию
    $pdo->beginTransaction();
    
    try {
        // Хеширование пароля
        $password_hash = password_hash($data['password'], PASSWORD_DEFAULT);
        
        // Генерация номера аккаунта
        $account_number = 'U' . str_pad(mt_rand(1, 99999999999), 11, '0', STR_PAD_LEFT);
        
        // 1. Создаем запись в actors
        $stmt = $pdo->prepare("
            INSERT INTO actors (nickname, actor_type_id, account, created_by, updated_by) 
            VALUES (?, 1, ?, 1, 1)
            RETURNING actor_id
        ");
        
        $stmt->execute([$data['nickname'], $account_number]);
        $actor_row = $stmt->fetch(PDO::FETCH_ASSOC);
        $actor_id = $actor_row['actor_id'];
        
        // 2. Создаем запись в persons с email
        $stmt = $pdo->prepare("
            INSERT INTO persons (name, last_name, email, actor_id, created_by, updated_by) 
            VALUES (?, ?, ?, ?, 1, 1)
        ");
        
        $stmt->execute([
            $data['name'] ?? $data['nickname'], // Если имя не указано, используем nickname
            $data['last_name'] ?? '', // Фамилия может быть пустой
            $data['email'],
            $actor_id
        ]);
        
        // 3. Присваиваем статус "Участник ТЦ" (ID = 7)
        $stmt = $pdo->prepare("
            INSERT INTO actor_current_statuses (actor_id, actor_status_id, created_by) 
            VALUES (?, 7, ?)
        ");
        $stmt->execute([$actor_id, $actor_id]);
        
        // 4. Генерация JWT токена
        $payload = [
            'user_id' => $actor_id,
            'nickname' => $data['nickname'],
            'email' => $data['email'],
            'status_id' => 7 // Участник ТЦ
        ];
        
        $token = JWT::encode($payload, JWT_SECRET);
        
        // Коммитим транзакцию
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Регистрация успешна',
            'token' => $token,
            'actor_id' => $actor_id,
            'nickname' => $data['nickname'], // ← ВАЖНО: возвращаем nickname, а не username
            'global_status' => 'Участник ТЦ'
        ]);
        
    } catch (Exception $e) {
        $pdo->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}