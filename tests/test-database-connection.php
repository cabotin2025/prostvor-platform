<?php
// test-database-connection.php
echo "<h2>🔍 Тестирование подключения к базе данных</h2>";

// Тест 1: Подключаем config/database.php
echo "<h3>1. Подключение config/database.php:</h3>";
require_once 'config/database.php';

if (class_exists('DatabaseConfig')) {
    echo "✅ Класс DatabaseConfig существует<br>";
    echo "DB_NAME: " . DatabaseConfig::DB_NAME . "<br>";
    echo "USERNAME: " . DatabaseConfig::USERNAME . "<br>";
} else {
    echo "❌ Класс DatabaseConfig не существует<br>";
}

// Тест 2: Проверяем глобальную переменную $pdo
echo "<h3>2. Проверка глобальной переменной \$pdo:</h3>";
if (isset($pdo) && $pdo instanceof PDO) {
    echo "✅ \$pdo существует и является экземпляром PDO<br>";
    
    // Пробуем выполнить простой запрос
    try {
        $stmt = $pdo->query("SELECT version() as postgres_version");
        $result = $stmt->fetch();
        echo "✅ Версия PostgreSQL: " . $result['postgres_version'] . "<br>";
    } catch(Exception $e) {
        echo "❌ Ошибка запроса: " . $e->getMessage() . "<br>";
    }
} else {
    echo "❌ \$pdo не существует или не PDO<br>";
    var_dump($pdo);
}

// Тест 3: Проверяем функцию getPDOConnection()
echo "<h3>3. Проверка функции getPDOConnection():</h3>";
if (function_exists('getPDOConnection')) {
    echo "✅ Функция getPDOConnection() существует<br>";
    
    $testPdo = getPDOConnection();
    if ($testPdo instanceof PDO) {
        echo "✅ Функция возвращает PDO<br>";
        
        // Проверяем таблицы
        $stmt = $testPdo->query("SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'public'");
        $count = $stmt->fetchColumn();
        echo "✅ Количество таблиц в базе: $count<br>";
    }
} else {
    echo "❌ Функция getPDOConnection() не существует<br>";
}