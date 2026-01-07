<?php
// test_db.php - проверка подключения к базе данных
require_once 'config/database.php';
require_once 'lib/Database.php';

header('Content-Type: text/html; charset=utf-8');

echo "<h2>Тест подключения к базе данных</h2>";

try {
    // 1. Проверка подключения
    echo "<h3>1. Проверка подключения к PostgreSQL...</h3>";
    $db = Prostvor\Database::getConnection();
    echo "<p style='color: green;'>✅ Подключение успешно!</p>";
    
    // 2. Проверка таблиц
    echo "<h3>2. Проверка таблиц в базе 'creative_center_base'...</h3>";
    
    $tables = Prostvor\Database::fetchAll("
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public'
        ORDER BY table_name
    ");
    
    if (count($tables) > 0) {
        echo "<p style='color: green;'>✅ Найдено таблиц: " . count($tables) . "</p>";
        echo "<ul>";
        foreach ($tables as $table) {
            echo "<li>" . $table['table_name'] . "</li>";
        }
        echo "</ul>";
    } else {
        echo "<p style='color: red;'>❌ Таблицы не найдены</p>";
    }
    
    // 3. Проверка таблицы actors
    echo "<h3>3. Проверка таблицы actors...</h3>";
    $actors_count = Prostvor\Database::fetchOne("SELECT COUNT(*) as count FROM actors");
    echo "<p>Количество участников: " . $actors_count['count'] . "</p>";
    
    // 4. Проверка функции authenticate_user
    echo "<h3>4. Проверка функции authenticate_user...</h3>";
    $function_exists = Prostvor\Database::fetchOne("
        SELECT EXISTS(
            SELECT 1 FROM pg_proc 
            WHERE proname = 'authenticate_user'
        ) as exists
    ");
    
    if ($function_exists['exists']) {
        echo "<p style='color: green;'>✅ Функция authenticate_user существует</p>";
    } else {
        echo "<p style='color: orange;'>⚠️ Функция authenticate_user не найдена</p>";
    }
    
} catch (Exception $e) {
    echo "<p style='color: red;'>❌ Ошибка: " . $e->getMessage() . "</p>";
    echo "<pre>Подробности: " . $e->getTraceAsString() . "</pre>";
}

// 5. Проверка PHP расширений
echo "<h3>5. Проверка PHP расширений...</h3>";
$required_extensions = ['pdo', 'pdo_pgsql', 'json', 'openssl'];
foreach ($required_extensions as $ext) {
    if (extension_loaded($ext)) {
        echo "<p>✅ $ext</p>";
    } else {
        echo "<p style='color: red;'>❌ $ext (не установлено)</p>";
    }
}