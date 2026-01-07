<?php
// config/database.php

// Конфигурация базы данных - ИЗМЕНИТЕ ПАРОЛЬ!
define('DB_HOST', 'localhost');
define('DB_PORT', '5432');
define('DB_NAME', 'creative_center_base');
define('DB_USER', 'postgres');
define('DB_PASSWORD', '123456'); // ← ВАЖНО: замените на ваш пароль!
define('DB_CHARSET', 'UTF8');

// JWT настройки
define('JWT_SECRET', 'prostvor_super_secret_key_2025_change_in_production!');
define('JWT_ALGORITHM', 'HS256');
define('JWT_EXPIRE', 86400); // 24 часа

// URL приложения
define('APP_URL', 'http://localhost:8000');
define('APP_ENV', 'development');

// Автозагрузка Composer
require_once __DIR__ . '/../vendor/autoload.php';