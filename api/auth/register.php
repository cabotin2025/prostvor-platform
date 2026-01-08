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
    
    // Валидация (УБИРАЕМ locality_id из обязательных!)
    $required_fields = ['username', 'email', 'password'];
    foreach ($required_fields as $field) {
        if (empty($data[$field])) {
            throw new Exception("Поле '$field' обязательно для заполнения");
        }
    }
    
    // Проверка существования пользователя
    $stmt = $pdo->prepare("SELECT actor_id FROM actors WHERE username = ? OR email = ?");
    $stmt->execute([$data['username'], $data['email']]);
    
    if ($stmt->fetch()) {
        throw new Exception('Пользователь с таким именем или email уже существует');
    }
    
    // Начинаем транзакцию
    $pdo->beginTransaction();
    
    try {
        // Хеширование пароля
        $password_hash = password_hash($data['password'], PASSWORD_DEFAULT);
        
        // Создание аккаунта
        $account_number = 'U' . str_pad(mt_rand(1, 99999999999), 11, '0', STR_PAD_LEFT);
        
        // Создаем актора (БЕЗ locality_id при создании)
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
        
        // Привязываем актора к населенному пункту (если указан)
        if (!empty($data['locality_id'])) {
            // Проверяем существование населенного пункта в таблице localities
            $stmt = $pdo->prepare("SELECT id FROM localities WHERE id = ?");
            $stmt->execute([$data['locality_id']]);
            
            if ($stmt->fetch()) {
                $stmt = $pdo->prepare("
                    INSERT INTO actors_locations (actor_id, location_id) 
                    VALUES (?, ?)
                ");
                $stmt->execute([$actor_id, $data['locality_id']]);
            }
            // Если locality_id неверный - просто пропускаем, не прерываем регистрацию
        }
        
        // Автоматически присваиваем статус "Участник ТЦ" (actor_status_id = 7)
        $stmt = $pdo->prepare("
            INSERT INTO actor_current_statuses (actor_id, actor_status_id, created_by) 
            VALUES (?, 7, ?)
        ");
        $stmt->execute([$actor_id, $actor_id]);
        
        // Генерация JWT токена
        $payload = [
            'user_id' => $actor_id,
            'username' => $data['username'],
            'email' => $data['email'],
            'status_id' => 7 // Участник ТЦ
        ];
        
        // Если есть locality_id, добавляем в токен
        if (!empty($data['locality_id'])) {
            $payload['locality_id'] = $data['locality_id'];
        }
        
        $token = JWT::encode($payload, JWT_SECRET);
        
        // Коммитим транзакцию
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Регистрация успешна',
            'token' => $token,
            'actor_id' => $actor_id,
            'username' => $data['username'],
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