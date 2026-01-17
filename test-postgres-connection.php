<?php
// test-postgres-connection.php
echo "<h2>Тестирование подключения к PostgreSQL</h2>";

// Тестовые подключения
$configs = [
    [
        'name' => 'Стандартное (localhost:5432)',
        'dsn' => 'pgsql:host=localhost;port=5432;dbname=creative_center_base',
        'user' => 'postgres',
        'pass' => ''  // оставьте пустым или укажите ваш пароль
    ],
    [
        'name' => 'Без пароля',
        'dsn' => 'pgsql:host=127.0.0.1;port=5432;dbname=creative_center_base',
        'user' => 'postgres',
        'pass' => ''
    ],
    [
        'name' => 'С паролем',
        'dsn' => 'pgsql:host=localhost;port=5432',
        'user' => 'postgres',
        'pass' => 'postgres'  // типичный пароль по умолчанию
    ]
];

foreach ($configs as $config) {
    echo "<h3>Попытка: {$config['name']}</h3>";
    
    try {
        $pdo = new PDO($config['dsn'], $config['user'], $config['pass'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
        ]);
        
        echo "✅ Успешно!<br>";
        
        // Проверяем список баз данных
        $stmt = $pdo->query("SELECT datname FROM pg_database WHERE datistemplate = false");
        $dbs = $stmt->fetchAll(PDO::FETCH_COLUMN);
        
        echo "Доступные базы: " . implode(', ', $dbs) . "<br>";
        
        if (in_array('creative_center_base', $dbs)) {
            echo "✅ База 'creative_center_base' найдена!<br>";
            
            // Подключаемся к конкретной базе
            $pdo2 = new PDO(
                "pgsql:host=localhost;port=5432;dbname=creative_center_base",
                $config['user'],
                $config['pass']
            );
            
            // Проверяем таблицы
            $stmt2 = $pdo2->query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'");
            $tables = $stmt2->fetchAll(PDO::FETCH_COLUMN);
            
            if (empty($tables)) {
                echo "⚠️ В базе нет таблиц<br>";
            } else {
                echo "✅ Таблицы: " . implode(', ', $tables) . "<br>";
            }
        } else {
            echo "❌ База 'creative_center_base' не найдена<br>";
        }
        
    } catch (PDOException $e) {
        echo "❌ Ошибка: " . $e->getMessage() . "<br>";
    }
    
    echo "<hr>";
}