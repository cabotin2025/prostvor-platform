<?php
// api/projects/index.php - получение списка проектов
require_once __DIR__ . '/../../middleware/auth.php';

// Проверяем авторизацию
$user = requireAuth();

try {
    // Получаем проекты
    $projects = \Prostvor\Database::fetchAll("
        SELECT 
            p.project_id,
            p.title,
            p.full_title,
            p.description,
            p.start_date,
            p.end_date,
            p.keywords,
            p.created_at,
            ps.status as project_status,
            pt.type as project_type,
            a.actor_id as author_id,
            a.nickname as author_name
        FROM projects p
        LEFT JOIN project_statuses ps ON p.project_status_id = ps.project_status_id
        LEFT JOIN project_types pt ON p.project_type_id = pt.project_type_id
        LEFT JOIN actors a ON p.author_id = a.actor_id
        WHERE p.deleted_at IS NULL
        ORDER BY p.created_at DESC
        LIMIT 50
    ");
    
    echo json_encode([
        'success' => true,
        'count' => count($projects),
        'projects' => $projects
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Failed to fetch projects',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}