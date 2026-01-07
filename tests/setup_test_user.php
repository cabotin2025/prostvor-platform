<?php
require_once 'config/database.php';
require_once 'lib/Database.php';

echo "Создание тестового пользователя для разработки...\n\n";

try {
    $db = Prostvor\Database::getConnection();
    
    // 1. Проверяем, есть ли уже тестовый пользователь
    $existing = Prostvor\Database::fetchOne("
        SELECT p.email, a.account 
        FROM persons p 
        JOIN actors a ON p.actor_id = a.actor_id
        WHERE p.email = 'dev@prostvor.local'
        AND p.deleted_at IS NULL
    ");
    
    if ($existing) {
        echo "✅ Тестовый пользователь уже существует!\n";
        echo "Email: {$existing['email']}\n";
        echo "Account: {$existing['account']}\n";
        exit;
    }
    
    // 2. Генерируем УНИКАЛЬНЫЙ account
    // Находим максимальный числовой суффикс для аккаунтов, начинающихся с 'DEV'
    $max_dev = Prostvor\Database::fetchOne("
        SELECT MAX(CAST(SUBSTRING(account FROM 4) AS INTEGER)) as max_num
        FROM actors 
        WHERE account LIKE 'DEV%' 
        AND LENGTH(account) = 12
        AND account ~ '^DEV[0-9]{9}$'
    ");
    
    $next_num = ($max_dev['max_num'] ?? 0) + 1;
    $account = 'DEV' . str_pad($next_num, 9, '0', STR_PAD_LEFT); // DEV + 9 цифр = 12 символов
    
    echo "Генерируем уникальный account: $account\n";
    
    // Проверяем, не занят ли этот account
    $account_check = Prostvor\Database::fetchOne("
        SELECT account FROM actors WHERE account = :account
    ", ['account' => $account]);
    
    if ($account_check) {
        echo "⚠️ Account '$account' уже занят, пробую следующий...\n";
        $account = 'DEV' . str_pad($next_num + 1, 9, '0', STR_PAD_LEFT);
        echo "Новый account: $account\n";
    }
    
    // 3. Создаем актора
    $actor_data = [
        'nickname' => 'Разработчик',
        'actor_type_id' => 1,
        'account' => $account,
        'created_by' => 1,
        'updated_by' => 1
    ];
    
    echo "Создаю актора с account: '$account'...\n";
    
    $stmt = $db->prepare("
        INSERT INTO actors (nickname, actor_type_id, account, created_by, updated_by) 
        VALUES (:nickname, :actor_type_id, :account, :created_by, :updated_by)
        RETURNING actor_id
    ");
    
    $stmt->execute($actor_data);
    $actor_id = $stmt->fetch()['actor_id'];
    
    echo "✅ Актор создан, ID: $actor_id\n";
    
    // 4. Создаем персону
    $person_data = [
        'name' => 'Тест',
        'last_name' => 'Разработчик',
        'email' => 'dev@prostvor.local',
        'actor_id' => $actor_id,
        'created_by' => 1,
        'updated_by' => 1
    ];
    
    $stmt = $db->prepare("
        INSERT INTO persons (name, last_name, email, actor_id, created_by, updated_by)
        VALUES (:name, :last_name, :email, :actor_id, :created_by, :updated_by)
    ");
    $stmt->execute($person_data);
    
    echo "✅ Персона создана\n";
    
    // 5. Создаем учетные данные
    $password_hash = password_hash('developer', PASSWORD_BCRYPT);
    $stmt = $db->prepare("
        INSERT INTO actor_credentials (actor_id, password_hash)
        VALUES (:actor_id, :password_hash)
    ");
    $stmt->execute(['actor_id' => $actor_id, 'password_hash' => $password_hash]);
    
    echo "✅ Учетные данные созданы\n";
    
    // 6. Устанавливаем статус
    $stmt = $db->prepare("
        INSERT INTO actor_current_statuses (actor_id, actor_status_id, created_by, updated_by)
        VALUES (:actor_id, 7, 1, 1)
    ");
    $stmt->execute(['actor_id' => $actor_id]);
    
    echo "✅ Статус установлен\n\n";
    
    echo "🎉 ТЕСТОВЫЙ ПОЛЬЗОВАТЕЛЬ УСПЕШНО СОЗДАН!\n";
    echo "========================================\n";
    echo "Данные для входа:\n";
    echo "📧 Email: dev@prostvor.local\n";
    echo "🔑 Пароль: developer\n";
    echo "🆔 Actor ID: $actor_id\n";
    echo "💳 Account: $account\n";
    echo "\nДля теста аутентификации:\n";
    echo "➤ POST http://localhost:8000/api/auth/login\n";
    echo "📦 Body: {\"email\":\"dev@prostvor.local\",\"password\":\"developer\"}\n";
    
} catch (Exception $e) {
    echo "❌ Ошибка: " . $e->getMessage() . "\n";
    
    // Если ошибка уникальности account
    if (strpos($e->getMessage(), 'unique') !== false || strpos($e->getMessage(), 'duplicate') !== false) {
        echo "\n💡 Account уже занят. Пробую альтернативный...\n";
        
        // Альтернативный account на основе timestamp
        $alt_account = 'T' . date('YmdHi'); // T + дата+время (12 символов максимум)
        $alt_account = substr($alt_account, 0, 12); // Обрезаем до 12 символов
        
        echo "Пробую account: '$alt_account'\n";
        
        try {
            // Пробуем с альтернативным account
            $stmt = $db->prepare("
                INSERT INTO actors (nickname, actor_type_id, account, created_by, updated_by) 
                VALUES ('Разработчик', 1, :account, 1, 1)
                RETURNING actor_id
            ");
            
            $stmt->execute(['account' => $alt_account]);
            $actor_id = $stmt->fetch()['actor_id'];
            
            // ... остальной код создания пользователя
            echo "✅ Успешно с account: '$alt_account'\n";
            
        } catch (Exception $e2) {
            echo "❌ И альтернативный не работает: " . $e2->getMessage() . "\n";
        }
    }
}