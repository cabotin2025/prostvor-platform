<?php
// test-pages.php
echo "<h2>🌐 Проверка отображения страниц</h2>";

$pages = [
    'Главная' => 'index.html',
    'Проекты' => 'pages/Projects.html',
    'Актеры' => 'pages/actors.html',
    'Вход/Регистрация' => 'pages/enter-reg.html'
];

foreach ($pages as $name => $file) {
    echo "<h3>$name ($file):</h3>";
    
    if (file_exists($file)) {
        echo "✅ Файл существует<br>";
        
        // Проверяем, можно ли прочитать
        $content = file_get_contents($file);
        if ($content !== false) {
            echo "✅ Файл читается (" . strlen($content) . " байт)<br>";
            
            // Проверяем есть ли JavaScript ошибки в подключении
            if (strpos($content, 'js/config.js') !== false) {
                echo "✅ Подключен config.js<br>";
            }
            
            if (strpos($content, 'api') !== false) {
                echo "✅ Есть API вызовы<br>";
            }
        } else {
            echo "❌ Не удалось прочитать файл<br>";
        }
    } else {
        echo "❌ Файл не найден<br>";
    }
    
    echo "Ссылка: <a href='$file' target='_blank'>Открыть $name</a><br>";
    echo "<hr>";
}