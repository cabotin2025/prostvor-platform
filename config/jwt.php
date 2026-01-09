<?php
/**
 * JWT Configuration
 */

define('JWT_SECRET', 'prostvor-secret-key-2025-change-in-production');
define('JWT_ALGORITHM', 'HS256');
define('JWT_EXPIRATION', 86400); // 24 часа

class JWT {
    public static function encode($payload, $key = JWT_SECRET, $alg = JWT_ALGORITHM) {
        $header = ['typ' => 'JWT', 'alg' => $alg];
        $payload['iat'] = time();
        $payload['exp'] = time() + JWT_EXPIRATION;
        
        $header_encoded = self::base64UrlEncode(json_encode($header));
        $payload_encoded = self::base64UrlEncode(json_encode($payload));
        
        $signature = hash_hmac('sha256', "$header_encoded.$payload_encoded", $key, true);
        $signature_encoded = self::base64UrlEncode($signature);
        
        return "$header_encoded.$payload_encoded.$signature_encoded";
    }
    
    public static function decode($jwt, $key = JWT_SECRET) {
        $parts = explode('.', $jwt);
        if (count($parts) !== 3) {
            throw new Exception('Invalid token format');
        }
        
        list($header_encoded, $payload_encoded, $signature_encoded) = $parts;
        
        $signature = self::base64UrlDecode($signature_encoded);
        $expected_signature = hash_hmac('sha256', "$header_encoded.$payload_encoded", $key, true);
        
        if (!hash_equals($signature, $expected_signature)) {
            throw new Exception('Invalid signature');
        }
        
        $payload = json_decode(self::base64UrlDecode($payload_encoded));
        
        if (isset($payload->exp) && $payload->exp < time()) {
            throw new Exception('Token expired');
        }
        
        return $payload;
    }
    
    public static function createForUser($actor_id, $nickname, $email, $status_id, $location_id = null, $actor_type_id = 1) {
        $payload = [
            'user_id' => $actor_id,
            'nickname' => $nickname,
            'email' => $email,
            'status_id' => $status_id,
            'actor_type_id' => $actor_type_id
        ];
        
        if ($location_id) {
            $payload['location_id'] = $location_id;
        }
        
        return self::encode($payload);
    }
    
    private static function base64UrlEncode($data) {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
    
    private static function base64UrlDecode($data) {
        return base64_decode(strtr($data, '-_', '+/'));
    }
}