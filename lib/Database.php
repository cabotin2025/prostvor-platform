<?php
// lib/Database.php - ИСПРАВЛЕННЫЙ ДЛЯ POSTGRESQL
class Database {
    private static $instance = null;
    private $connection;
    
    private function __construct() {
        try {
            // Подключение к PostgreSQL
            $dsn = DatabaseConfig::getDSN();
            $this->connection = new PDO(
                $dsn,
                DatabaseConfig::USERNAME,
                DatabaseConfig::PASSWORD,
                DatabaseConfig::getConnectionParams()
            );
            
            // Устанавливаем кодировку
            $this->connection->exec("SET NAMES 'UTF8'");
            
        } catch(PDOException $e) {
            die("❌ Ошибка подключения к PostgreSQL: " . $e->getMessage());
        }
    }
    
    public static function getInstance() {
        if (self::$instance == null) {
            self::$instance = new Database();
        }
        return self::$instance;
    }
    
    public function getConnection() {
        return $this->connection;
    }
}