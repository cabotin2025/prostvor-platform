<?php
// check-real-structure.php
require_once 'config/database.php';
require_once 'lib/Database.php';

header('Content-Type: text/html; charset=utf-8');
echo "<h2>🔍 Проверка РЕАЛЬНОЙ структуры базы данных</h2>";

try {
    $db = Database::getInstance()->getConnection();
    echo "✅ Подключение установлено<br>";
    
    // 1. Получаем ВСЕ существующие таблицы
    $sql = "SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            ORDER BY table_name";
    
    $stmt = $db->query($sql);
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo "<h3>📋 Существующие таблицы (" . count($tables) . "):</h3>";
    
    if (empty($tables)) {
        echo "❌ Нет таблиц в базе данных!<br>";
        echo "Нужно выполнить creative_center_base.sql<br>";
    } else {
        echo "<ul>";
        foreach ($tables as $table) {
            echo "<li><strong>$table</strong>";
            
            // Получаем колонки для каждой таблицы
            $colSql = "SELECT column_name, data_type, is_nullable 
                      FROM information_schema.columns 
                      WHERE table_name = :table 
                      ORDER BY ordinal_position";
            $colStmt = $db->prepare($colSql);
            $colStmt->execute([':table' => $table]);
            $columns = $colStmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo " (" . count($columns) . " колонок):<br><small>";
            foreach ($columns as $col) {
                echo $col['column_name'] . " " . $col['data_type'];
                if ($col['is_nullable'] === 'NO') echo " NOT NULL";
                echo ", ";
            }
            echo "</small></li>";
        }
        echo "</ul>";
    }
    
    // 2. Проверяем конкретно таблицы, на которые есть ссылки в коде
    echo "<h3>🔎 Проверка таблиц, упоминаемых в коде:</h3>";
    
    // Из api файлов вижу обращения к:
    $codeTables = ['users', 'projects', 'actors', 'tasks', 'messages'];
    
    foreach ($codeTables as $table) {
        $checkSql = "SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = :table
        )";
        
        $checkStmt = $db->prepare($checkSql);
        $checkStmt->execute([':table' => $table]);
        $exists = $checkStmt->fetchColumn();
        
        if ($exists) {
            echo "✅ Таблица <strong>'$table'</strong> существует<br>";
            
            // Проверяем есть ли данные
            $countSql = "SELECT COUNT(*) FROM $table";
            $countStmt = $db->query($countSql);
            $count = $countStmt->fetchColumn();
            echo "   📊 Записей: $count<br>";
        } else {
            echo "❌ Таблица <strong>'$table'</strong> ОТСУТСТВУЕТ!<br>";
        }
        echo "<br>";
    }
    
} catch(PDOException $e) {
    echo "❌ Ошибка: " . $e->getMessage();
    echo "<br>Проверьте настройки подключения в config/database.php";
}