/**
 * Менеджер статусов пользователей для платформы Prostvor
 * Управление глобальными статусами и правами доступа
 * ВЕРСИЯ 2.0 - исправлена для работы с реальной структурой БД
 */

class StatusManager {
    constructor() {
        console.log('📊 Status Manager загружен (v2.0)');
        
        // Карта соответствия статусов и их уровней
        this.statusLevelMap = {
            'Гость': 0,
            'Участник ТЦ': 1,
            'Участник проекта': 2,
            'Администратор проекта': 3,
            'Руководитель проекта': 4,
            'Проектный куратор': 5,
            'Куратор направления': 6,
            'Руководитель ТЦ': 7
        };
        
        // Описания статусов для UI
        this.statusDescriptions = {
            'Гость': 'Не является участником ТЦ. Может просматривать публичную информацию.',
            'Участник ТЦ': 'Базовый участник творческого центра. Может создавать проекты, идеи, ресурсы.',
            'Участник проекта': 'Участник конкретного проекта. Может просматривать проектную информацию.',
            'Администратор проекта': 'Администратор проекта. Может управлять задачами и участниками.',
            'Руководитель проекта': 'Руководитель проекта. Может редактировать проект, назначать роли.',
            'Проектный куратор': 'Куратор назначенный на проект. Может проверять проект.',
            'Куратор направления': 'Куратор творческого направления в населенном пункте.',
            'Руководитель ТЦ': 'Руководитель творческого центра в населенном пункте.'
        };
        
        // Текущие данные пользователя
        this.currentUser = {
            actor_id: null,
            nickname: null,
            global_status: 'Гость',
            all_statuses: ['Гость'],
            max_level: 0,
            project_roles: {}
        };
        
        this.initialized = false;
    }
    
    /**
     * Инициализация менеджера статусов
     */
    async init() {
        console.log('📊 Инициализация менеджера статусов');
        
        try {
            // Загружаем данные пользователя
            await this.loadCurrentUser();
            
            // Обновляем UI
            await this.updateUIByStatus();
            
            this.initialized = true;
            console.log('✅ Менеджер статусов инициализирован');
            
        } catch (error) {
            console.error('❌ Ошибка инициализации StatusManager:', error);
            // Устанавливаем статус гостя по умолчанию
            this.setGuestStatus();
        }
    }
    
    /**
     * Загрузка данных текущего пользователя
     */
    async loadCurrentUser() {
        try {
            // Получаем данные из localStorage
            const actorId = localStorage.getItem('user_id');
            const nickname = localStorage.getItem('user_nickname');
            const token = localStorage.getItem('auth_token');
            
            if (!token) {
                // Пользователь не авторизован - гость
                this.setGuestStatus();
                return;
            }
            
            // Сохраняем базовые данные
            this.currentUser.actor_id = actorId ? parseInt(actorId) : null;
            this.currentUser.nickname = nickname || 'Пользователь';
            
            // Запрашиваем статусы с сервера
            const statusData = await this.fetchUserStatuses(this.currentUser.actor_id);
            
            if (statusData.success) {
                // Обновляем данные пользователя
                this.currentUser.global_status = statusData.current_status?.status || 'Участник ТЦ';
                this.currentUser.all_statuses = statusData.statuses || ['Участник ТЦ'];
                this.currentUser.max_level = statusData.max_level || 1;
                
                console.log(`👤 Пользователь: ${this.currentUser.nickname}`);
                console.log(`📋 Статус: ${this.currentUser.global_status}`);
                console.log(`📊 Уровень: ${this.currentUser.max_level}`);
            } else {
                // Если не удалось получить статусы, используем по умолчанию
                this.currentUser.global_status = 'Участник ТЦ';
                this.currentUser.all_statuses = ['Участник ТЦ'];
                this.currentUser.max_level = 1;
            }
            
            // Загружаем роли в проектах
            await this.loadProjectRoles();
            
        } catch (error) {
            console.error('❌ Ошибка загрузки данных пользователя:', error);
            this.setGuestStatus();
        }
    }
    
    /**
     * Запрос статусов пользователя с сервера
     */
    async fetchUserStatuses(actorId) {
        try {
            if (!actorId) {
                return {
                    success: true,
                    statuses: ['Гость'],
                    max_level: 0
                };
            }
            
            const token = localStorage.getItem('auth_token');
            if (!token) {
                return {
                    success: true,
                    statuses: ['Гость'],
                    max_level: 0
                };
            }
            
            // Используем API для получения статусов
            const response = await fetch(`/api/actors/statuses.php?actor_id=${actorId}`, {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });
            
            if (response.ok) {
                return await response.json();
            } else {
                // Если API не доступен, возвращаем стандартные данные
                return {
                    success: true,
                    statuses: ['Участник ТЦ'],
                    current_status: { status: 'Участник ТЦ', actor_status_id: 7 },
                    max_level: 1
                };
            }
            
        } catch (error) {
            console.warn('⚠️ Не удалось получить статусы с сервера:', error.message);
            
            // Возвращаем данные по умолчанию
            return {
                success: true,
                statuses: ['Участник ТЦ'],
                current_status: { status: 'Участник ТЦ', actor_status_id: 7 },
                max_level: 1
            };
        }
    }
    
    /**
     * Загрузка ролей пользователя в проектах
     */
    async loadProjectRoles() {
        try {
            const token = localStorage.getItem('auth_token');
            if (!token || !this.currentUser.actor_id) {
                this.currentUser.project_roles = {};
                return;
            }
            
            // Запрашиваем проекты пользователя
            const response = await fetch('/api/projects/index.php', {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });
            
            if (response.ok) {
                const data = await response.json();
                
                if (data.success && data.projects) {
                    // Извлекаем роли из данных проектов
                    this.currentUser.project_roles = {};
                    
                    data.projects.forEach(project => {
                        if (project.user_role) {
                            this.currentUser.project_roles[project.project_id] = {
                                role_type: project.user_role,
                                role_name: project.user_role_name,
                                project_name: project.title
                            };
                        }
                    });
                    
                    console.log(`📂 Загружено ${Object.keys(this.currentUser.project_roles).length} проектных ролей`);
                }
            }
        } catch (error) {
            console.warn('⚠️ Не удалось загрузить проектные роли:', error.message);
            this.currentUser.project_roles = {};
        }
    }
    
    /**
     * Установка статуса гостя
     */
    setGuestStatus() {
        this.currentUser = {
            actor_id: null,
            nickname: null,
            global_status: 'Гость',
            all_statuses: ['Гость'],
            max_level: 0,
            project_roles: {}
        };
    }
    
    /**
     * Обновление UI на основе статуса пользователя
     */
    async updateUIByStatus() {
        console.log('🎯 Обновляю UI на основе статусов...');
        
        const status = this.currentUser.global_status;
        const maxLevel = this.currentUser.max_level;
        
        // Показываем информацию о статусе в UI
        this.updateStatusDisplay(status, maxLevel);
        
        // Настраиваем видимость элементов в зависимости от статуса
        this.configureUIByStatus(status);
        
        // Показываем следующий доступный статус (для прогресса)
        this.showNextAvailableStatus(maxLevel);
    }
    
    /**
     * Обновление отображения статуса в UI
     */
    updateStatusDisplay(status, level) {
        // Находим элемент для отображения статуса
        const statusElement = document.getElementById('user-status-display') ||
                              document.querySelector('.user-status') ||
                              document.querySelector('[data-status-display]');
        
        if (statusElement) {
            statusElement.textContent = status;
            statusElement.title = this.statusDescriptions[status] || '';
            statusElement.dataset.level = level;
            
            // Добавляем CSS класс в зависимости от уровня
            statusElement.className = 'user-status';
            statusElement.classList.add(`status-level-${level}`);
            statusElement.classList.add(`status-${status.replace(/\s+/g, '-').toLowerCase()}`);
        }
        
        // Обновляем заголовок страницы или другие элементы
        const nickname = this.currentUser.nickname;
        if (nickname && nickname !== 'Пользователь') {
            const titleElements = document.querySelectorAll('[data-user-nickname]');
            titleElements.forEach(el => {
                el.textContent = nickname;
            });
        }
    }
    
    /**
     * Настройка UI в зависимости от статуса
     */
    configureUIByStatus(status) {
        // Элементы, которые нужно скрыть для гостей
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
            '.invite-user-btn',
            '.project-admin-panel'
        ];
        
        // Элементы только для Руководителя ТЦ
        const tcLeaderSelectors = [
            '.tc-leader-only',
            '.assign-curator-btn',
            '.manage-directions',
            '.system-admin-panel'
        ];
        
        // Элементы только для Куратора направления
        const curatorSelectors = [
            '.direction-curator-only',
            '.verify-project-btn',
            '.suspend-project-btn',
            '.curator-dashboard'
        ];
        
        // Скрываем все специальные элементы сначала
        const allSelectors = [...guestHiddenSelectors, ...tcLeaderSelectors, ...curatorSelectors];
        allSelectors.forEach(selector => {
            document.querySelectorAll(selector).forEach(el => {
                el.style.display = 'none';
            });
        });
        
        // Для гостей только скрываем функциональные элементы
        if (status === 'Гость') {
            guestHiddenSelectors.forEach(selector => {
                document.querySelectorAll(selector).forEach(el => {
                    el.style.display = 'none';
                });
            });
            return;
        }
        
        // Для участников ТЦ и выше показываем основные функции
        if (this.statusLevelMap[status] >= this.statusLevelMap['Участник ТЦ']) {
            guestHiddenSelectors.forEach(selector => {
                document.querySelectorAll(selector).forEach(el => {
                    el.style.display = '';
                });
            });
        }
        
        // Для Руководителя ТЦ
        if (status === 'Руководитель ТЦ') {
            tcLeaderSelectors.forEach(selector => {
                document.querySelectorAll(selector).forEach(el => {
                    el.style.display = '';
                });
            });
        }
        
        // Для Куратора направления
        if (status === 'Куратор направления') {
            curatorSelectors.forEach(selector => {
                document.querySelectorAll(selector).forEach(el => {
                    el.style.display = '';
                });
            });
        }
        
        // Настраиваем кнопки создания в зависимости от статуса
        this.configureCreationButtons(status);
    }
    
    /**
     * Настройка кнопок создания
     */
    configureCreationButtons(status) {
        const canCreateProject = this.statusLevelMap[status] >= this.statusLevelMap['Участник ТЦ'];
        const canCreateGlobal = this.statusLevelMap[status] >= this.statusLevelMap['Участник ТЦ'];
        
        // Кнопка создания проекта
        document.querySelectorAll('.create-project-btn').forEach(btn => {
            if (canCreateProject) {
                btn.disabled = false;
                btn.title = 'Создать новый проект';
            } else {
                btn.disabled = true;
                btn.title = 'Только участники ТЦ могут создавать проекты';
            }
        });
        
        // Другие кнопки создания
        const createButtons = [
            '.create-idea-btn',
            '.create-resource-btn', 
            '.create-event-btn',
            '.create-service-btn',
            '.create-topic-btn'
        ];
        
        createButtons.forEach(selector => {
            document.querySelectorAll(selector).forEach(btn => {
                if (canCreateGlobal) {
                    btn.disabled = false;
                } else {
                    btn.disabled = true;
                    btn.title = 'Требуется авторизация';
                }
            });
        });
    }
    
    /**
     * Показ следующего доступного статуса
     */
    showNextAvailableStatus(currentLevel) {
        // Находим следующий статус по уровню
        let nextStatus = null;
        let nextLevel = currentLevel + 1;
        
        for (const [status, level] of Object.entries(this.statusLevelMap)) {
            if (level === nextLevel) {
                nextStatus = status;
                break;
            }
        }
        
        // Обновляем UI, если есть следующий статус
        const nextStatusElement = document.getElementById('next-status-display') ||
                                 document.querySelector('.next-status');
        
        if (nextStatusElement && nextStatus) {
            nextStatusElement.innerHTML = `
                <strong>Следующий статус:</strong> ${nextStatus} (уровень ${nextLevel})<br>
                <small>${this.statusDescriptions[nextStatus] || ''}</small>
            `;
            nextStatusElement.style.display = 'block';
        }
    }
    
    /**
     * Получение максимального уровня из массива статусов
     */
    getUserMaxLevel(statuses) {
        if (!statuses || !Array.isArray(statuses)) {
            console.warn('⚠️ statuses не является массивом:', statuses);
            return 0;
        }
        
        let maxLevel = 0;
        statuses.forEach(status => {
            const level = this.statusLevelMap[status] || 0;
            if (level > maxLevel) maxLevel = level;
        });
        
        return maxLevel;
    }
    
    /**
     * Проверка, имеет ли пользователь глобальный статус
     */
    hasGlobalStatus(statusName) {
        return this.currentUser.global_status === statusName;
    }
    
    /**
     * Проверка, имеет ли пользователь минимальный уровень
     */
    hasMinLevel(minLevel) {
        return this.currentUser.max_level >= minLevel;
    }
    
    /**
     * Проверка роли в конкретном проекте
     */
    hasProjectRole(projectId, requiredRole) {
        const role = this.currentUser.project_roles[projectId];
        if (!role) return false;
        
        const roleHierarchy = {
            'member': 1,
            'curator': 2,
            'admin': 3,
            'leader': 4
        };
        
        const userLevel = roleHierarchy[role.role_type] || 0;
        const requiredLevel = roleHierarchy[requiredRole] || 0;
        
        return userLevel >= requiredLevel;
    }
    
    /**
     * Получение роли в проекте
     */
    getProjectRole(projectId) {
        return this.currentUser.project_roles[projectId];
    }
    
    /**
     * Проверка, является ли пользователь гостем
     */
    isGuest() {
        return this.currentUser.global_status === 'Гость' || !this.currentUser.actor_id;
    }
    
    /**
     * Проверка, является ли пользователь участником ТЦ
     */
    isTCMember() {
        return this.currentUser.max_level >= this.statusLevelMap['Участник ТЦ'];
    }
    
    /**
     * Проверка, является ли пользователь руководителем ТЦ
     */
    isTCLeader() {
        return this.currentUser.global_status === 'Руководитель ТЦ';
    }
    
    /**
     * Проверка, является ли пользователь куратором направления
     */
    isDirectionCurator() {
        return this.currentUser.global_status === 'Куратор направления';
    }
    
    /**
     * Получение текущих данных пользователя
     */
    getUserData() {
        return { ...this.currentUser };
    }
    
    /**
     * Обновление данных пользователя (после входа/выхода)
     */
    async updateUserData() {
        await this.loadCurrentUser();
        await this.updateUIByStatus();
    }
    
    /**
     * Сброс данных пользователя (выход)
     */
    resetUserData() {
        this.setGuestStatus();
        this.updateUIByStatus();
    }
}

// Создаем глобальный экземпляр
window.statusManager = new StatusManager();

// Автоматическая инициализация при загрузке DOM
document.addEventListener('DOMContentLoaded', () => {
    window.statusManager.init().catch(error => {
        console.error('Ошибка инициализации StatusManager:', error);
    });
});

// Экспортируем методы для глобального использования
window.hasGlobalStatus = (status) => window.statusManager.hasGlobalStatus(status);
window.hasProjectRole = (projectId, role) => window.statusManager.hasProjectRole(projectId, role);
window.isGuest = () => window.statusManager.isGuest();
window.isTCMember = () => window.statusManager.isTCMember();
window.isTCLeader = () => window.statusManager.isTCLeader();
window.getUserData = () => window.statusManager.getUserData();