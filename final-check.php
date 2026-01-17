<?php
// final-check.php
require_once 'config/database.php';
require_once 'lib/Database.php';

header('Content-Type: text/html; charset=utf-8');
echo "<h2>✅ ПРОВЕРКА ПОДКЛЮЧЕНИЯ К POSTGRESQL</h2>";

try {
    $db = Database::getInstance()->getConnection();
    echo "🎉 УСПЕШНО! Подключение к PostgreSQL установлено<br>";
    echo "База данных: " . DatabaseConfig::DB_NAME . "<br>";
    echo "Пользователь: " . DatabaseConfig::USERNAME . "<br><br>";
    
    // Проверяем таблицы
    echo "<h3>📊 ПРОВЕРКА СТРУКТУРЫ БАЗЫ:</h3>";
    
    $sql = "SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            ORDER BY table_name";
    
    $stmt = $db->query($sql);
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    if (empty($tables)) {
        echo "⚠️ В базе НЕТ таблиц!<br>";
        echo "Нужно создать таблицы. Файл creative_center_base.sql пустой.<br>";
        
        echo "<h3>🛠 СОЗДАНИЕ БАЗОВЫХ ТАБЛИЦ:</h3>";
        
        // Создаем таблицу users (основную)
        $createUsers = "CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            login VARCHAR(50) UNIQUE NOT NULL,
            email VARCHAR(100) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            role VARCHAR(20) DEFAULT 'user',
            status VARCHAR(20) DEFAULT 'active',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_login TIMESTAMP
        )";
        
        $db->exec($createUsers);
        echo "✅ Таблица 'users' создана<br>";
        
        // Создаем таблицу projects
        $createProjects = "CREATE TABLE IF NOT EXISTS projects (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            description TEXT,
            owner_id INTEGER,
            status VARCHAR(20) DEFAULT 'active',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )";
        
        $db->exec($createProjects);
        echo "✅ Таблица 'projects' создана<br>";
        
        // Перепроверяем
        $stmt = $db->query($sql);
        $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
        echo "<br>✅ Теперь таблиц: " . count($tables) . "<br>";
    }
    
    echo "<h3>📋 СУЩЕСТВУЮЩИЕ ТАБЛИЦЫ:</h3>";
    
    if (!empty($tables)) {
        echo "<ul>";
        foreach ($tables as $table) {
            echo "<li><strong>$table</strong>";
            
            // Показываем колонки
            $colSql = "SELECT column_name, data_type 
                      FROM information_schema.columns 
                      WHERE table_name = '$table' 
                      ORDER BY ordinal_position";
            $colStmt = $db->query($colSql);
            $columns = $colStmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo " (";
            $colNames = [];
            foreach ($columns as $col) {
                $colNames[] = $col['column_name'];
            }
            echo implode(", ", $colNames);
            echo ")</li>";
        }
        echo "</ul>";
    }
    
    echo "<hr>";
    echo "<h3>🎯 СЛЕДУЮЩИЕ ШАГИ:</h3>";
    echo "1. Подключение к PostgreSQL НАСТРОЕНО ✅<br>";
    echo "2. Теперь можно проверить отображение страниц<br>";
    
    // Простая проверка API
    echo "<br><a href='test-connection.php' target='_blank'>Проверить API подключение</a>";
    
} catch(PDOException $e) {
    echo "❌ Ошибка: " . $e->getMessage();
}