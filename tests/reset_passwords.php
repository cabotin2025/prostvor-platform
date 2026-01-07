<?php
require_once 'config/database.php';
require_once 'lib/Database.php';

echo "Сброс паролей для тестирования...\n\n";

// Новые простые пароли для всех пользователей
$users_to_reset = [
    ['email' => 'admin@example.com', 'new_password' => 'admin123', 'actor_id' => 1],
    ['email' => 'dev@prostvor.local', 'new_password' => 'developer', 'actor_id' => 9],
    ['email' => 'newuser@example.com', 'new_password' => 'password', 'actor_id' => 3],
    ['email' => 'seconduser@example.com', 'new_password' => 'password', 'actor_id' => 4],
    ['email' => 'success_user@example.com', 'new_password' => 'password', 'actor_id' => 6],
    ['email' => 'test_final@test.com', 'new_password' => 'password', 'actor_id' => 8]
];

foreach ($users_to_reset as $user) {
    echo "Сбрасываю пароль для: {$user['email']}... ";
    
    try {
        $password_hash = password_hash($user['new_password'], PASSWORD_BCRYPT);
        
        // Проверяем существование записи
        $existing = Prostvor\Database::fetchOne("
            SELECT actor_id FROM actor_credentials WHERE actor_id = :actor_id
        ", ['actor_id' => $user['actor_id']]);
        
        if ($existing) {
            // Обновляем
            Prostvor\Database::query("
                UPDATE actor_credentials 
                SET password_hash = :password_hash
                WHERE actor_id = :actor_id
            ", ['password_hash' => $password_hash, 'actor_id' => $user['actor_id']]);
        } else {
            // Создаем
            Prostvor\Database::query("
                INSERT INTO actor_credentials (actor_id, password_hash)
                VALUES (:actor_id, :password_hash)
            ", ['actor_id' => $user['actor_id'], 'password_hash' => $password_hash]);
        }
        
        echo "✅ Установлен пароль: '{$user['new_password']}'\n";
        
    } catch (Exception $e) {
        echo "❌ Ошибка: " . $e->getMessage() . "\n";
    }
}

echo "\n🎉 Все пароли сброшены!\n";
echo "Теперь используйте:\n";
echo "- admin@example.com / admin123\n";
echo "- dev@prostvor.local / developer\n";
echo "- Остальные: email / password\n";