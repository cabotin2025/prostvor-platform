// js/auth-permissions.js - Управление правами доступа
console.log('🔐 auth-permissions.js загружен');

const AuthPermissions = {
    // Статусы пользователей
    STATUSES: {
        PARTICIPANT: 'Участник ТЦ',
        PROJECT_LEADER: 'Руководитель проекта',
        CURATOR: 'Проектный куратор',
        DIRECTION_LEADER: 'Руководитель ТЦ',
        ADMIN: 'Администратор'
    },
    
    // Проверка авторизации
    isAuthenticated() {
        const token = localStorage.getItem('prostvor_token') || 
                      sessionStorage.getItem('prostvor_token');
        return !!token;
    },
    
    // Получение текущего пользователя
    getCurrentUser() {
        if (!this.isAuthenticated()) return null;
        
        const userStr = localStorage.getItem('prostvor_user') || 
                       sessionStorage.getItem('prostvor_user');
        try {
            return JSON.parse(userStr);
        } catch (e) {
            console.error('Ошибка парсинга пользователя:', e);
            return null;
        }
    },
    
    // Получение статуса пользователя
    getUserStatus() {
        const user = this.getCurrentUser();
        return user ? user.status : null;
    },
    
    // Проверка прав
    canCreateProjects() {
        const status = this.getUserStatus();
        const allowedStatuses = [
            this.STATUSES.PROJECT_LEADER,
            this.STATUSES.CURATOR,
            this.STATUSES.DIRECTION_LEADER,
            this.STATUSES.ADMIN
        ];
        return this.isAuthenticated() && allowedStatuses.includes(status);
    },
    
    canCreateEvents() {
        return this.canCreateProjects(); // Те же права
    },
    
    canCreateTopics() {
        return this.isAuthenticated(); // Все авторизованные
    },
    
    canCreateServices() {
        return this.isAuthenticated(); // Все авторизованные
    },
    
    canManageResources() {
        const status = this.getUserStatus();
        const allowedStatuses = [
            this.STATUSES.CURATOR,
            this.STATUSES.DIRECTION_LEADER,
            this.STATUSES.ADMIN
        ];
        return this.isAuthenticated() && allowedStatuses.includes(status);
    },
    
    // Обновление UI на основе прав
    updateUIBasedOnPermissions() {
        console.log('🔧 Обновляю UI на основе прав доступа...');
        
        const user = this.getCurrentUser();
        const isAuth = this.isAuthenticated();
        
        // Элементы, доступные только авторизованным
        document.querySelectorAll('[data-auth-only]').forEach(el => {
            el.style.display = isAuth ? 'block' : 'none';
            el.style.opacity = isAuth ? '1' : '0.3';
            el.style.pointerEvents = isAuth ? 'auto' : 'none';
        });
        
        // Элементы, доступные только гостям
        document.querySelectorAll('[data-guest-only]').forEach(el => {
            el.style.display = isAuth ? 'none' : 'block';
        });
        
        // Элементы, требующие специальных прав
        document.querySelectorAll('[data-permission="create-projects"]').forEach(el => {
            const hasPermission = this.canCreateProjects();
            el.style.display = hasPermission ? 'block' : 'none';
            if (!hasPermission) {
                el.title = 'Для создания проектов нужен статус Руководителя проекта или выше';
            }
        });
        
        document.querySelectorAll('[data-permission="create-events"]').forEach(el => {
            const hasPermission = this.canCreateEvents();
            el.style.display = hasPermission ? 'block' : 'none';
        });
        
        // Обновляем текст/состояние элементов
        document.querySelectorAll('[data-user-status]').forEach(el => {
            if (user && user.status) {
                el.textContent = user.status;
                el.style.display = 'inline';
            }
        });
        
        document.querySelectorAll('[data-user-name]').forEach(el => {
            if (user && user.nickname) {
                el.textContent = user.nickname;
            }
        });
        
        console.log('✅ UI обновлен. Авторизован:', isAuth, 'Статус:', user ? user.status : 'нет');
    },
    
    // Инициализация
    init() {
        console.log('🔐 Инициализация системы прав доступа');
        
        // Обновляем UI сразу
        this.updateUIBasedOnPermissions();
        
        // Слушаем изменения авторизации
        window.addEventListener('storage', (e) => {
            if (e.key === 'prostvor_token' || e.key === 'prostvor_user') {
                console.log('🔄 Обнаружено изменение авторизации, обновляю права...');
                this.updateUIBasedOnPermissions();
            }
        });
        
        // Также обновляем при загрузке страницы
        document.addEventListener('DOMContentLoaded', () => {
            this.updateUIBasedOnPermissions();
        });
        
        // Делаем глобально доступным
        window.AuthPermissions = this;
        
        console.log('✅ Система прав доступа инициализирована');
    }
};

// Автоматическая инициализация
AuthPermissions.init();