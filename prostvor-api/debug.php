<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h2>Диагностика PHP API</h2>";

// 1. Проверка PHP
echo "<h3>1. Проверка PHP:</h3>";
echo "Версия PHP: " . phpversion() . "<br>";
echo "Расширение PDO: " . (extension_loaded('pdo') ? '✅ Загружено' : '❌ Отсутствует') . "<br>";
echo "Расширение pdo_pgsql: " . (extension_loaded('pdo_pgsql') ? '✅ Загружено' : '❌ Отсутствует') . "<br>";

// 2. Проверка структуры папок
echo "<h3>2. Структура папок:</h3>";
function listDir($dir, $depth = 0) {
    $items = scandir($dir);
    foreach ($items as $item) {
        if ($item != '.' && $item != '..') {
            echo str_repeat('&nbsp;', $depth * 4) . $item . "<br>";
            if (is_dir($dir . '/' . $item) && $depth < 3) {
                listDir($dir . '/' . $item, $depth + 1);
            }
        }
    }
}
listDir(__DIR__);

// 3. Проверка Database.php
echo "<h3>3. Проверка Database.php:</h3>";
if (file_exists(__DIR__ . '/includes/Database.php')) {
    echo "✅ Database.php существует<br>";
    
    // Проверяем конфигурацию
    $content = file_get_contents(__DIR__ . '/includes/Database.php');
    if (strpos($content, 'creative_center') !== false) {
        echo "✅ Имя БД указано<br>";
    } else {
        echo "❌ Имя БД не найдено в файле<br>";
    }
} else {
    echo "❌ Database.php не найден!<br>";
}

// 4. Проверка API файлов
echo "<h3>4. Проверка API файлов:</h3>";
$apiFiles = [
    'api/auth/register.php',
    'api/auth/login.php',
    'api/projects/index.php'
];

foreach ($apiFiles as $file) {
    if (file_exists(__DIR__ . '/' . $file)) {
        echo "✅ " . $file . " существует (" . filesize(__DIR__ . '/' . $file) . " байт)<br>";
    } else {
        echo "❌ " . $file . " не найден!<br>";
    }
}
?>