<?php
// find-php-output-issues.php
echo "<h2>🔍 Поиск вывода до заголовков в PHP файлах</h2>";

function checkFileForOutput($file) {
    $content = file_get_contents($file);
    $lines = explode("\n", $content);
    
    $issues = [];
    $foundHeader = false;
    
    for ($i = 0; $i < count($lines); $i++) {
        $line = $lines[$i];
        $lineNum = $i + 1;
        
        // Ищем заголовки
        if (preg_match('/header\(/i', $line)) {
            $foundHeader = true;
        }
        
        // Ищем вывод ДО заголовков
        if (!$foundHeader) {
            // Проверяем на вывод
            if (preg_match('/echo\s+|print\s+|printf\s+|var_dump|print_r|<\?php\s*[^?]/', $line) ||
                preg_match('/^\s*<\?=/', $line) ||
                preg_match('/^\s*<\?/', $line) && !preg_match('/^\s*<\?php/', $line)) {
                $issues[] = "Строка $lineNum: возможный вывод до заголовков - " . htmlspecialchars(trim($line));
            }
        }
        
        // Проверяем на закрывающий тег PHP перед кодом
        if (preg_match('/\?>\s*<\?php/', $line)) {
            $issues[] = "Строка $lineNum: лишние пробелы/переносы между ?> и <?php";
        }
    }
    
    return $issues;
}

// Проверяем все API файлы
$apiFiles = [
    'api/actors/index.php',
    'api/actors/statuses.php',
    'api/auth/login.php',
    'api/auth/check-token.php',
    'api/projects/index.php',
    'config/database.php',
    'lib/Database.php'
];

foreach ($apiFiles as $file) {
    if (!file_exists($file)) {
        echo "<h3>$file: ❌ не существует</h3>";
        continue;
    }
    
    echo "<h3>$file:</h3>";
    $issues = checkFileForOutput($file);
    
    if (empty($issues)) {
        echo "✅ Нет проблем с выводом до заголовков<br>";
    } else {
        echo "❌ Найдены проблемы:<br>";
        echo "<ul>";
        foreach ($issues as $issue) {
            echo "<li>$issue</li>";
        }
        echo "</ul>";
    }
    
    // Проверяем BOM
    $content = file_get_contents($file);
    if (substr($content, 0, 3) === "\xEF\xBB\xBF") {
        echo "⚠️ Файл содержит BOM (Byte Order Mark)<br>";
    }
}