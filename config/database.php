<?php
// Временно закомментируйте весь код и оставьте только подключение
try {
    $pdo = new PDO('pgsql:host=localhost;dbname=creative_center', 'username', 'password');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch(PDOException $e) {
    // Возвращаем JSON ошибку вместо исключения
    header('Content-Type: application/json');
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database connection failed']);
    exit;
}

// Конфигурация базы данных - ИЗМЕНИТЕ ПАРОЛЬ!
//define('DB_HOST', 'localhost');
//define('DB_PORT', '5432');
//define('DB_NAME', 'creative_center_base');
//define('DB_USER', 'postgres');
//define('DB_PASSWORD', '123456'); // ← ВАЖНО: замените на ваш пароль!
//define('DB_CHARSET', 'UTF8');

// JWT настройки
//define('JWT_SECRET', 'prostvor_super_secret_key_2025_change_in_production!');
//define('JWT_ALGORITHM', 'HS256');
//define('JWT_EXPIRE', 86400); // 24 часа

// URL приложения
//define('APP_URL', 'http://localhost:8000');
//define('APP_ENV', 'development');

// Автозагрузка Composer
//require_once __DIR__ . '/../vendor/autoload.php';