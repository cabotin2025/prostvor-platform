<?php
require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php';

header('Content-Type: application/json');

class StatusesAPI {
    private $pdo;
    
    public function __construct() {
        global $pdo;
        $this->pdo = $pdo;
    }
    
    public function handleRequest() {
        $method = $_SERVER['REQUEST_METHOD'];
        
        try {
            switch($method) {
                case 'GET':
                    $this->getStatuses();
                    break;
                case 'POST':
                    $this->setUserStatus();
                    break;
                case 'PUT':
                    $this->updateProjectStatus();
                    break;
                default:
                    http_response_code(405);
                    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
            }
        } catch(Exception $e) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => $e->getMessage()]);
        }
    }
    
    private function getStatuses() {
        // Получить все глобальные статусы
        $stmt = $this->pdo->query("SELECT * FROM actor_statuses ORDER BY actor_status_id");
        $statuses = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Получить статус текущего пользователя, если авторизован
        try {
            $user_id = $this->getUserIdFromToken();
            $stmt = $this->pdo->prepare("
                SELECT s.* 
                FROM actor_current_statuses acs
                JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
                WHERE acs.actor_id = ?
            ");
            $stmt->execute([$user_id]);
            $current_status = $stmt->fetch(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true, 
                'statuses' => $statuses,
                'current_status' => $current_status
            ]);
        } catch(Exception $e) {
            echo json_encode(['success' => true, 'statuses' => $statuses]);
        }
    }
    
    private function setUserStatus() {
        $data = json_decode(file_get_contents('php://input'), true);
        
        if(empty($data['actor_id']) || empty($data['status_id'])) {
            throw new Exception('Actor ID and Status ID are required');
        }
        
        $current_user_id = $this->getUserIdFromToken();
        
        // Проверяем права: только Руководитель ТЦ или выше может менять статусы
        $stmt = $this->pdo->prepare("
            SELECT 1 FROM actor_current_statuses acs
            JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
            WHERE acs.actor_id = ? AND s.status IN ('Руководитель ТЦ', 'Куратор направления')
        ");
        $stmt->execute([$current_user_id]);
        
        if(!$stmt->fetch()) {
            // Проверяем, может ли пользователь менять свой собственный статус на "Участник ТЦ"
            if($current_user_id == $data['actor_id'] && $data['status_id'] == 7) {
                // Разрешаем установить себе статус "Участник ТЦ"
            } else {
                throw new Exception('Insufficient permissions to change user status');
            }
        }
        
        // Устанавливаем новый статус
        $stmt = $this->pdo->prepare("
            INSERT INTO actor_current_statuses (actor_id, actor_status_id, created_by) 
            VALUES (?, ?, ?)
            ON CONFLICT (actor_id) DO UPDATE 
            SET actor_status_id = EXCLUDED.actor_status_id,
                updated_at = CURRENT_TIMESTAMP,
                updated_by = EXCLUDED.created_by
        ");
        $stmt->execute([$data['actor_id'], $data['status_id'], $current_user_id]);
        
        echo json_encode(['success' => true, 'message' => 'User status updated']);
    }
    
    private function updateProjectStatus() {
        $data = json_decode(file_get_contents('php://input'), true);
        
        if(empty($data['project_id']) || empty($data['status_id'])) {
            throw new Exception('Project ID and Status ID are required');
        }
        
        $user_id = $this->getUserIdFromToken();
        
        // Проверяем права на изменение статуса проекта
        // Могут: Руководитель проекта, Куратор направления, Руководитель ТЦ
        $stmt = $this->pdo->prepare("
            SELECT 1 FROM project_actor_roles par
            WHERE par.project_id = ? AND par.actor_id = ? AND par.role_type IN ('leader', 'curator')
            UNION
            SELECT 1 FROM actor_current_statuses acs
            JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
            WHERE acs.actor_id = ? AND s.status IN ('Руководитель ТЦ', 'Куратор направления')
        ");
        $stmt->execute([$data['project_id'], $user_id, $user_id]);
        
        if(!$stmt->fetch()) {
            throw new Exception('Insufficient permissions to change project status');
        }
        
        // Обновляем статус проекта
        $stmt = $this->pdo->prepare("
            UPDATE projects SET project_status_id = ?, updated_by = ? 
            WHERE project_id = ?
        ");
        $stmt->execute([$data['status_id'], $user_id, $data['project_id']]);
        
        echo json_encode(['success' => true, 'message' => 'Project status updated']);
    }
    
    private function getUserIdFromToken() {
        $headers = getallheaders();
        $token = null;
        
        if (isset($headers['Authorization'])) {
            $authHeader = $headers['Authorization'];
            if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
                $token = $matches[1];
            }
        }
        
        if (!$token) {
            throw new Exception('Authorization token not found');
        }
        
        try {
            $decoded = JWT::decode($token, JWT_SECRET, ['HS256']);
            return $decoded->user_id;
        } catch (Exception $e) {
            throw new Exception('Invalid token: ' . $e->getMessage());
        }
    }
}

$api = new StatusesAPI();
$api->handleRequest();