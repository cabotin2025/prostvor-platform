/**
 * Система управления правами доступа для платформы
 * Реализует проверку статусов согласно ТЗ
 */

class AuthPermissions {
    constructor() {
        this.currentUser = {
            actor_id: null,
            username: null,
            global_status: 'Гость',
            locality_id: null,
            project_roles: {},
            directions: []
        };
        
        this.statusHierarchy = {
            'Гость': 0,
            'Участник ТЦ': 7,           // ID 7 из БД
            'Участник проекта': 6,      // ID 6 из БД
            'Администратор проекта': 5, // ID 5 из БД
            'Руководитель проекта': 4,  // ID 4 из БД
            'Проектный куратор': 3,     // ID 3 из БД
            'Куратор направления': 2,   // ID 2 из БД
            'Руководитель ТЦ': 1        // ID 1 из БД (самый высокий)
        };

        // Иерархия ролей в проектах (соответствует role_type в project_actor_role)
        this.roleHierarchy = {
            'leader': 4,    // Руководитель проекта
            'admin': 3,     // Администратор проекта
            'curator': 2,   // Проектный куратор
            'member': 1     // Участник проекта
        };
    }
    
    // Инициализация при загрузке страницы
    async init() {
        await this.loadUserData();
        this.setupGlobalHelpers();
        this.applyPermissionsToUI();
    }
    
    // Загрузка данных пользователя
    async loadUserData() {
        const token = localStorage.getItem('auth_token');
        
        if (!token) {
            this.setGuestMode();
            return;
        }
        
        try {
            // Проверяем токен
            const verifyResponse = await window.apiService.get('/api/auth/verify.php');
            
            if (!verifyResponse.success) {
                this.setGuestMode();
                return;
            }
            
            // Загружаем полные данные пользователя
            const userResponse = await window.apiService.get('/api/auth/me.php');
            
            if (userResponse.success) {
                this.currentUser = {
                    actor_id: userResponse.actor.actor_id,
                    username: userResponse.actor.username,
                    global_status: userResponse.actor.global_status || 'Участник ТЦ',
                    locality_id: userResponse.actor.location_id,
                    project_roles: {},
                    directions: userResponse.directions || []
                };
                
                // Формируем объект ролей в проектах
                if (userResponse.project_roles) {
                    userResponse.project_roles.forEach(role => {
                        this.currentUser.project_roles[role.project_id] = {
                            role_type: role.role_type,
                            role_name: role.role_name
                        };
                    });
                }
                
                console.log('User permissions loaded:', this.currentUser);
            }
        } catch (error) {
            console.error('Failed to load user permissions:', error);
            this.setGuestMode();
        }
    }
    
    setGuestMode() {
        this.currentUser = {
            actor_id: null,
            username: null,
            global_status: 'Гость',
            locality_id: null,
            project_roles: {},
            directions: []
        };
    }
    
    // Глобальные хелперы для удобства
    setupGlobalHelpers() {
        window.hasGlobalStatus = (statusName) => this.hasGlobalStatus(statusName);
        window.hasProjectRole = (projectId, requiredRole) => this.hasProjectRole(projectId, requiredRole);
        window.canViewProject = (projectId) => this.canViewProject(projectId);
        window.canEditProject = (projectId) => this.canEditProject(projectId);
        window.canCreateTask = (projectId) => this.canCreateTask(projectId);
        window.canViewContactDetails = (projectId) => this.canViewContactDetails(projectId);
        window.canInviteToProject = (projectId) => this.canInviteToProject(projectId);
        window.isGuest = () => this.isGuest();
        window.isTCMember = () => this.isTCMember();
        window.isTCLeader = () => this.isTCLeader();
        window.isDirectionCurator = () => this.isDirectionCurator();
        window.isProjectLeader = (projectId) => this.isProjectLeader(projectId);
    }
    
    // Применение прав к интерфейсу
    applyPermissionsToUI() {
        // Скрываем/показываем элементы в зависимости от статуса
        this.toggleElementsByStatus();
        
        // Настраиваем доступ к проектам
        this.setupProjectAccess();
        
        // Настраиваем меню
        this.setupMenuPermissions();
    }
    
    toggleElementsByStatus() {
        const status = this.currentUser.global_status;
        const isGuest = status === 'Гость';
        
        // Элементы, скрываемые для гостей
        const guestHiddenSelectors = [
            '.create-project-btn',
            '.create-idea-btn',
            '.create-resource-btn',
            '.create-event-btn',
            '.create-service-btn',
            '.create-topic-btn',
            '.notes-panel',
            '.favorites-panel',
            '.messages-panel',
            '.invite-to-project-btn'
        ];
        
        if (isGuest) {
            guestHiddenSelectors.forEach(selector => {
                document.querySelectorAll(selector).forEach(el => {
                    el.style.display = 'none';
                });
            });
        }
        
        // Элементы, доступные только Руководителю ТЦ
        if (!this.isTCLeader()) {
            document.querySelectorAll('.tc-leader-only').forEach(el => {
                el.style.display = 'none';
            });
        }
        
        // Элементы, доступные только Кураторам направления
        if (!this.isDirectionCurator()) {
            document.querySelectorAll('.direction-curator-only').forEach(el => {
                el.style.display = 'none';
            });
        }
    }
    
    setupProjectAccess() {
        // Получаем project_id из URL, если мы на странице проекта
        const urlParams = new URLSearchParams(window.location.search);
        const projectId = urlParams.get('project');
        
        if (projectId && !this.canViewProject(projectId)) {
            // Перенаправляем на страницу проектов, если нет доступа
            window.location.href = '/pages/Projects.html';
        }
    }
    
    setupMenuPermissions() {
        // Настройка видимости пунктов меню согласно ТЗ
        
        // Для гостей
        if (this.isGuest()) {
            this.hideMenuItems(['create-project', 'my-projects', 'messages', 'notes', 'favorites']);
        }
        
        // Для участников ТЦ
        if (this.isTCMember()) {
            this.showMenuItems(['create-project', 'my-projects', 'messages', 'notes', 'favorites']);
        }
        
        // Для руководителей ТЦ
        if (this.isTCLeader()) {
            this.showMenuItems(['tc-admin', 'assign-curators']);
        }
    }
    
    hideMenuItems(menuIds) {
        menuIds.forEach(id => {
            const element = document.getElementById(`menu-${id}`);
            if (element) element.style.display = 'none';
        });
    }
    
    showMenuItems(menuIds) {
        menuIds.forEach(id => {
            const element = document.getElementById(`menu-${id}`);
            if (element) element.style.display = 'block';
        });
    }
    
    // === ОСНОВНЫЕ МЕТОДЫ ПРОВЕРКИ ПРАВ ===
    
    // Проверка глобального статуса
    hasGlobalStatus(statusName) {
        return this.currentUser.global_status === statusName;
    }
    
    // Проверка статуса гостя
    isGuest() {
        return this.hasGlobalStatus('Гость');
    }
    
    // Проверка статуса участника ТЦ
    isTCMember() {
        const status = this.currentUser.global_status;
        return status !== 'Гость' && this.statusHierarchy[status] >= this.statusHierarchy['Участник ТЦ'];
    }
    
    // Проверка статуса руководителя ТЦ
    isTCLeader() {
        return this.hasGlobalStatus('Руководитель ТЦ');
    }
    
    // Проверка статуса куратора направления
    isDirectionCurator() {
        return this.hasGlobalStatus('Куратор направления');
    }
    
    // Проверка роли в проекте
    hasProjectRole(projectId, requiredRole) {
        const role = this.currentUser.project_roles[projectId];
        if (!role) return false;
        
        const userLevel = this.roleHierarchy[role.role_type] || 0;
        const requiredLevel = this.roleHierarchy[requiredRole] || 0;
        
        return userLevel >= requiredLevel;
    }
    
    // Проверка, является ли руководителем проекта
    isProjectLeader(projectId) {
        return this.hasProjectRole(projectId, 'leader');
    }
    
    // === СПЕЦИФИЧЕСКИЕ ПРОВЕРКИ ПРАВ ПО ТЗ ===
    
    // 1. Просмотр главной страницы проекта
    canViewProjectMain(projectId) {
        // Могут: Гость (только список), Участник ТЦ, Участник проекта и выше
        return this.hasProjectRole(projectId, 'member') || 
               this.isTCMember() ||
               this.isGuest(); // Но для гостей будет ограничение в applyPermissionsToUI
    }
    
    // 2. Просмотр страниц ProjectMain, ProjectMedia, ProjectKanban
    canViewProjectPages(projectId) {
        // Могут: Участники проекта и выше
        return this.hasProjectRole(projectId, 'member');
    }
    
    // 3. Редактирование и добавление контента в проекте
    canEditProject(projectId) {
        // Только Руководитель проекта
        return this.hasProjectRole(projectId, 'leader');
    }
    
    // 4. Создание задач в проекте
    canCreateTask(projectId) {
        // Руководитель и Администратор проекта
        return this.hasProjectRole(projectId, 'leader') || 
               this.hasProjectRole(projectId, 'admin');
    }
    
    // 5. Просмотр контактных данных
    canViewContactDetails(projectId) {
        // Могут: Администратор проекта, Руководитель проекта, Кураторы
        return this.hasProjectRole(projectId, 'admin') ||
               this.hasProjectRole(projectId, 'leader') ||
               this.hasProjectRole(projectId, 'curator') ||
               this.isTCLeader() ||
               this.isDirectionCurator();
    }
    
    // 6. Приглашение в проект
    canInviteToProject(projectId) {
        // Руководитель и Администратор проекта
        return this.hasProjectRole(projectId, 'leader') || 
               this.hasProjectRole(projectId, 'admin');
    }
    
    // 7. Создание нового проекта
    canCreateProject() {
        // Любой участник ТЦ
        return this.isTCMember();
    }
    
    // 8. Назначение кураторов
    canAssignCurators() {
        // Руководитель ТЦ
        return this.isTCLeader();
    }
    
    // 9. Проверка проекта (верификация)
    canVerifyProject(projectId) {
        // Проектный куратор и Куратор направления
        return this.hasProjectRole(projectId, 'curator') || 
               this.isDirectionCurator();
    }
    
    // 10. Приостановка проекта
    canSuspendProject(projectId) {
        // Куратор направления
        return this.isDirectionCurator();
    }
    
    // Проверка доступа к API с обработкой ошибок
    async checkApiPermission(endpoint, projectId = null) {
        try {
            // Для проектных эндпоинтов проверяем права
            if (projectId && endpoint.includes('/projects/')) {
                const response = await window.apiService.get(`/api/projects/permissions.php`, {
                    project_id: projectId
                });
                
                if (!response.has_access) {
                    throw new Error(`No access to project ${projectId}: ${response.access_reason}`);
                }
                
                return true;
            }
            
            return true;
        } catch (error) {
            console.error('Permission check failed:', error);
            throw error;
        }
    }
    
    // Получение текущего проекта из URL
    getCurrentProjectId() {
        const urlParams = new URLSearchParams(window.location.search);
        return urlParams.get('project');
    }
    
    // Показать модальное окно с информацией о правах
    showPermissionAlert(message, options = {}) {
        const alertDiv = document.createElement('div');
        alertDiv.className = 'permission-alert';
        alertDiv.innerHTML = `
            <div class="permission-alert-content">
                <h3>Ограничение доступа</h3>
                <p>${message}</p>
                ${options.requiredStatus ? `<p><strong>Требуемый статус:</strong> ${options.requiredStatus}</p>` : ''}
                ${options.currentStatus ? `<p><strong>Ваш текущий статус:</strong> ${options.currentStatus}</p>` : ''}
                <button onclick="this.parentElement.parentElement.remove()">Закрыть</button>
            </div>
        `;
        
        document.body.appendChild(alertDiv);
        
        // Автоматическое скрытие через 5 секунд
        setTimeout(() => {
            if (alertDiv.parentNode) {
                alertDiv.remove();
            }
        }, 5000);
    }
}

// Создаем и экспортируем экземпляр
window.authPermissions = new AuthPermissions();

// Инициализируем при загрузке страницы
document.addEventListener('DOMContentLoaded', () => {
    window.authPermissions.init();
});

// CSS для модального окна прав
const style = document.createElement('style');
style.textContent = `
.permission-alert {
    position: fixed;
    top: 20px;
    right: 20px;
    background: #ffebee;
    border: 2px solid #f44336;
    border-radius: 8px;
    padding: 15px;
    max-width: 400px;
    z-index: 10000;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
}

.permission-alert-content h3 {
    margin-top: 0;
    color: #d32f2f;
}

.permission-alert-content button {
    background: #d32f2f;
    color: white;
    border: none;
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
    margin-top: 10px;
}

.permission-alert-content button:hover {
    background: #b71c1c;
}
`;
document.head.appendChild(style);