<?php
require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php';

header('Content-Type: application/json');

class ProjectPermissionsAPI {
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
                    $this->checkPermissions();
                    break;
                case 'POST':
                    $this->inviteToProject();
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
    
    private function checkPermissions() {
        $project_id = $_GET['project_id'] ?? null;
        
        if (!$project_id) {
            throw new Exception('Project ID is required');
        }
        
        $actor_id = $this->getUserIdFromToken();
        
        // Получаем глобальный статус пользователя
        $global_status = $this->getGlobalStatus($actor_id);
        
        // Получаем роль пользователя в проекте
        $project_role = $this->getProjectRole($actor_id, $project_id);
        
        // Проверяем существование проекта
        $stmt = $this->pdo->prepare("
            SELECT project_id, title FROM projects 
            WHERE project_id = ? AND deleted_at IS NULL
        ");
        $stmt->execute([$project_id]);
        $project = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$project) {
            throw new Exception('Project not found');
        }
        
        // Определяем уровень доступа
        $has_access = false;
        $access_level = 'none';
        $access_reason = '';
        
        // Логика согласно ТЗ
        if ($global_status === 'Гость') {
            $has_access = false;
            $access_level = 'guest';
            $access_reason = 'Гости не имеют доступа к страницам проектов';
        } 
        elseif ($project_role) {
            $has_access = true;
            $access_level = $project_role['role_type'];
            $access_reason = "Имеет роль: {$project_role['role_type']}";
        }
        elseif ($global_status === 'Участник ТЦ') {
            $has_access = false;
            $access_level = 'tc_member';
            $access_reason = 'Участник ТЦ не является участником этого проекта';
        }
        elseif (in_array($global_status, ['Руководитель ТЦ', 'Куратор направления'])) {
            // Проверяем, относится ли проект к локации пользователя
            $stmt = $this->pdo->prepare("
                SELECT 1 FROM projects p
                JOIN actors_locations al ON p.author_id = al.actor_id
                WHERE p.project_id = ? AND al.location_id IN (
                    SELECT location_id FROM actors_locations WHERE actor_id = ?
                )
            ");
            $stmt->execute([$project_id, $actor_id]);
            
            if ($stmt->fetch()) {
                $has_access = true;
                $access_level = $global_status === 'Руководитель ТЦ' ? 'tc_leader' : 'direction_curator';
                $access_reason = "{$global_status} имеет доступ к проектам в своей локации";
            } else {
                $has_access = false;
                $access_reason = "{$global_status} не имеет доступа к проектам вне своей локации";
            }
        }
        
        echo json_encode([
            'success' => true,
            'has_access' => $has_access,
            'access_level' => $access_level,
            'global_status' => $global_status,
            'project_role' => $project_role,
            'access_reason' => $access_reason,
            'project' => $project
        ]);
    }
    
    private function inviteToProject() {
        $data = json_decode(file_get_contents('php://input'), true);
        
        $required = ['project_id', 'actor_id', 'role_type'];
        foreach($required as $field) {
            if(empty($data[$field])) {
                throw new Exception("Missing required field: $field");
            }
        }
        
        $current_user_id = $this->getUserIdFromToken();
        $project_id = $data['project_id'];
        $target_actor_id = $data['actor_id'];
        $role_type = $data['role_type'];
        
        // Проверяем права текущего пользователя
        $current_user_role = $this->getProjectRole($current_user_id, $project_id);
        
        if (!$current_user_role || !in_array($current_user_role['role_type'], ['leader', 'admin'])) {
            throw new Exception('Only project leaders and admins can invite users');
        }
        
        // Приглашаем пользователя в проект
        $stmt = $this->pdo->prepare("
            INSERT INTO project_actor_roles (actor_id, project_id, role_type, assigned_by) 
            VALUES (?, ?, ?, ?)
            ON CONFLICT (actor_id, project_id) DO UPDATE 
            SET role_type = EXCLUDED.role_type,
                assigned_at = CURRENT_TIMESTAMP,
                assigned_by = EXCLUDED.assigned_by
        ");
        
        $stmt->execute([$target_actor_id, $project_id, $role_type, $current_user_id]);
        
        echo json_encode([
            'success' => true,
            'message' => 'User invited to project successfully'
        ]);
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
        
        $decoded = JWT::decode($token, JWT_SECRET, ['HS256']);
        return $decoded->user_id;
    }
    
    private function getGlobalStatus($actor_id) {
        $stmt = $this->pdo->prepare("
            SELECT s.status 
            FROM actor_current_statuses acs
            JOIN actor_statuses s ON acs.actor_status_id = s.actor_status_id
            WHERE acs.actor_id = ?
        ");
        $stmt->execute([$actor_id]);
        
        $status = $stmt->fetch(PDO::FETCH_COLUMN);
        return $status ?: 'Гость';
    }
    
    private function getProjectRole($actor_id, $project_id) {
        $stmt = $this->pdo->prepare("
            SELECT role_type, assigned_at 
            FROM project_actor_roles 
            WHERE actor_id = ? AND project_id = ?
        ");
        $stmt->execute([$actor_id, $project_id]);
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
}

$api = new ProjectPermissionsAPI();
$api->handleRequest();