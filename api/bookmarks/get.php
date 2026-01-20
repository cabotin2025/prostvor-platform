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

$themeId = $_GET['theme_id'] ?? null;
$actorId = $auth['user']['actor_id'];

if (!$themeId) {
    echo json_encode(['error' => 'Не указан theme_id']);
    exit;
}

try {
    $db = new Database();
    
    $sql = "SELECT b.*, d.content as last_discussion_content
            FROM theme_bookmarks b
            LEFT JOIN theme_discussions d ON b.last_read_discussion_id = d.discussion_id
            WHERE b.theme_id = ? AND b.actor_id = ?";
    
    $stmt = $db->query($sql, [$themeId, $actorId]);
    $bookmark = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($bookmark) {
        echo json_encode(['success' => true, 'bookmark' => $bookmark]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Закладка не найдена']);
    }
    
} catch (Exception $e) {
    echo json_encode(['error' => $e->getMessage()]);
}
?>