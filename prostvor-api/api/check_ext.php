<?php
echo "<h2>Проверка расширений PostgreSQL</h2>";

// Пытаемся загрузить расширение вручную
$ext_dir = ini_get('extension_dir');
echo "Папка расширений: $ext_dir<br>";

// Проверяем доступные DLL
if (is_dir($ext_dir)) {
    $files = scandir($ext_dir);
    echo "Найденные DLL:<br>";
    foreach ($files as $file) {
        if (strpos($file, 'pgsql') !== false || strpos($file, 'pdo') !== false) {
            echo "• $file<br>";
        }
    }
}

// Альтернатива: используем SQLite временно
echo "<h3>Временное решение:</h3>";
echo "Пока настраиваем pdo_pgsql, используйте SQLite для тестирования<br>";
?>