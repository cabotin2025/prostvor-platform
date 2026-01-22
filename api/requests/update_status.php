<?php
// /api/requests/update_status.php - Изменение статуса запроса

header('Content-Type: application/json');
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../api/helpers/auth_check.php';

// Проверяем авторизацию
$auth = checkAuth();
if (!$auth['authenticated']) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Требуется авторизация']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

// Валидация
if (!isset($input['request_id']) || !isset($input['new_status'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Отсутствуют обязательные поля']);
    exit;
}

try {
    $db = Database::getInstance()->getConnection();
    
    // Проверяем существование запроса и права доступа
    $request = getRequest($db, $input['request_id'], $auth['user_id']);
    if (!$request) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Запрос не найден или нет доступа']);
        exit;
    }
    
    // Проверяем права на изменение статуса
    if (!canChangeStatus($db, $request, $auth['user_id'], $input['new_status'])) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Недостаточно прав для изменения статуса']);
        exit;
    }
    
    // Получаем ID нового статуса
    $newStatusId = getStatusId($db, $input['new_status']);
    if (!$newStatusId) {
        throw new Exception("Неизвестный статус: " . $input['new_status']);
    }
    
    // Обновляем статус запроса
    $oldStatus = $request['request_status_id'];
    
    $query = "UPDATE requests 
              SET request_status_id = :new_status_id, 
                  update_date = NOW(),
                  validity_period = CASE 
                    WHEN :new_status = 'cancelled' AND validity_period IS NULL 
                    THEN NOW() + INTERVAL '1 minute' 
                    ELSE validity_period 
                  END
              WHERE request_id = :request_id 
              RETURNING *";
    
    $stmt = $db->prepare($query);
    $stmt->execute([
        'new_status_id' => $newStatusId,
        'new_status' => $input['new_status'],
        'request_id' => $input['request_id']
    ]);
    
    $updatedRequest = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // Логируем изменение статуса
    logStatusChange($db, $input['request_id'], $oldStatus, $newStatusId, 
                   $auth['user_id'], $input['reason'] ?? '');
    
    echo json_encode([
        'success' => true,
        'message' => 'Статус запроса успешно обновлен',
        'data' => $updatedRequest,
        'old_status' => getStatusName($db, $oldStatus)
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}

// ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

function getRequest($db, $requestId, $userId) {
    $query = "SELECT r.*, 
                     rs.status as status_name,
                     p.project_status_id,
                     e.event_status_id
              FROM requests r
              LEFT JOIN request_statuses rs ON r.request_status_id = rs.request_status_id
              LEFT JOIN projects p ON r.project_id = p.project_id
              LEFT JOIN events e ON r.event_id = e.event_id
              WHERE r.request_id = :request_id 
                AND (r.requester_id = :user_id OR r.owner_id = :user_id 
                     OR EXISTS (SELECT 1 FROM project_actors pa 
                                WHERE pa.project_id = r.project_id 
                                  AND pa.actor_id = :user_id 
                                  AND pa.role_type IN ('leader', 'admin')))";
    
    $stmt = $db->prepare($query);
    $stmt->execute(['request_id' => $requestId, 'user_id' => $userId]);
    
    return $stmt->fetch(PDO::FETCH_ASSOC);
}

function canChangeStatus($db, $request, $userId, $newStatus) {
    // Проверка элементарных прав
    if ($request['requester_id'] == $userId) {
        // Создатель может отменять и приостанавливать свои запросы
        return in_array($newStatus, ['cancelled', 'suspended', 'active']);
    }
    
    // Проверка прав в проекте (если запрос связан с проектом)
    if ($request['project_id']) {
        $query = "SELECT role_type FROM project_actors 
                  WHERE project_id = :project_id AND actor_id = :user_id";
        
        $stmt = $db->prepare($query);
        $stmt->execute(['project_id' => $request['project_id'], 'user_id' => $userId]);
        $role = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($role) {
            $roleHierarchy = ['leader' => 4, 'admin' => 3, 'curator' => 2, 'member' => 1];
            $userLevel = $roleHierarchy[$role['role_type']] ?? 0;
            
            // Руководители и администраторы могут менять статусы
            if ($userLevel >= 3) {
                return true;
            }
        }
    }
    
    return false;
}

function getStatusId($db, $statusName) {
    $statusMap = [
        'active' => 'действующий',
        'suspended' => 'приостановлен',
        'cancelled' => 'отменён',
        'completed' => 'завершён'
    ];
    
    $status = $statusMap[$statusName] ?? $statusName;
    
    $stmt = $db->prepare("SELECT request_status_id FROM request_statuses WHERE status = :status");
    $stmt->execute(['status' => $status]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    return $result ? $result['request_status_id'] : null;
}

function getStatusName($db, $statusId) {
    $stmt = $db->prepare("SELECT status FROM request_statuses WHERE request_status_id = :status_id");
    $stmt->execute(['status_id' => $statusId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    return $result ? $result['status'] : 'Неизвестно';
}

function logStatusChange($db, $requestId, $oldStatusId, $newStatusId, $userId, $reason) {
    $query = "INSERT INTO request_status_log 
              (request_id, old_status_id, new_status_id, changed_by, reason, change_date) 
              VALUES (:request_id, :old_status, :new_status, :user_id, :reason, NOW())";
    
    $stmt = $db->prepare($query);
    $stmt->execute([
        'request_id' => $requestId,
        'old_status' => $oldStatusId,
        'new_status' => $newStatusId,
        'user_id' => $userId,
        'reason' => $reason
    ]);
}
?>