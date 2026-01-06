<?php
// Простой тест API
echo "Тест PHP API:<br>";
echo "1. Проверка подключения к БД... ";
require_once 'includes/Database.php';
try {
    $db = Database::getConnection();
    echo "✅ Успешно<br>";
    
    echo "2. Проверка функции register_person... ";
    $stmt = $db->prepare("SELECT proname FROM pg_proc WHERE proname = 'register_person'");
    $stmt->execute();
    echo $stmt->rowCount() > 0 ? "✅ Найдена<br>" : "❌ Не найдена<br>";
} catch (Exception $e) {
    echo "❌ Ошибка: " . $e->getMessage();
}
?>