<?php
// config/database.php - ИСПРАВЛЕННЫЙ
class DatabaseConfig {
    // PostgreSQL настройки
    const HOST = 'localhost';
    const PORT = '5432';
    const DB_NAME = 'creative_center_base';
    const USERNAME = 'postgres';
    const PASSWORD = '123456';
    const CHARSET = 'UTF8';
}

// Создаем глобальное подключение PDO для обратной совместимости
function getPDOConnection() {
    static $pdo = null;
    
    if ($pdo === null) {
        try {
            $dsn = "pgsql:host=" . DatabaseConfig::HOST . 
                   ";port=" . DatabaseConfig::PORT . 
                   ";dbname=" . DatabaseConfig::DB_NAME;
            
            $pdo = new PDO(
                $dsn,
                DatabaseConfig::USERNAME,
                DatabaseConfig::PASSWORD,
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false
                ]
            );
            
            // Устанавливаем кодировку
            $pdo->exec("SET NAMES 'UTF8'");
            
        } catch(PDOException $e) {
            die("❌ Ошибка подключения к PostgreSQL: " . $e->getMessage());
        }
    }
    
    return $pdo;
}

// Глобальная переменная для обратной совместимости
$pdo = getPDOConnection();