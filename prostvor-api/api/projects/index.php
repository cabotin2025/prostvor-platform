<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
require_once '../../includes/Database.php';

$db = Database::getConnection();

try {
    // Используем представление из creative_center.sql
    $stmt = $db->query("SELECT * FROM vw_active_projects_summary ORDER BY start_date DESC");
    $projects = $stmt->fetchAll();
    
    echo json_encode([
        'success' => true,
        'count' => count($projects),
        'projects' => $projects
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Ошибка сервера: ' . $e->getMessage()]);
}
?>