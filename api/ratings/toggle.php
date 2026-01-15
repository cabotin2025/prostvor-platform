<?php
// api/ratings/toggle.php
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
    $rating_type = $input['rating_type'] ?? 'положительно';
    
    // Получаем ID типа оценки
    $type_sql = "SELECT rating_type_id FROM rating_types WHERE type = ?";
    $type_stmt = $pdo->prepare($type_sql);
    $type_stmt->execute([$rating_type]);
    $rating_type_id = $type_stmt->fetchColumn();
    
    if (!$rating_type_id) {
        throw new Exception('Неверный тип оценки');
    }
    
    // Определяем таблицу и поле для данной сущности
    $entity_config = [
        'projects' => ['table' => 'projects', 'id_field' => 'project_id'],
        'ideas' => ['table' => 'ideas', 'id_field' => 'idea_id'],
        'actors' => ['table' => 'actors', 'id_field' => 'actor_id'],
        'matresources' => ['table' => 'matresources', 'id_field' => 'matresource_id'],
        'finresources' => ['table' => 'finresources', 'id_field' => 'finresource_id'],
        'venues' => ['table' => 'venues', 'id_field' => 'venue_id'],
        'services' => ['table' => 'services', 'id_field' => 'service_id'],
        'themes' => ['table' => 'themes', 'id_field' => 'theme_id'],
        'events' => ['table' => 'events', 'id_field' => 'event_id']
    ];
    
    if (!isset($entity_config[$entity_type])) {
        throw new Exception('Неверный тип сущности');
    }
    
    $config = $entity_config[$entity_type];
    
    // Проверяем существующую оценку
    $check_sql = "
        SELECT r.rating_id 
        FROM ratings r
        INNER JOIN {$config['table']} e ON e.rating_id = r.rating_id
        WHERE r.actor_id = ? AND e.{$config['id_field']} = ?
    ";
    
    $check_stmt = $pdo->prepare($check_sql);
    $check_stmt->execute([$actor_id, $entity_id]);
    
    if ($check_stmt->rowCount() > 0) {
        // Удаляем оценку
        $rating = $check_stmt->fetch(PDO::FETCH_ASSOC);
        
        $delete_sql = "DELETE FROM ratings WHERE rating_id = ?";
        $delete_stmt = $pdo->prepare($delete_sql);
        $delete_stmt->execute([$rating['rating_id']]);
        
        $update_sql = "UPDATE {$config['table']} SET rating_id = NULL WHERE {$config['id_field']} = ?";
        $update_stmt = $pdo->prepare($update_sql);
        $update_stmt->execute([$entity_id]);
        
        echo json_encode([
            'success' => true,
            'action' => 'removed',
            'message' => 'Оценка удалена',
            'has_rating' => false
        ]);
    } else {
        // Создаем новую оценку
        $insert_sql = "INSERT INTO ratings (actor_id, rating_type_id, created_at) VALUES (?, ?, NOW())";
        $insert_stmt = $pdo->prepare($insert_sql);
        $insert_stmt->execute([$actor_id, $rating_type_id]);
        
        $new_rating_id = $pdo->lastInsertId();
        
        // Привязываем оценку к сущности
        $update_sql = "UPDATE {$config['table']} SET rating_id = ? WHERE {$config['id_field']} = ?";
        $update_stmt = $pdo->prepare($update_sql);
        $update_stmt->execute([$new_rating_id, $entity_id]);
        
        echo json_encode([
            'success' => true,
            'action' => 'added',
            'message' => 'Оценка добавлена',
            'has_rating' => true,
            'rating_id' => $new_rating_id
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка: ' . $e->getMessage()
    ]);
}
?>