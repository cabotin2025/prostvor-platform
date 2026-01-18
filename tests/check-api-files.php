<?php
// check-api-files.php
echo "<h2>🔍 Проверка API файлов</h2>";

$apiFiles = [
    'api/actors/index.php',
    'api/auth/login.php',
    'api/projects/index.php',
    'api/auth/check-token.php',
    '.htaccess'
];

foreach ($apiFiles as $file) {
    echo "<h3>$file:</h3>";
    
    if (file_exists($file)) {
        echo "✅ Файл существует<br>";
        
        // Проверяем содержимое
        $content = file_get_contents($file);
        if ($content !== false) {
            $size = strlen($content);
            echo "Размер: $size байт<br>";
            
            // Проверяем подключение к базе
            if (strpos($content, 'database') !== false || 
                strpos($content, 'Database') !== false) {
                echo "✅ Есть подключение к базе<br>";
            }
            
            if (strpos($content, 'PDO') !== false) {
                echo "✅ Используется PDO<br>";
            }
        }
    } else {
        echo "❌ Файл не найден<br>";
        
        // Создаем минимальный API файл если его нет
        if (strpos($file, 'api/') === 0) {
            echo "Создаю базовый файл...<br>";
            $dir = dirname($file);
            if (!is_dir($dir)) {
                mkdir($dir, 0777, true);
            }
            
            file_put_contents($file, "<?php\n// API endpoint: $file\nhttp_response_code(501);\necho json_encode(['error' => 'Not implemented']);");
            echo "✅ Создан<br>";
        }
    }
    echo "<hr>";
}