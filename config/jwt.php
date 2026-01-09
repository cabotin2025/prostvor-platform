<?php
/**
 * JWT (JSON Web Token) конфигурация и обработка
 * Для работы с аутентификацией в платформе Prostvor
 */

// ==================== КОНФИГУРАЦИЯ ====================
/**
 * Секретный ключ для подписи JWT токенов
 * ВНИМАНИЕ: В продакшене используйте сложный случайный ключ длиной не менее 32 символа
 * Никогда не храните секретный ключ в публичном репозитории
 */
define('JWT_SECRET', 'prostvor-platform-secret-key-change-in-production-2025');

/**
 * Алгоритм подписи JWT токенов
 * Рекомендуемые значения: HS256, HS384, HS512
 */
define('JWT_ALGORITHM', 'HS256');

/**
 * Время жизни токена (в секундах)
 * 86400 секунд = 24 часа
 * 604800 секунд = 7 дней
 */
define('JWT_EXPIRATION', 86400);

/**
 * Время обновления токена (в секундах)
 * Если токен старше этого времени, рекомендуется обновить его
 */
define('JWT_REFRESH_THRESHOLD', 43200); // 12 часов

/**
 * Идентификатор издателя (issuer claim)
 */
define('JWT_ISSUER', 'prostvor-platform');

/**
 * Идентификатор аудитории (audience claim)
 */
define('JWT_AUDIENCE', 'prostvor-users');

// ==================== КЛАСС JWT ====================
class JWT {
    /**
     * Кодирование данных в JWT токен
     * 
     * @param array $payload Данные для кодирования
     * @param string $key Секретный ключ
     * @param string $alg Алгоритм подписи
     * @return string JWT токен
     * @throws Exception
     */
    public static function encode(array $payload, string $key = JWT_SECRET, string $alg = JWT_ALGORITHM): string {
        // Проверяем алгоритм
        $supported_algs = [
            'HS256' => 'sha256',
            'HS384' => 'sha384', 
            'HS512' => 'sha512'
        ];
        
        if (!isset($supported_algs[$alg])) {
            throw new Exception('Неподдерживаемый алгоритм подписи: ' . $alg);
        }
        
        // Заголовок токена
        $header = [
            'typ' => 'JWT',
            'alg' => $alg,
            'iss' => JWT_ISSUER,
            'aud' => JWT_AUDIENCE,
            'iat' => time()
        ];
        
        // Добавляем стандартные claim'ы в payload
        $payload['iss'] = JWT_ISSUER;
        $payload['aud'] = JWT_AUDIENCE;
        $payload['iat'] = time(); // Время создания
        $payload['exp'] = time() + JWT_EXPIRATION; // Время истечения
        $payload['jti'] = bin2hex(random_bytes(16)); // Уникальный идентификатор токена
        
        // Кодируем header и payload в Base64Url
        $header_encoded = self::base64UrlEncode(json_encode($header));
        $payload_encoded = self::base64UrlEncode(json_encode($payload));
        
        // Создаем подпись
        $data_to_sign = $header_encoded . '.' . $payload_encoded;
        $signature = hash_hmac($supported_algs[$alg], $data_to_sign, $key, true);
        $signature_encoded = self::base64UrlEncode($signature);
        
        // Формируем итоговый токен
        return $header_encoded . '.' . $payload_encoded . '.' . $signature_encoded;
    }
    
    /**
     * Декодирование и верификация JWT токена
     * 
     * @param string $jwt JWT токен
     * @param string $key Секретный ключ
     * @param string $alg Алгоритм подписи
     * @return stdClass Декодированные данные
     * @throws Exception
     */
    public static function decode(string $jwt, string $key = JWT_SECRET, string $alg = JWT_ALGORITHM): stdClass {
        // Разделяем токен на части
        $parts = explode('.', $jwt);
        
        if (count($parts) !== 3) {
            throw new Exception('Неверный формат токена. Ожидается 3 части, получено: ' . count($parts));
        }
        
        list($header_encoded, $payload_encoded, $signature_encoded) = $parts;
        
        // Декодируем header
        $header = json_decode(self::base64UrlDecode($header_encoded));
        if (!$header || !isset($header->alg)) {
            throw new Exception('Неверный заголовок токена');
        }
        
        // Проверяем алгоритм
        if ($header->alg !== $alg) {
            throw new Exception('Алгоритм токена не соответствует ожидаемому. Ожидается: ' . $alg . ', получено: ' . $header->alg);
        }
        
        // Проверяем издателя (issuer)
        if (isset($header->iss) && $header->iss !== JWT_ISSUER) {
            throw new Exception('Неверный издатель токена');
        }
        
        // Проверяем аудиторию (audience)
        if (isset($header->aud) && $header->aud !== JWT_AUDIENCE) {
            throw new Exception('Неверная аудитория токена');
        }
        
        // Проверяем подпись
        $signature = self::base64UrlDecode($signature_encoded);
        $data_to_sign = $header_encoded . '.' . $payload_encoded;
        
        $supported_algs = [
            'HS256' => 'sha256',
            'HS384' => 'sha384',
            'HS512' => 'sha512'
        ];
        
        if (!isset($supported_algs[$header->alg])) {
            throw new Exception('Неподдерживаемый алгоритм подписи: ' . $header->alg);
        }
        
        $expected_signature = hash_hmac($supported_algs[$header->alg], $data_to_sign, $key, true);
        
        if (!hash_equals($signature, $expected_signature)) {
            throw new Exception('Неверная подпись токена');
        }
        
        // Декодируем payload
        $payload = json_decode(self::base64UrlDecode($payload_encoded));
        if (!$payload) {
            throw new Exception('Неверный payload токена');
        }
        
        // Проверяем время истечения (exp)
        if (isset($payload->exp) && $payload->exp < time()) {
            throw new Exception('Токен истек');
        }
        
        // Проверяем время создания (iat) - не в будущем
        if (isset($payload->iat) && $payload->iat > time() + 60) {
            throw new Exception('Токен создан в будущем');
        }
        
        // Проверяем обязательные claim'ы для нашего приложения
        if (!isset($payload->user_id)) {
            throw new Exception('Токен не содержит user_id');
        }
        
        if (!isset($payload->nickname)) {
            throw new Exception('Токен не содержит nickname');
        }
        
        // Проверяем издателя и аудиторию в payload
        if (isset($payload->iss) && $payload->iss !== JWT_ISSUER) {
            throw new Exception('Неверный издатель в payload токена');
        }
        
        if (isset($payload->aud) && $payload->aud !== JWT_AUDIENCE) {
            throw new Exception('Неверная аудитория в payload токена');
        }
        
        return $payload;
    }
    
    /**
     * Проверка валидности токена без выбрасывания исключения
     * 
     * @param string $jwt JWT токен
     * @param string $key Секретный ключ
     * @return bool True если токен валиден
     */
    public static function validate(string $jwt, string $key = JWT_SECRET): bool {
        try {
            self::decode($jwt, $key);
            return true;
        } catch (Exception $e) {
            return false;
        }
    }
    
    /**
     * Обновление JWT токена (если он еще действителен)
     * 
     * @param string $jwt Старый JWT токен
     * @param string $key Секретный ключ
     * @return string|null Новый токен или null если обновление невозможно
     */
    public static function refresh(string $jwt, string $key = JWT_SECRET): ?string {
        try {
            $decoded = self::decode($jwt, $key);
            
            // Проверяем, не истек ли токен полностью
            if (isset($decoded->exp) && $decoded->exp < time()) {
                return null;
            }
            
            // Создаем новый payload на основе старого
            $new_payload = [
                'user_id' => $decoded->user_id,
                'nickname' => $decoded->nickname,
                'email' => $decoded->email ?? null,
                'status_id' => $decoded->status_id ?? null,
                'location_id' => $decoded->location_id ?? null, // ← ИСПРАВЛЕНО: location_id вместо locality_id
                'actor_type_id' => $decoded->actor_type_id ?? 1
            ];
            
            return self::encode($new_payload, $key);
            
        } catch (Exception $e) {
            return null;
        }
    }
    
    /**
     * Извлечение данных из токена без проверки подписи (только для отладки)
     * ВНИМАНИЕ: Не используйте в продакшене для проверки аутентификации!
     * 
     * @param string $jwt JWT токен
     * @return stdClass|null Декодированные данные или null при ошибке
     */
    public static function peek(string $jwt): ?stdClass {
        try {
            $parts = explode('.', $jwt);
            if (count($parts) !== 3) {
                return null;
            }
            
            $payload_encoded = $parts[1];
            $payload = json_decode(self::base64UrlDecode($payload_encoded));
            
            return $payload ?: null;
            
        } catch (Exception $e) {
            return null;
        }
    }
    
    /**
     * Создание токена для конкретного пользователя
     * 
     * @param int $actor_id ID актора
     * @param string $nickname Никнейм пользователя
     * @param string $email Email пользователя
     * @param int $status_id ID статуса пользователя
     * @param int|null $location_id ID населенного пункта из таблицы locations
     * @param int $actor_type_id Тип актора (1=человек, 2=сообщество, 3=организация)
     * @return string JWT токен
     */
    public static function createForUser(
        int $actor_id, 
        string $nickname, 
        string $email, 
        int $status_id = 7, // Участник ТЦ по умолчанию
        ?int $location_id = null, // ← ИСПРАВЛЕНО: location_id вместо locality_id
        int $actor_type_id = 1
    ): string {
        $payload = [
            'user_id' => $actor_id,
            'nickname' => $nickname,
            'email' => $email,
            'status_id' => $status_id,
            'actor_type_id' => $actor_type_id
        ];
        
        if ($location_id) {
            $payload['location_id'] = $location_id; // ← ИСПРАВЛЕНО
        }
        
        return self::encode($payload);
    }
    
    /**
     * Получение данных пользователя из токена
     * 
     * @param string $jwt JWT токен
     * @return array|null Данные пользователя или null при ошибке
     */
    public static function getUserData(string $jwt): ?array {
        try {
            $decoded = self::decode($jwt);
            
            return [
                'actor_id' => $decoded->user_id,
                'nickname' => $decoded->nickname,
                'email' => $decoded->email ?? null,
                'status_id' => $decoded->status_id ?? null,
                'location_id' => $decoded->location_id ?? null, // ← ИСПРАВЛЕНО
                'actor_type_id' => $decoded->actor_type_id ?? 1,
                'expires_at' => $decoded->exp ?? null
            ];
        } catch (Exception $e) {
            return null;
        }
    }
    
    /**
     * Извлечение токена из заголовка Authorization
     * 
     * @return string|null Токен или null если не найден
     */
    public static function getTokenFromHeader(): ?string {
        $headers = getallheaders();
        
        if (isset($headers['Authorization'])) {
            $authHeader = $headers['Authorization'];
            if (preg_match('/Bearer\s+(\S+)/', $authHeader, $matches)) {
                return $matches[1];
            }
        }
        
        // Альтернативный способ получения заголовка
        if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
            $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
            if (preg_match('/Bearer\s+(\S+)/', $authHeader, $matches)) {
                return $matches[1];
            }
        }
        
        return null;
    }
    
    /**
     * Проверка и получение данных пользователя из заголовка
     * 
     * @return array|null Данные пользователя или null если токен невалиден
     */
    public static function getUserFromHeader(): ?array {
        $token = self::getTokenFromHeader();
        if (!$token) {
            return null;
        }
        
        return self::getUserData($token);
    }
    
    /**
     * Проверка авторизации пользователя
     * 
     * @param int $required_status_id Минимальный требуемый ID статуса
     * @return bool True если пользователь авторизован и имеет требуемый статус
     */
    public static function checkAuth(int $required_status_id = 1): bool {
        try {
            $user = self::getUserFromHeader();
            if (!$user) {
                return false;
            }
            
            return ($user['status_id'] >= $required_status_id);
        } catch (Exception $e) {
            return false;
        }
    }
    
    /**
     * Проверка является ли пользователь руководителем ТЦ
     * 
     * @return bool True если пользователь имеет статус Руководитель ТЦ (ID=1)
     */
    public static function isTCLeader(): bool {
        try {
            $user = self::getUserFromHeader();
            return ($user && $user['status_id'] == 1); // ID 1 = Руководитель ТЦ
        } catch (Exception $e) {
            return false;
        }
    }
    
    /**
     * Проверка является ли пользователь участником ТЦ
     * 
     * @return bool True если пользователь имеет статус Участник ТЦ (ID=7) или выше
     */
    public static function isTCMember(): bool {
        try {
            $user = self::getUserFromHeader();
            return ($user && $user['status_id'] >= 7); // ID 7 = Участник ТЦ
        } catch (Exception $e) {
            return false;
        }
    }
    
    /**
     * Кодирование в Base64Url
     * 
     * @param string $data Данные для кодирования
     * @return string Закодированные данные
     */
    private static function base64UrlEncode(string $data): string {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
    
    /**
     * Декодирование из Base64Url
     * 
     * @param string $data Закодированные данные
     * @return string Декодированные данные
     */
    private static function base64UrlDecode(string $data): string {
        return base64_decode(strtr($data, '-_', '+/'));
    }
}

/**
 * Вспомогательная функция для проверки авторизации в API
 * 
 * @param int $required_status_id Минимальный требуемый ID статуса
 * @return int ID пользователя или выбрасывает исключение
 * @throws Exception
 */
function requireAuth(int $required_status_id = 1): int {
    $user = JWT::getUserFromHeader();
    
    if (!$user) {
        throw new Exception('Требуется авторизация', 401);
    }
    
    if ($user['status_id'] < $required_status_id) {
        throw new Exception('Недостаточно прав', 403);
    }
    
    return $user['actor_id'];
}

/**
 * Вспомогательная функция для получения ID текущего пользователя
 * 
 * @return int|null ID пользователя или null если не авторизован
 */
function getCurrentUserId(): ?int {
    $user = JWT::getUserFromHeader();
    return $user ? $user['actor_id'] : null;
}