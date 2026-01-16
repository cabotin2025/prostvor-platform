<?php
/**
 * Конфигурация подключения к базе данных PostgreSQL
 */

class DatabaseConfig {
    // Для PostgreSQL
    const HOST = 'localhost';
    const PORT = '5432';
    const DB_NAME = 'creative_center_base';
    const USERNAME = 'postgres'; // измените на вашего пользователя
    const PASSWORD = 'ваш_пароль'; // измените на ваш пароль
    
    // Для подключения
    public static function getDSN() {
        return "pgsql:host=" . self::HOST . 
               ";port=" . self::PORT . 
               ";dbname=" . self::DB_NAME . 
               ";user=" . self::USERNAME . 
               ";password=" . self::PASSWORD;
    }
    
    // Альтернативный вариант DSN
    public static function getPDODSN() {
        return "pgsql:host=" . self::HOST . 
               ";port=" . self::PORT . 
               ";dbname=" . self::DB_NAME;
    }
}