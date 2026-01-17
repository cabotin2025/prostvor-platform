<?php
// api/actors/index.php - ИСПРАВЛЕННАЯ ВЕРСИЯ

// ОЧИСТКА БУФЕРА
while (ob_get_level()) ob_end_clean();

// ЗАГОЛОВКИ ПЕРВЫМИ
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

require_once '../../config/database.php';
require_once '../../config/cors.php';
// require_once '../../middleware/auth.php'; // ЗАКОММЕНТИРОВАТЬ или создать файл

try {
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        // Простой запрос для теста
        $limit = $_GET['limit'] ?? 10;
        $offset = $_GET['offset'] ?? 0;
        
        $stmt = $pdo->prepare("
            SELECT 
                a.actor_id as id,
                a.nickname,
                a.account,
                at.type as actor_type,
                acs.actor_status_id,
                ast.status as actor_status,
                a.created_at
            FROM actors a
            LEFT JOIN actor_types at ON a.actor_type_id = at.actor_type_id
            LEFT JOIN actor_current_statuses acs ON a.actor_id = acs.actor_id
            LEFT JOIN actor_statuses ast ON acs.actor_status_id = ast.actor_status_id
            WHERE a.deleted_at IS NULL
            ORDER BY a.created_at DESC
            LIMIT :limit OFFSET :offset
        ");
        
        $stmt->bindValue(':limit', (int)$limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', (int)$offset, PDO::PARAM_INT);
        $stmt->execute();
        
        $actors = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Получаем общее количество
        $countStmt = $pdo->query("SELECT COUNT(*) FROM actors WHERE deleted_at IS NULL");
        $total = $countStmt->fetchColumn();
        
        echo json_encode([
            'success' => true,
            'data' => $actors,
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset
        ], JSON_UNESCAPED_UNICODE);
        
    } else {
        http_response_code(405);
        echo json_encode([
            'success' => false,
            'message' => 'Method not allowed'
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}