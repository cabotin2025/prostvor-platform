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

$actorId = $auth['user']['actor_id'];

try {
    $db = new Database();
    
    $sql = "SELECT b.*, t.title as theme_title, t.description as theme_description,
                   d.content as last_discussion_content
            FROM theme_bookmarks b
            JOIN themes t ON b.theme_id = t.theme_id
            LEFT JOIN theme_discussions d ON b.last_read_discussion_id = d.discussion_id
            WHERE b.actor_id = ?
            ORDER BY b.updated_at DESC";
    
    $stmt = $db->query($sql, [$actorId]);
    $bookmarks = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'bookmarks' => $bookmarks]);
    
} catch (Exception $e) {
    echo json_encode(['error' => $e->getMessage()]);
}
?>