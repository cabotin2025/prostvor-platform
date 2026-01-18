<?php
// test-postgres-password.php
echo "<h2>🔐 Проверка пароля PostgreSQL</h2>";

$host = 'localhost';
$port = '5432';
$user = 'postgres';

// Распространенные пароли для проверки
$passwords = [
    '',             // пустой
    'postgres',     // стандартный по умолчанию
    'postgres123',  // postgres + цифры
    'password',
    '123456',
    'admin',
    'root',
    'Postgres',     // с заглавной
    '12345',
    'postgre',
    'qwerty'
];

echo "Проверяем подключение к PostgreSQL...<br>";
echo "Хост: $host, Порт: $port, Пользователь: $user<br><br>";

foreach ($passwords as $password) {
    echo "Пароль: <strong>" . ($password ? $password : '(пустой)') . "</strong> - ";
    
    try {
        $pdo = new PDO(
            "pgsql:host=$host;port=$port",
            $user,
            $password,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 3]
        );
        
        echo "✅ УСПЕХ!<br>";
        
        // Проверяем список баз
        $stmt = $pdo->query("SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname");
        $dbs = $stmt->fetchAll(PDO::FETCH_COLUMN);
        
        echo "Доступные базы: " . implode(', ', $dbs) . "<br>";
        
        // Проверяем наличие нашей базы
        if (in_array('creative_center_base', $dbs)) {
            echo "🎯 База 'creative_center_base' найдена!<br>";
        }
        
        break; // Нашли правильный пароль
        
    } catch (PDOException $e) {
        echo "❌ Ошибка<br>";
    }
}

echo "<hr><h3>Альтернативные варианты:</h3>";

// Пробуем подключиться без пароля к другим базам
try {
    // Пробуем подключиться к стандартной базе postgres
    $pdo = new PDO(
        "pgsql:host=$host;port=$port;dbname=postgres",
        $user,
        '',
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    echo "✅ Успешное подключение к базе 'postgres'<br>";
    
    // Проверяем существующие базы
    $stmt = $pdo->query("SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname");
    $allDbs = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo "Все базы данных: <br>";
    foreach ($allDbs as $db) {
        echo "- $db<br>";
    }
    
} catch (PDOException $e) {
    echo "❌ Не удалось подключиться к базе 'postgres'<br>";
}