// Глобальный объект для хранения данных пользователя
window.currentUser = {
    actor_id: null,
    global_status: 'Гость',
    project_roles: {},
    permissions: {}
};

// Проверка аутентификации при загрузке страницы
document.addEventListener('DOMContentLoaded', async function() {
    await checkAuthAndLoadPermissions();
    
    // Инициализируем панели в зависимости от статуса
    initPanelsBasedOnStatus();
});

async function checkAuthAndLoadPermissions() {
    const token = localStorage.getItem('auth_token');
    const currentPage = window.location.pathname;
    
    // Страницы, доступные без авторизации (гости)
    const publicPages = [
        '/index.html',
        '/pages/enter-reg.html',
        '/pages/RecoveryPass.html',
        '/pages/Agreement.html',
        '/pages/HowItWorks.html',
        '/pages/News.html',
        '/pages/Projects.html',
        '/pages/Ideas.html',
        '/pages/resources.html',
        '/pages/events.html',
        '/pages/services.html',
        '/pages/topics.html',
        '/pages/actors.html'
    ];
    
    // Если пользователь не авторизован и пытается получить доступ к защищенной странице
    if (!token && !publicPages.includes(currentPage)) {
        window.location.href = '/pages/enter-reg.html';
        return;
    }
    
    // Если токен есть, проверяем его валидность и загружаем права
    if (token) {
        try {
            const isValid = await verifyToken(token);
            if (!isValid) {
                localStorage.removeItem('auth_token');
                window.currentUser = { actor_id: null, global_status: 'Гость', project_roles: {} };
                
                if (!publicPages.includes(currentPage)) {
                    window.location.href = '/pages/enter-reg.html';
                }
            } else {
                // Загружаем данные пользователя и права
                await loadUserDataAndPermissions();
            }
        } catch (error) {
            console.error('Auth check failed:', error);
            window.currentUser = { actor_id: null, global_status: 'Гость', project_roles: {} };
        }
    } else {
        // Гость
        window.currentUser = { actor_id: null, global_status: 'Гость', project_roles: {} };
    }
}

async function verifyToken(token) {
    try {
        const response = await fetch('/api/auth/verify.php', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        return response.ok;
    } catch (error) {
        console.error('Token verification failed:', error);
        return false;
    }
}

async function loadUserDataAndPermissions() {
    try {
        // 1. Получаем ID пользователя
        const userResponse = await fetch('/api/auth/me.php', {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('auth_token')}`
            }
        });
        
        if (!userResponse.ok) {
            throw new Error('Failed to get user data');
        }
        
        const userData = await userResponse.json();
        const userId = userData.actor_id;
        
        // 2. Загружаем глобальный статус и роли в проектах
        const statusResponse = await fetch(`/api/actors/statuses.php`, {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('auth_token')}`
            }
        });
        
        if (statusResponse.ok) {
            const statusData = await statusResponse.json();
            window.currentUser.actor_id = userId;
            window.currentUser.global_status = statusData.current_status?.status || 'Участник ТЦ';
            
            // Загружаем дополнительные права если есть
            await loadProjectRoles(userId);
        }
        
        console.log('User permissions loaded:', window.currentUser);
        
    } catch (error) {
        console.error('Failed to load user permissions:', error);
        // Устанавливаем статус по умолчанию
        window.currentUser.global_status = 'Участник ТЦ';
    }
}

async function loadProjectRoles(actorId) {
    try {
        // Загружаем проекты с ролями пользователя
        const response = await fetch('/api/projects/index.php', {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('auth_token')}`
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            if (data.success && data.projects) {
                // Сохраняем роли пользователя в проектах
                data.projects.forEach(project => {
                    if (project.user_role) {
                        window.currentUser.project_roles[project.project_id] = {
                            role_type: project.user_role,
                            role_name: project.user_role_name
                        };
                    }
                });
            }
        }
    } catch (error) {
        console.error('Failed to load project roles:', error);
    }
}

function initPanelsBasedOnStatus() {
    // Инициализация панелей в зависимости от статуса пользователя
    const status = window.currentUser.global_status;
    
    // Для гостей скрываем некоторые функциональные панели
    if (status === 'Гость' || !window.currentUser.actor_id) {
        // Скрываем панели заметок, избранного, сообщений для гостей
        const guestHiddenPanels = ['notes-panel', 'favorites-panel', 'messages-panel'];
        guestHiddenPanels.forEach(panelId => {
            const panel = document.getElementById(panelId);
            if (panel) panel.style.display = 'none';
        });
    }
    
    // Для участников ТЦ и выше показываем все панели
    if (status !== 'Гость' && window.currentUser.actor_id) {
        // Можно добавить дополнительную логику инициализации
        console.log('Initializing panels for status:', status);
    }
}

// Экспортируемые функции для проверки прав
window.hasGlobalStatus = function(statusName) {
    return window.currentUser.global_status === statusName;
};

window.hasProjectRole = function(projectId, requiredRole) {
    const role = window.currentUser.project_roles[projectId];
    if (!role) return false;
    
    const roleHierarchy = {
        'leader': 4,
        'admin': 3,
        'curator': 3,
        'member': 2
    };
    
    const userLevel = roleHierarchy[role.role_type] || 0;
    const requiredLevel = roleHierarchy[requiredRole] || 0;
    
    return userLevel >= requiredLevel;
};

window.canViewProject = function(projectId) {
    // Могут: Гость, Участник ТЦ, Участник проекта и выше
    return window.hasProjectRole(projectId, 'member') || 
           window.hasGlobalStatus('Участник ТЦ') ||
           window.hasGlobalStatus('Гость');
};