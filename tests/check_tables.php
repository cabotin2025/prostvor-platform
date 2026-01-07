<?php
require_once 'config/database.php';
require_once 'lib/Database.php';

echo "Проверка структуры таблиц...\n\n";

try {
    // 1. Таблица actors
    echo "1. ТАБЛИЦА actors:\n";
    $actors_structure = Prostvor\Database::fetchAll("
        SELECT 
            column_name,
            data_type,
            character_maximum_length as max_len,
            is_nullable,
            column_default
        FROM information_schema.columns
        WHERE table_name = 'actors'
        ORDER BY ordinal_position
    ");
    
    foreach ($actors_structure as $col) {
        echo "  - {$col['column_name']}: {$col['data_type']}";
        if ($col['max_len']) echo "({$col['max_len']})";
        echo " [NULL: {$col['is_nullable']}]";
        if ($col['column_default']) echo " DEFAULT: {$col['column_default']}";
        echo "\n";
    }
    
    // 2. Существующие accounts
    echo "\n2. Существующие accounts в actors:\n";
    $existing_accounts = Prostvor\Database::fetchAll("
        SELECT account, LENGTH(account) as len
        FROM actors 
        WHERE account IS NOT NULL
        ORDER BY account
        LIMIT 5
    ");
    
    if (count($existing_accounts) > 0) {
        foreach ($existing_accounts as $acc) {
            echo "  - '{$acc['account']}' ({$acc['len']} символов)\n";
        }
    } else {
        echo "  (нет записей с account)\n";
    }
    
    // 3. Проверяем ограничения (constraints)
    echo "\n3. ОГРАНИЧЕНИЯ таблицы actors:\n";
    $constraints = Prostvor\Database::fetchAll("
        SELECT 
            tc.constraint_name,
            tc.constraint_type,
            kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
            ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'actors'
        ORDER BY tc.constraint_type, tc.constraint_name
    ");
    
    foreach ($constraints as $con) {
        echo "  - {$con['constraint_name']}: {$con['constraint_type']} на {$con['column_name']}\n";
    }
    
} catch (Exception $e) {
    echo "❌ Ошибка: " . $e->getMessage() . "\n";
}