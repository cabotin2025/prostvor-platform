<?php
require_once 'config/database.php';
require_once 'lib/Database.php';

header('Content-Type: text/html; charset=utf-8');

echo "<h2>Проверка содержимого базы данных</h2>";

try {
    $db = Prostvor\Database::getConnection();
    
    // 1. Проверяем таблицу persons
    echo "<h3>1. Пользователи в таблице persons:</h3>";
    $persons = Prostvor\Database::fetchAll("
        SELECT p.person_id, p.name, p.last_name, p.email, p.actor_id, a.nickname
        FROM persons p
        JOIN actors a ON p.actor_id = a.actor_id
        WHERE p.deleted_at IS NULL
        LIMIT 10
    ");
    
    if (count($persons) > 0) {
        echo "<table border='1' cellpadding='5'>";
        echo "<tr><th>ID</th><th>Имя</th><th>Фамилия</th><th>Email</th><th>Actor ID</th><th>Никнейм</th></tr>";
        foreach ($persons as $person) {
            echo "<tr>";
            echo "<td>{$person['person_id']}</td>";
            echo "<td>{$person['name']}</td>";
            echo "<td>{$person['last_name']}</td>";
            echo "<td>{$person['email']}</td>";
            echo "<td>{$person['actor_id']}</td>";
            echo "<td>{$person['nickname']}</td>";
            echo "</tr>";
        }
        echo "</table>";
    } else {
        echo "<p style='color: red;'>❌ В таблице persons нет записей</p>";
    }
    
    // 2. Проверяем таблицу actor_credentials
    echo "<h3>2. Учетные данные в actor_credentials:</h3>";
    $credentials = Prostvor\Database::fetchAll("
        SELECT actor_id, password_hash, created_at 
        FROM actor_credentials 
        LIMIT 10
    ");
    
    if (count($credentials) > 0) {
        echo "<table border='1' cellpadding='5'>";
        echo "<tr><th>Actor ID</th><th>Хеш пароля</th><th>Создан</th></tr>";
        foreach ($credentials as $cred) {
            $hash_preview = substr($cred['password_hash'], 0, 20) . '...';
            echo "<tr>";
            echo "<td>{$cred['actor_id']}</td>";
            echo "<td>{$hash_preview}</td>";
            echo "<td>{$cred['created_at']}</td>";
            echo "</tr>";
        }
        echo "</table>";
    } else {
        echo "<p style='color: orange;'>⚠️ В таблице actor_credentials нет записей</p>";
    }
    
    // 3. Проверяем существование функции authenticate_user
    echo "<h3>3. Проверка функции authenticate_user:</h3>";
    $function_check = Prostvor\Database::fetchOne("
        SELECT 
            proname as function_name,
            pg_get_functiondef(p.oid) as definition
        FROM pg_proc p
        WHERE proname = 'authenticate_user'
        LIMIT 1
    ");
    
    if ($function_check) {
        echo "<p style='color: green;'>✅ Функция authenticate_user существует</p>";
        echo "<pre>Определение: " . htmlspecialchars(substr($function_check['definition'], 0, 500)) . "...</pre>";
    } else {
        echo "<p style='color: red;'>❌ Функция authenticate_user НЕ существует</p>";
    }
    
    // 4. Проверяем администратора
    echo "<h3>4. Проверка администратора (admin@example.com):</h3>";
    $admin = Prostvor\Database::fetchOne("
        SELECT p.*, a.nickname 
        FROM persons p
        JOIN actors a ON p.actor_id = a.actor_id
        WHERE p.email = 'admin@example.com'
        AND p.deleted_at IS NULL
    ");
    
    if ($admin) {
        echo "<p style='color: green;'>✅ Администратор найден</p>";
        echo "<pre>" . print_r($admin, true) . "</pre>";
    } else {
        echo "<p style='color: red;'>❌ Администратор с email admin@example.com не найден</p>";
        
        // Показываем какие email есть
        $emails = Prostvor\Database::fetchAll("
            SELECT email FROM persons WHERE deleted_at IS NULL LIMIT 5
        ");
        echo "<p>Доступные email: ";
        foreach ($emails as $email) {
            echo $email['email'] . ", ";
        }
        echo "</p>";
    }
    
} catch (Exception $e) {
    echo "<p style='color: red;'>❌ Ошибка: " . $e->getMessage() . "</p>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}