<?php
// test_postgres.php
header('Content-Type: text/html; charset=utf-8');

echo "<h2>Тест PostgreSQL подключения</h2>";

try {
    // Прямое подключение к PostgreSQL
    $pdo = new PDO(
        'pgsql:host=localhost;dbname=creative_center',
        'postgres',
        'postgres', // ваш пароль
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    echo "✅ Подключение к PostgreSQL успешно!<br>";
    
    // Тестируем простой запрос
    $stmt = $pdo->query("SELECT version()");
    $version = $stmt->fetchColumn();
    echo "Версия PostgreSQL: $version<br>";
    
    // Проверяем функции
    $stmt = $pdo->query("SELECT proname FROM pg_proc WHERE proname LIKE '%register%'");
    $functions = $stmt->fetchAll();
    
    echo "Найденные функции: ";
    foreach ($functions as $func) {
        echo $func['proname'] . " ";
    }
    
} catch (PDOException $e) {
    echo "❌ Ошибка PostgreSQL: " . $e->getMessage() . "<br>";
    
    // Проверяем доступность порта
    $port = 5432;
    $timeout = 3;
    $socket = @fsockopen('localhost', $port, $errno, $errstr, $timeout);
    
    if ($socket) {
        echo "✅ Порт $port открыт<br>";
        fclose($socket);
    } else {
        echo "❌ Порт $port закрыт: $errstr<br>";
    }
}
?>