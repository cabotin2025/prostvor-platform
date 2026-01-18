<?php
// simple-check.php
echo "<h2>Простая проверка подключения</h2>";

try {
    require_once 'config/database.php';
    require_once 'lib/Database.php';
    
    $db = Database::getInstance()->getConnection();
    echo "✅ Подключение к PostgreSQL установлено<br>";
    
    // Просто получаем список таблиц
    $sql = "SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'";
    
    $stmt = $db->query($sql);
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    if (empty($tables)) {
        echo "❌ В базе данных НЕТ таблиц<br>";
        echo "Нужно создать таблицы. Файл creative_center_base.sql пустой.<br>";
    } else {
        echo "✅ Найдено таблиц: " . count($tables) . "<br>";
        echo "Список: " . implode(", ", $tables);
    }
    
} catch(Exception $e) {
    echo "❌ Ошибка: " . $e->getMessage();
}