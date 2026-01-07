<?php
require_once __DIR__ . '/database.php';

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

class JWTManager {
    
    public static function generateToken($actor_id, $email) {
        $payload = [
            'iss' => APP_URL,
            'aud' => APP_URL,
            'iat' => time(),
            'exp' => time() + JWT_EXPIRE,
            'data' => [
                'actor_id' => $actor_id,
                'email' => $email
            ]
        ];
        
        return JWT::encode($payload, JWT_SECRET, JWT_ALGORITHM);
    }
    
    public static function validateToken($token) {
        try {
            $decoded = JWT::decode($token, new Key(JWT_SECRET, JWT_ALGORITHM));
            return (array) $decoded;
        } catch (Exception $e) {
            return false;
        }
    }
    
    public static function getAuthUser() {
        $headers = getallheaders();
        
        if (isset($headers['Authorization'])) {
            $authHeader = $headers['Authorization'];
        } elseif (isset($_SERVER['HTTP_AUTHORIZATION'])) {
            $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
        } else {
            return false;
        }
        
        if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
            $token = $matches[1];
            return self::validateToken($token);
        }
        
        return false;
    }
} 
