<?php
require_once '../../config/database.php';
require_once '../../config/cors.php';
require_once '../../config/jwt.php'; // Подключаем JWT

header('Content-Type: application/json');

class ProjectsAPI {
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
                    $this->getProjects();
                    break;
                case 'POST':
                    $this->createProject();
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
    
    private function getProjects() {
        // Добавляем информацию о роли текущего пользователя в проектах
        $user_id = $this->getUserIdFromToken();
        
        $stmt = $this->pdo->prepare("
            SELECT 
                p.*, 
                ps.status as project_status, 
                pt.type as project_type,
                par.role_type as user_role,
                CASE 
                    WHEN par.role_type = 'leader' THEN 'Руководитель проекта'
                    WHEN par.role_type = 'admin' THEN 'Администратор проекта'
                    WHEN par.role_type = 'member' THEN 'Участник проекта'
                    WHEN par.role_type = 'curator' THEN 'Проектный куратор'
                    ELSE 'Не участвует'
                END as user_role_name
            FROM projects p
            LEFT JOIN project_statuses ps ON p.project_status_id = ps.project_status_id
            LEFT JOIN project_types pt ON p.project_type_id = pt.project_type_id
            LEFT JOIN project_actor_roles par ON p.project_id = par.project_id AND par.actor_id = ?
            WHERE p.deleted_at IS NULL
            ORDER BY p.created_at DESC
        ");
        $stmt->execute([$user_id]);
        $projects = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode(['success' => true, 'projects' => $projects]);
    }
    
    private function createProject() {
        $data = json_decode(file_get_contents('php://input'), true);
        
        // Валидация
        $required = ['title', 'description'];
        foreach($required as $field) {
            if(empty($data[$field])) {
                throw new Exception("Missing required field: $field");
            }
        }
        
        // Получаем ID пользователя из токена
        $user_id = getCurrentUserId();
        if (!$user_id) {
            http_response_code(401);
            echo json_encode(['success' => false, 'message' => 'Требуется авторизация']);
            exit;
        }

        // Или с проверкой минимального статуса
        try {
            $user_id = requireAuth(7); // Требуется статус "Участник ТЦ" (ID=7) или выше
        } catch (Exception $e) {
            http_response_code($e->getCode());
            echo json_encode(['success' => false, 'message' => $e->getMessage()]);
            exit;
        }
                
        // Начинаем транзакцию
        $this->pdo->beginTransaction();
        
        try {
            // Создаем проект
            $stmt = $this->pdo->prepare("
                INSERT INTO projects 
                (title, description, author_id, project_status_id, created_by, updated_by) 
                VALUES (?, ?, ?, 1, ?, ?)
            ");
            
            $stmt->execute([
                $data['title'],
                $data['description'],
                $user_id,
                $user_id,
                $user_id
            ]);
            
            $project_id = $this->pdo->lastInsertId();
            
            // Автоматически назначаем создателя руководителем проекта
            $stmt = $this->pdo->prepare("
                INSERT INTO project_actor_roles (actor_id, project_id, role_type, assigned_by) 
                VALUES (?, ?, 'leader', ?)
            ");
            $stmt->execute([$user_id, $project_id, $user_id]);
            
            // Коммитим транзакцию
            $this->pdo->commit();
            
            echo json_encode([
                'success' => true, 
                'message' => 'Project created successfully',
                'project_id' => $project_id,
                'role_assigned' => 'leader'
            ]);
            
        } catch(Exception $e) {
            $this->pdo->rollBack();
            throw $e;
        }
    }
    
    private function getUserIdFromToken() {
        // Реализация из config/jwt.php
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

$api = new ProjectsAPI();
$api->handleRequest();