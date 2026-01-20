<?php
/**
 * Исправление кодировки русских текстов в базе
 */

$host = 'localhost';
$port = '5432';
$dbname = 'creative_center_base';
$username = 'postgres';
$password = '123456';

try {
    $dsn = "pgsql:host=$host;port=$port;dbname=$dbname";
    $pdo = new PDO($dsn, $username, $password);
    
    // Функция для исправления кодировки
    function fix_encoding($text) {
        // Попробуем разные кодировки
        $encodings = ['Windows-1251', 'CP866', 'KOI8-R', 'ISO-8859-5'];
        
        foreach ($encodings as $encoding) {
            $decoded = @iconv($encoding, 'UTF-8', $text);
            if ($decoded && mb_check_encoding($decoded, 'UTF-8')) {
                return $decoded;
            }
        }
        
        return $text; // Если не удалось, оставляем как есть
    }
    
    // Исправляем actors
    $stmt = $pdo->query("SELECT actor_id, nickname FROM actors");
    $actors = $stmt->fetchAll();
    
    $fixed_count = 0;
    foreach ($actors as $actor) {
        $fixed = fix_encoding($actor['nickname']);
        if ($fixed !== $actor['nickname']) {
            $stmt = $pdo->prepare("UPDATE actors SET nickname = ? WHERE actor_id = ?");
            $stmt->execute([$fixed, $actor['actor_id']]);
            $fixed_count++;
        }
    }
    
    echo "✅ Исправлено $fixed_count записей в таблице actors\n";
    
} catch (Exception $e) {
    echo "❌ Ошибка: " . $e->getMessage();
}