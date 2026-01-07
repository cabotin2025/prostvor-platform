<?php
require_once 'config/database.php';
require_once 'lib/Database.php';

echo "Поиск существующих пользователей...\n\n";

try {
    // Находим всех пользователей с email
    $users = Prostvor\Database::fetchAll("
        SELECT 
            p.person_id,
            p.name,
            p.last_name,
            p.email,
            a.actor_id,
            a.nickname,
            a.account,
            ac.password_hash IS NOT NULL as has_password
        FROM persons p
        JOIN actors a ON p.actor_id = a.actor_id
        LEFT JOIN actor_credentials ac ON a.actor_id = ac.actor_id
        WHERE p.deleted_at IS NULL
        AND p.email IS NOT NULL
        ORDER BY a.actor_id
        LIMIT 10
    ");
    
    if (count($users) > 0) {
        echo "✅ Найдено пользователей: " . count($users) . "\n\n";
        
        foreach ($users as $user) {
            echo "👤 Пользователь #{$user['actor_id']}:\n";
            echo "   Никнейм: {$user['nickname']}\n";
            echo "   Email: {$user['email']}\n";
            echo "   Account: {$user['account']}\n";
            echo "   Пароль: " . ($user['has_password'] ? '✅ установлен' : '❌ отсутствует') . "\n";
            echo "   ---\n";
        }
        
        echo "\n💡 Для входа используйте один из этих email!\n";
        echo "   Затем проверьте пароль или установите новый.\n";
        
    } else {
        echo "❌ Пользователи не найдены\n";
    }
    
} catch (Exception $e) {
    echo "Ошибка: " . $e->getMessage() . "\n";
}