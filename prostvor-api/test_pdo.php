<?php
echo "<h2>Проверка расширений</h2>";

// Попробуем загрузить расширение вручную
if (!extension_loaded('pdo_pgsql')) {
    echo "pdo_pgsql не загружен. Попробуем загрузить...<br>";
    
    // Для Windows
    if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
        if (extension_loaded('pdo')) {
            echo "PDO загружен<br>";
            // Пока используем SQLite для тестирования
            echo "Для тестирования используем SQLite<br>";
            
            try {
                $db = new PDO('sqlite::memory:');
                echo "✅ SQLite работает (временное решение)<br>";
                echo "Для PostgreSQL нужно установить pdo_pgsql<br>";
            } catch (Exception $e) {
                echo "❌ Ошибка: " . $e->getMessage();
            }
        }
    }
}

// Проверка доступных драйверов PDO
echo "<h3>Доступные драйверы PDO:</h3>";
print_r(PDO::getAvailableDrivers());
?>