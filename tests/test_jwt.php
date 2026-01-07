<?php
require_once 'vendor/autoload.php';

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

echo "✅ Composer установлен успешно!\n";
echo "✅ JWT библиотека загружена: " . class_exists('Firebase\JWT\JWT') . "\n";

// Тест создания токена
$secret_key = 'test_key';
$payload = [
    'user_id' => 123,
    'email' => 'test@example.com'
];

try {
    $jwt = JWT::encode($payload, $secret_key, 'HS256');
    echo "✅ Токен создан: " . substr($jwt, 0, 20) . "...\n";
    
    $decoded = JWT::decode($jwt, new Key($secret_key, 'HS256'));
    echo "✅ Токен проверен: user_id=" . $decoded->user_id . "\n";
    
    echo "\n🎉 Всё работает! Можно создавать бэкенд.\n";
} catch (Exception $e) {
    echo "❌ Ошибка: " . $e->getMessage() . "\n";
}