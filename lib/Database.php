<?php
namespace Prostvor;

class Database {
    private static $connection = null;
    
    public static function getConnection() {
        if (self::$connection === null) {
            try {
                $dsn = "pgsql:host=" . DB_HOST . 
                       ";port=" . DB_PORT . 
                       ";dbname=" . DB_NAME . 
                       ";user=" . DB_USER . 
                       ";password=" . DB_PASSWORD;
                
                self::$connection = new \PDO($dsn);
                self::$connection->setAttribute(\PDO::ATTR_ERRMODE, \PDO::ERRMODE_EXCEPTION);
                self::$connection->setAttribute(\PDO::ATTR_DEFAULT_FETCH_MODE, \PDO::FETCH_ASSOC);
                self::$connection->exec("SET NAMES 'UTF8'");
                
            } catch (\PDOException $e) {
                error_log("Database connection error: " . $e->getMessage());
                throw new \Exception("Database connection failed");
            }
        }
        
        return self::$connection;
    }
    
    public static function query($sql, $params = []) {
        $stmt = self::getConnection()->prepare($sql);
        $stmt->execute($params);
        return $stmt;
    }
    
    public static function fetchAll($sql, $params = []) {
        $stmt = self::query($sql, $params);
        return $stmt->fetchAll();
    }
    
    public static function fetchOne($sql, $params = []) {
        $stmt = self::query($sql, $params);
        return $stmt->fetch();
    }
    
    public static function insert($table, $data) {
        $columns = implode(', ', array_keys($data));
        $placeholders = ':' . implode(', :', array_keys($data));
        
        $sql = "INSERT INTO $table ($columns) VALUES ($placeholders) RETURNING *";
        $stmt = self::query($sql, $data);
        
        return $stmt->fetch();
    }
    
    public static function lastInsertId() {
        return self::getConnection()->lastInsertId();
    }
}