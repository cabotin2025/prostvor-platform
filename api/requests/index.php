<?php
// /api/requests/index.php - Основной API для работы с запросами

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

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

try {
    $db = Database::getInstance()->getConnection();
    
    switch ($method) {
        case 'GET':
            handleGetRequest($db, $auth['user_id']);
            break;
            
        case 'POST':
            handlePostRequest($db, $input, $auth['user_id']);
            break;
            
        default:
            http_response_code(405);
            echo json_encode(['success' => false, 'message' => 'Метод не поддерживается']);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}

// ==================== ОБРАБОТЧИКИ ====================

/**
 * Обработка GET запросов (получение списка/одного запроса)
 */
function handleGetRequest($db, $userId) {
    $requestId = $_GET['request_id'] ?? null;
    $projectId = $_GET['project_id'] ?? null;
    $eventId = $_GET['event_id'] ?? null;
    $status = $_GET['status'] ?? null;
    
    if ($requestId) {
        // Получение одного запроса
        $query = "SELECT r.*, 
                         rs.status as status_name,
                         rt.type as resource_type_name,
                         l.name as location_name,
                         a1.nickname as requester_name,
                         a2.nickname as owner_name
                  FROM requests r
                  LEFT JOIN request_statuses rs ON r.request_status_id = rs.request_status_id
                  LEFT JOIN resource_types rt ON r.request_type_id = rt.resource_type_id
                  LEFT JOIN locations l ON r.location_id = l.location_id
                  LEFT JOIN actors a1 ON r.requester_id = a1.actor_id
                  LEFT JOIN actors a2 ON r.owner_id = a2.actor_id
                  WHERE r.request_id = :request_id";
        
        $stmt = $db->prepare($query);
        $stmt->execute(['request_id' => $requestId]);
        $request = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($request) {
            echo json_encode(['success' => true, 'data' => $request]);
        } else {
            echo json_encode(['success' => false, 'message' => 'Запрос не найден']);
        }
    } else {
        // Получение списка запросов с фильтрами
        $query = "SELECT r.*, rs.status as status_name 
                  FROM requests r
                  LEFT JOIN request_statuses rs ON r.request_status_id = rs.request_status_id
                  WHERE 1=1";
        
        $params = [];
        
        // Фильтр по проекту
        if ($projectId) {
            $query .= " AND r.project_id = :project_id";
            $params['project_id'] = $projectId;
        }
        
        // Фильтр по событию
        if ($eventId) {
            $query .= " AND r.event_id = :event_id";
            $params['event_id'] = $eventId;
        }
        
        // Фильтр по статусу
        if ($status) {
            $query .= " AND rs.status = :status";
            $params['status'] = $status;
        }
        
        // Показываем только запросы пользователя (кроме администраторов)
        if (!isAdmin($userId)) {
            $query .= " AND (r.requester_id = :user_id OR r.owner_id = :user_id)";
            $params['user_id'] = $userId;
        }
        
        $query .= " ORDER BY r.creation_date DESC";
        
        $stmt = $db->prepare($query);
        $stmt->execute($params);
        $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode(['success' => true, 'data' => $requests]);
    }
}

/**
 * Обработка POST запросов (создание запроса)
 */
function handlePostRequest($db, $data, $userId) {
    // Валидация обязательных полей
    $required = ['resource_type', 'resource_id', 'owner_id'];
    foreach ($required as $field) {
        if (!isset($data[$field]) || empty($data[$field])) {
            throw new Exception("Отсутствует обязательное поле: $field");
        }
    }
    
    // Определяем request_type_id из resource_type
    $resourceTypeMap = [
        'venue' => 1, // Локация
        'matresource' => 2, // Материальный ресурс
        'finresource' => 3, // Финансовый ресурс
        'service' => 4, // Услуга
        'idea' => 5, // Идея
        'function' => 6  // Функция
    ];
    
    $requestTypeId = $resourceTypeMap[$data['resource_type']] ?? null;
    if (!$requestTypeId) {
        throw new Exception("Неизвестный тип ресурса: " . $data['resource_type']);
    }
    
    // Определяем location_id (из пользователя или данных)
    $locationId = $data['location_id'] ?? getUserLocationId($db, $userId);
    
    // Проверяем, совпадает ли локация с владельцем ресурса
    $ownerLocationId = getResourceOwnerLocation($db, $data['resource_type'], $data['resource_id']);
    $locationNotification = null;
    
    if ($ownerLocationId && $locationId && $ownerLocationId != $locationId) {
        $locationNotification = [
            'show' => true,
            'requester_location' => getLocationName($db, $locationId),
            'owner_location' => getLocationName($db, $ownerLocationId)
        ];
    }
    
    // Получаем ID статуса "действующий"
    $stmt = $db->prepare("SELECT request_status_id FROM request_statuses WHERE status = 'действующий'");
    $stmt->execute();
    $status = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // Подготавливаем данные для вставки
    $requestData = [
        'requester_id' => $userId,
        'owner_id' => $data['owner_id'],
        'resource_type' => $data['resource_type'],
        'resource_id' => $data['resource_id'],
        'request_type_id' => $requestTypeId,
        'request_status_id' => $status['request_status_id'],
        'location_id' => $locationId,
        'title' => $data['title'] ?? '',
        'description' => $data['description'] ?? '',
        'quantity' => $data['quantity'] ?? 1,
        'validity_period' => isset($data['validity_period']) ? $data['validity_period'] : null,
        'project_id' => $data['project_id'] ?? null,
        'event_id' => $data['event_id'] ?? null
    ];
    
    // Вставляем запрос (используем функцию БД или прямой INSERT)
    $columns = implode(', ', array_keys($requestData));
    $placeholders = ':' . implode(', :', array_keys($requestData));
    
    $query = "INSERT INTO requests ($columns, creation_date, update_date) 
              VALUES ($placeholders, NOW(), NOW()) 
              RETURNING request_id, creation_date";
    
    $stmt = $db->prepare($query);
    $stmt->execute($requestData);
    
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    $requestId = $result['request_id'];
    
    // Если нужно, создаем уведомление о разных локациях
    if ($locationNotification && $locationNotification['show']) {
        createLocationNotification($db, $userId, $locationNotification);
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Запрос успешно создан',
        'data' => array_merge($requestData, ['request_id' => $requestId]),
        'notification' => $locationNotification
    ]);
}

// ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

function isAdmin($userId) {
    // Проверка, является ли пользователь администратором
    // Реализуйте согласно вашей логике прав
    return false;
}

function getUserLocationId($db, $userId) {
    $stmt = $db->prepare("
        SELECT al.location_id 
        FROM actors_locations al 
        WHERE al.actor_id = :user_id 
        LIMIT 1
    ");
    $stmt->execute(['user_id' => $userId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    return $result ? $result['location_id'] : null;
}

function getResourceOwnerLocation($db, $resourceType, $resourceId) {
    $tables = [
        'venue' => ['venues', 'owner_id', 'venue_id'],
        'matresource' => ['matresources', 'owner_id', 'matresource_id'],
        'finresource' => ['finresources', 'owner_id', 'finresource_id'],
        'service' => ['services', 'owner_id', 'service_id'],
        'idea' => ['ideas', 'author_id', 'idea_id'],
        'function' => ['actors_functions', 'actor_id', 'function_id']
    ];
    
    if (!isset($tables[$resourceType])) {
        return null;
    }
    
    list($table, $ownerColumn, $idColumn) = $tables[$resourceType];
    
    // Для functions связь сложнее - пропускаем для простоты
    if ($resourceType === 'function') {
        return null;
    }
    
    $query = "SELECT al.location_id 
              FROM $table r 
              JOIN actors_locations al ON r.$ownerColumn = al.actor_id 
              WHERE r.$idColumn = :resource_id 
              LIMIT 1";
    
    $stmt = $db->prepare($query);
    $stmt->execute(['resource_id' => $resourceId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    return $result ? $result['location_id'] : null;
}

function getLocationName($db, $locationId) {
    $stmt = $db->prepare("SELECT name FROM locations WHERE location_id = :location_id");
    $stmt->execute(['location_id' => $locationId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    return $result ? $result['name'] : 'Неизвестно';
}

function createLocationNotification($db, $userId, $notification) {
    $query = "INSERT INTO notifications 
              (actor_id, title, message, notification_type, is_read, creation_date) 
              VALUES (:user_id, :title, :message, 'warning', false, NOW())";
    
    $stmt = $db->prepare($query);
    $stmt->execute([
        'user_id' => $userId,
        'title' => 'Внимание: разные локации',
        'message' => "Владелец находится в другом населенном пункте ({$notification['owner_location']})"
    ]);
}
?>