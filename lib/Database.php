<?php
// lib/Database.php
class Database {
    private static $instance = null;
    private $connection;
    
    private function __construct() {
        try {
            // Для PostgreSQL
            $dsn = DatabaseConfig::getPDODSN();
            $this->connection = new PDO(
                $dsn,
                DatabaseConfig::USERNAME,
                DatabaseConfig::PASSWORD
            );
            $this->connection->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $this->connection->exec("SET NAMES 'UTF8'");
            
        } catch(PDOException $e) {
            die("Connection failed: " . $e->getMessage());
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
    
    // Метод для проверки существования таблицы в PostgreSQL
    public function tableExists($tableName) {
        $sql = "SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = :table_name
        )";
        
        $stmt = $this->connection->prepare($sql);
        $stmt->execute(['table_name' => $tableName]);
        return $stmt->fetchColumn();
    }
}