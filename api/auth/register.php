<?php
/**
 * Реальная регистрация пользователя
 */

require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

// Включите для отладки
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Метод не разрешен']);
    exit;
}

try {
    $input = file_get_contents('php://input');
    error_log("Регистрация: " . $input);
    
    $data = json_decode($input, true);
    
    if (empty($data['email']) || empty($data['password']) || empty($data['nickname'])) {
        throw new Exception('Заполните email, пароль и никнейм');
    }
    
    $email = trim($data['email']);
    $password = $data['password'];
    $nickname = trim($data['nickname']);
    $name = $data['name'] ?? $nickname;
    $last_name = $data['last_name'] ?? '';
    
    // Проверка существования пользователя
    $stmt = $pdo->prepare("
        SELECT a.actor_id 
        FROM actors a
        LEFT JOIN persons p ON a.actor_id = p.actor_id
        WHERE p.email = ? OR a.nickname = ?
    ");
    $stmt->execute([$email, $nickname]);
    
    if ($stmt->fetch()) {
        throw new Exception('Пользователь с таким email или никнеймом уже существует');
    }
    
    // Начинаем транзакцию
    $pdo->beginTransaction();
    
    try {
        // Хеширование пароля
        $password_hash = password_hash($password, PASSWORD_DEFAULT);
        
        // Генерация номера аккаунта
        $account_number = 'U' . str_pad(mt_rand(1, 99999999999), 11, '0', STR_PAD_LEFT);
        
        // 1. Создаем запись в actors
        $stmt = $pdo->prepare("
            INSERT INTO actors (nickname, actor_type_id, account, color_frame, created_by, updated_by) 
            VALUES (?, 1, ?, ?, 1, 1)
            RETURNING actor_id
        ");

        $stmt->execute([$nickname, $account_number, $data['color_frame'] ?? '#4ECDC4']); // ← ТРИ параметра!
        $actor_row = $stmt->fetch(PDO::FETCH_ASSOC);
        $actor_id = $actor_row['actor_id'];
        
        // 2. Создаем запись в persons
        $stmt = $pdo->prepare("
            INSERT INTO persons (name, last_name, email, actor_id, created_by, updated_by) 
            VALUES (?, ?, ?, ?, 1, 1)
        ");
        
        $stmt->execute([$name, $last_name, $email, $actor_id]);
        
        // 3. Сохраняем пароль
        $stmt = $pdo->prepare("
            INSERT INTO actor_credentials (actor_id, password_hash) 
            VALUES (?, ?)
        ");
        $stmt->execute([$actor_id, $password_hash]);
        
        // 4. Присваиваем статус "Участник ТЦ" (ID = 7)
        $stmt = $pdo->prepare("
            INSERT INTO actor_current_statuses (actor_id, actor_status_id, created_by) 
            VALUES (?, 7, ?)
        ");
        $stmt->execute([$actor_id, $actor_id]);
        
        // 5. Генерируем JWT токен
        $token = JWT::encode([
            'user_id' => $actor_id,
            'nickname' => $nickname,
            'email' => $email,
            'status_id' => 7
        ]);
        
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Регистрация успешна',
            'token' => $token,
            'actor_id' => $actor_id,
            'nickname' => $nickname,
            'global_status' => 'Участник ТЦ'
        ], JSON_UNESCAPED_UNICODE);
        
    } catch (Exception $e) {
        $pdo->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Ошибка регистрации: " . $e->getMessage());
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}