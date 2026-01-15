<?php
// api/ratings/count.php
header('Content-Type: application/json');

if (!isset($_GET['entity_type']) || !isset($_GET['entity_id'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Не указаны параметры']);
    exit;
}

$entity_type = $_GET['entity_type'];
$entity_id = (int)$_GET['entity_id'];

try {
    require_once __DIR__ . '/../config/database.php';
    
    $entity_config = [
        'projects' => ['table' => 'projects', 'id_field' => 'project_id'],
        'ideas' => ['table' => 'ideas', 'id_field' => 'idea_id'],
        // ... остальные типы сущностей
    ];
    
    if (!isset($entity_config[$entity_type])) {
        throw new Exception('Неверный тип сущности');
    }
    
    $config = $entity_config[$entity_type];
    
    $sql = "
        SELECT COUNT(*) as count 
        FROM ratings r
        INNER JOIN {$config['table']} e ON e.rating_id = r.rating_id
        WHERE e.{$config['id_field']} = ?
    ";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$entity_id]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'count' => (int)$result['count'],
        'entity_type' => $entity_type,
        'entity_id' => $entity_id
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка получения счетчика'
    ]);
}
?>