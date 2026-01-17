<?php
// test-simple-pg.php
echo "Тест PostgreSQL подключения...\n";

// Простая попытка
try {
    $pdo = new PDO(
        'pgsql:host=localhost;port=5432;',
        'postgres',
        '',  // пустой пароль
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    echo "✅ Успешное подключение!\n";
    
    // Пробуем создать базу если её нет
    $stmt = $pdo->query("SELECT 1 FROM pg_database WHERE datname = 'creative_center_base'");
    if (!$stmt->fetch()) {
        echo "Базы 'creative_center_base' нет. Создаём...\n";
        $pdo->exec("CREATE DATABASE creative_center_base");
        echo "✅ База создана\n";
    } else {
        echo "✅ База 'creative_center_base' уже существует\n";
    }
    
} catch (PDOException $e) {
    echo "❌ Ошибка: " . $e->getMessage() . "\n";
    echo "Проверьте:\n";
    echo "1. Запущен ли PostgreSQL\n";
    echo "2. Правильный ли пароль для пользователя 'postgres'\n";
    echo "3. Настройки в pg_hba.conf\n";
}