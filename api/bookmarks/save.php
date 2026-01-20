<?php
require_once '../config/database.php';
require_once '../lib/Database.php';
require_once '../helpers/auth_check.php';

header('Content-Type: application/json');

$auth = checkAuth();
if (!$auth['authenticated']) {
    echo json_encode(['error' => 'Не авторизован']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);
$themeId = $data['theme_id'] ?? null;
$discussionId = $data['discussion_id'] ?? null; // ID последнего прочитанного комментария
$actorId = $auth['user']['actor_id'];

if (!$themeId) {
    echo json_encode(['error' => 'Не указан theme_id']);
    exit;
}

try {
    $db = new Database();
    
    // Используем UPSERT (INSERT ... ON CONFLICT ... UPDATE)
    $sql = "INSERT INTO theme_bookmarks (theme_id, actor_id, last_read_discussion_id, updated_at) 
            VALUES (?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT (theme_id, actor_id) 
            DO UPDATE SET 
                last_read_discussion_id = EXCLUDED.last_read_discussion_id,
                updated_at = CURRENT_TIMESTAMP
            RETURNING bookmark_id";
    
    $stmt = $db->query($sql, [$themeId, $actorId, $discussionId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true, 
        'bookmark_id' => $result['bookmark_id'],
        'message' => 'Закладка сохранена'
    ]);
    
} catch (Exception $e) {
    echo json_encode(['error' => $e->getMessage()]);
}
?>