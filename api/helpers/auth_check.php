<?php
// api/helpers/auth_check.php
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/jwt.php';

function getAuthenticatedActorId() {
    $actor_id = verifyJWT();
    
    if (!$actor_id) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Требуется авторизация'
        ]);
        exit;
    }
    
    return $actor_id;
}

function validateRequiredFields($data, $requiredFields) {
    foreach ($requiredFields as $field) {
        if (!isset($data[$field]) || empty($data[$field])) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'message' => "Отсутствует обязательное поле: $field"
            ]);
            exit;
        }
    }
}
?>