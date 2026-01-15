<?php
// api/favorites/toggle.php
require_once __DIR__ . '/../helpers/auth_check.php';
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Метод не разрешен']);
    exit;
}

try {
    $actor_id = getAuthenticatedActorId();
    $input = json_decode(file_get_contents('php://input'), true);
    
    validateRequiredFields($input, ['entity_type', 'entity_id']);
    
    $entity_type = $input['entity_type'];
    $entity_id = (int)$input['entity_id'];
    
    // Проверяем существование записи
    $check_sql = "SELECT favorite_id FROM favorites WHERE actor_id = ? AND entity_type = ? AND entity_id = ?";
    $check_stmt = $pdo->prepare($check_sql);
    $check_stmt->execute([$actor_id, $entity_type, $entity_id]);
    
    if ($check_stmt->rowCount() > 0) {
        // Удаляем из избранного
        $delete_sql = "DELETE FROM favorites WHERE actor_id = ? AND entity_type = ? AND entity_id = ?";
        $delete_stmt = $pdo->prepare($delete_sql);
        $delete_stmt->execute([$actor_id, $entity_type, $entity_id]);
        
        echo json_encode([
            'success' => true,
            'action' => 'removed',
            'message' => 'Удалено из избранного',
            'is_favorite' => false
        ]);
    } else {
        // Добавляем в избранное
        $insert_sql = "INSERT INTO favorites (actor_id, entity_type, entity_id, created_at) VALUES (?, ?, ?, NOW())";
        $insert_stmt = $pdo->prepare($insert_sql);
        $insert_stmt->execute([$actor_id, $entity_type, $entity_id]);
        
        echo json_encode([
            'success' => true,
            'action' => 'added',
            'message' => 'Добавлено в избранное',
            'is_favorite' => true,
            'favorite_id' => $pdo->lastInsertId()
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка сервера: ' . $e->getMessage()
    ]);
}
?>