/**
 * Упрощенный проверщик прав для немедленного использования
 */

class PermissionsChecker {
    constructor() {
        this.currentUser = null;
        this.initialized = false;
    }
    
    // Быстрая инициализация
    async quickInit() {
        const token = localStorage.getItem('auth_token');
        
        if (!token) {
            this.currentUser = {
                actor_id: null,
                global_status: 'Гость',
                project_roles: {}
            };
            this.initialized = true;
            return;
        }
        
        try {
            // Быстрая проверка токена
            const response = await fetch('/api/auth/verify.php', {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            
            if (response.ok) {
                const data = await response.json();
                this.currentUser = {
                    actor_id: data.user_id,
                    global_status: data.global_status || 'Участник ТЦ',
                    project_roles: await this.loadProjectRoles(data.user_id)
                };
            } else {
                this.currentUser = {
                    actor_id: null,
                    global_status: 'Гость',
                    project_roles: {}
                };
            }
        } catch (error) {
            console.warn('Quick auth check failed:', error);
            this.currentUser = {
                actor_id: null,
                global_status: 'Гость',
                project_roles: {}
            };
        }
        
        this.initialized = true;
        this.applyQuickRestrictions();
    }
    
    async loadProjectRoles(actorId) {
        try {
            const response = await fetch(`/api/projects/index.php`, {
                headers: { 'Authorization': `Bearer ${localStorage.getItem('auth_token')}` }
            });
            
            if (response.ok) {
                const data = await response.json();
                const roles = {};
                
                if (data.projects) {
                    data.projects.forEach(project => {
                        if (project.user_role) {
                            roles[project.project_id] = {
                                role_type: project.user_role,
                                role_name: project.user_role_name
                            };
                        }
                    });
                }
                
                return roles;
            }
        } catch (error) {
            console.warn('Failed to load project roles:', error);
        }
        
        return {};
    }
    
    // Быстрое применение ограничений
    applyQuickRestrictions() {
        // 1. Проверить доступ к текущей странице проекта
        const urlParams = new URLSearchParams(window.location.search);
        const projectId = urlParams.get('project');
        
        if (projectId && this.isProjectPage()) {
            this.checkProjectAccess(projectId);
        }
        
        // 2. Скрыть элементы для гостей
        if (this.isGuest()) {
            this.hideGuestElements();
        }
        
        // 3. Показать элементы по статусу
        this.showStatusBasedElements();
    }
    
    isProjectPage() {
        const path = window.location.pathname;
        return path.includes('ProjectMain.html') || 
               path.includes('ProjectMedia.html') || 
               path.includes('ProjectKanban.html');
    }
    
    async checkProjectAccess(projectId) {
        if (this.isGuest()) {
            this.redirectToProjects('Гости не имеют доступа к страницам проектов');
            return;
        }
        
        try {
            const token = localStorage.getItem('auth_token');
            const response = await fetch(`/api/projects/permissions.php?project_id=${projectId}`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            
            if (response.ok) {
                const data = await response.json();
                
                if (!data.has_access) {
                    this.redirectToProjects(data.access_reason);
                } else {
                    // Настроить интерфейс по уровню доступа
                    this.setupProjectUI(projectId, data.access_level);
                }
            }
        } catch (error) {
            console.error('Project access check failed:', error);
            this.redirectToProjects('Ошибка проверки доступа');
        }
    }
    
    redirectToProjects(reason) {
        alert(`Доступ запрещен: ${reason}`);
        window.location.href = '/pages/Projects.html';
    }
    
    setupProjectUI(projectId, accessLevel) {
        // Скрыть/показать элементы в зависимости от роли
        const roleBasedElements = {
            'leader': ['.edit-project', '.delete-project', '.invite-user', '.create-task', '.change-settings'],
            'admin': ['.invite-user', '.create-task', '.manage-tasks'],
            'member': ['.view-tasks', '.participate'],
            'tc_leader': ['.view-all', '.assign-curators'],
            'direction_curator': ['.verify-project', '.suspend-project']
        };
        
        // Скрыть все элементы управления
        Object.values(roleBasedElements).flat().forEach(selector => {
            document.querySelectorAll(selector).forEach(el => {
                el.style.display = 'none';
            });
        });
        
        // Показать элементы для текущего уровня доступа
        if (roleBasedElements[accessLevel]) {
            roleBasedElements[accessLevel].forEach(selector => {
                document.querySelectorAll(selector).forEach(el => {
                    el.style.display = 'block';
                });
            });
        }
    }
    
    hideGuestElements() {
        const guestHidden = [
            '.create-project-btn',
            '.create-idea-btn',
            '.create-resource-btn',
            '.create-event-btn',
            '.notes-panel',
            '.favorites-panel',
            '.messages-panel',
            '.send-message-btn',
            '.add-to-favorites'
        ];
        
        guestHidden.forEach(selector => {
            document.querySelectorAll(selector).forEach(el => {
                el.style.display = 'none';
            });
        });
    }
    
    showStatusBasedElements() {
        const status = this.currentUser.global_status;
        
        // Элементы для Руководителя ТЦ
        if (status === 'Руководитель ТЦ') {
            document.querySelectorAll('.tc-leader-only').forEach(el => {
                el.style.display = 'block';
            });
        }
        
        // Элементы для Куратора направления
        if (status === 'Куратор направления') {
            document.querySelectorAll('.direction-curator-only').forEach(el => {
                el.style.display = 'block';
            });
        }
        
        // Элементы для Участника ТЦ
        if (status === 'Участник ТЦ') {
            document.querySelectorAll('.tc-member-only').forEach(el => {
                el.style.display = 'block';
            });
        }
    }
    
    // Быстрые проверки
    isGuest() {
        return !this.currentUser || this.currentUser.global_status === 'Гость';
    }
    
    isTCMember() {
        return this.currentUser && this.currentUser.global_status !== 'Гость';
    }
    
    isTCLeader() {
        return this.currentUser && this.currentUser.global_status === 'Руководитель ТЦ';
    }
    
    hasProjectRole(projectId, requiredRole) {
        if (!this.currentUser || !this.currentUser.project_roles[projectId]) {
            return false;
        }
        
        const role = this.currentUser.project_roles[projectId];
        const hierarchy = { 'leader': 4, 'admin': 3, 'curator': 3, 'member': 2 };
        
        const userLevel = hierarchy[role.role_type] || 0;
        const requiredLevel = hierarchy[requiredRole] || 0;
        
        return userLevel >= requiredLevel;
    }
}

// Создать и немедленно инициализировать
window.permissionsChecker = new PermissionsChecker();

// Запустить при загрузке страницы
document.addEventListener('DOMContentLoaded', () => {
    window.permissionsChecker.quickInit();
});