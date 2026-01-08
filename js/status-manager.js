// js/status-manager.js - Управление статусами пользователя
console.log('📊 Status Manager загружен');

const StatusManager = {
    // Основные статусы из БД (должны соответствовать actor_statuses)
    STATUSES: {
        // Базовые статусы
        1: { id: 1, name: 'Участник ТЦ', level: 1 },
        2: { id: 2, name: 'Участник проекта', level: 2 },
        3: { id: 3, name: 'Исполнитель', level: 3 },
        4: { id: 4, name: 'Ответственный исполнитель', level: 4 },
        5: { id: 5, name: 'Руководитель проекта', level: 5 },
        6: { id: 6, name: 'Проектный куратор', level: 6 },
        7: { id: 7, name: 'Руководитель ТЦ', level: 7 },
        8: { id: 8, name: 'Администратор', level: 8 }
    },
    
    // Права для каждого уровня
    PERMISSIONS_BY_LEVEL: {
        1: ['view', 'comment', 'participate'], // Участник ТЦ
        2: ['view', 'comment', 'participate'], // Участник проекта
        3: ['view', 'comment', 'participate', 'execute-tasks'], // Исполнитель
        4: ['view', 'comment', 'participate', 'execute-tasks', 'manage-tasks'], // Ответственный исполнитель
        5: ['view', 'comment', 'participate', 'create-projects', 'manage-own-projects'], // Руководитель проекта
        6: ['view', 'comment', 'participate', 'create-projects', 'manage-any-projects', 'create-events'], // Проектный куратор
        7: ['view', 'comment', 'participate', 'create-projects', 'manage-any-projects', 'create-events', 'manage-users'], // Руководитель ТЦ
        8: ['all'] // Администратор
    },
    
    // Кэш статусов пользователя
    userStatusesCache: {},
    
    // Получение ВСЕХ статусов пользователя из API
    async fetchUserStatuses(actorId) {
        try {
            console.log(`📡 Запрашиваю статусы для пользователя ${actorId}...`);
            
            // Запрос к API для получения всех статусов
            const response = await fetch(`/api/actors/${actorId}/statuses`, {
                headers: {
                    'Authorization': `Bearer ${localStorage.getItem('prostvor_token')}`
                }
            });
            
            if (response.ok) {
                const data = await response.json();
                this.userStatusesCache[actorId] = data.statuses || [];
                console.log(`✅ Получены статусы:`, data.statuses);
                return data.statuses;
            } else {
                console.warn('⚠️ API статусов недоступно, использую fallback');
                return this.getFallbackStatuses(actorId);
            }
        } catch (error) {
            console.error('❌ Ошибка получения статусов:', error);
            return this.getFallbackStatuses(actorId);
        }
    },
    
    // Fallback - получение статусов из localStorage
    getFallbackStatuses(actorId) {
        const user = this.getCurrentUser();
        if (!user) return [];
        
        // Пробуем получить из user.additional_statuses
        if (user.additional_statuses && Array.isArray(user.additional_statuses)) {
            return user.additional_statuses;
        }
        
        // Или создаем на основе основного статуса
        const mainStatus = user.status || 'Участник ТЦ';
        return [mainStatus];
    },
    
    // Получение текущего пользователя
    getCurrentUser() {
        const userStr = localStorage.getItem('prostvor_user') || sessionStorage.getItem('prostvor_user');
        if (!userStr) return null;
        
        try {
            return JSON.parse(userStr);
        } catch (e) {
            console.error('Ошибка парсинга пользователя:', e);
            return null;
        }
    },
    
    // Получение ВСЕХ статусов текущего пользователя
    async getUserAllStatuses() {
        const user = this.getCurrentUser();
        if (!user || !user.actor_id) return [];
        
        // Проверяем кэш
        if (this.userStatusesCache[user.actor_id]) {
            return this.userStatusesCache[user.actor_id];
        }
        
        // Запрашиваем с API
        return await this.fetchUserStatuses(user.actor_id);
    },
    
    // Получение МАКСИМАЛЬНОГО уровня пользователя
    async getUserMaxLevel() {
        const statuses = await this.getUserAllStatuses();
        let maxLevel = 1; // Минимальный по умолчанию
        
        statuses.forEach(statusName => {
            // Находим статус по имени
            const status = Object.values(this.STATUSES).find(s => s.name === statusName);
            if (status && status.level > maxLevel) {
                maxLevel = status.level;
            }
        });
        
        console.log(`📊 Максимальный уровень пользователя: ${maxLevel}`);
        return maxLevel;
    },
    
    // Проверка прав на основе максимального уровня
    async hasPermission(requiredPermission) {
        const maxLevel = await this.getUserMaxLevel();
        const userPermissions = this.PERMISSIONS_BY_LEVEL[maxLevel] || [];
        
        // Разрешаем если есть право 'all' или конкретное право
        return userPermissions.includes('all') || userPermissions.includes(requiredPermission);
    },
    
    // Проверка минимального уровня
    async hasMinLevel(minLevel) {
        const maxLevel = await this.getUserMaxLevel();
        return maxLevel >= minLevel;
    },
    
    // Проверка конкретного статуса
    async hasStatus(statusName) {
        const statuses = await this.getUserAllStatuses();
        return statuses.includes(statusName);
    },
    
    // Обновление UI на основе статусов
    async updateUIByStatus() {
        console.log('🎯 Обновляю UI на основе статусов...');
        
        const user = this.getCurrentUser();
        const statuses = await this.getUserAllStatuses();
        const maxLevel = await this.getUserMaxLevel();
        
        console.log('👤 Пользователь:', user ? user.nickname : 'нет');
        console.log('📋 Все статусы:', statuses);
        console.log('📊 Максимальный уровень:', maxLevel);
        
        // 1. Обновляем информацию о статусах в интерфейсе
        this.displayUserStatuses(statuses);
        
        // 2. Обновляем доступ к элементам меню
        await this.updateMenuAccess();
        
        // 3. Показываем возможности повышения статуса
        this.showStatusUpgradeOptions(maxLevel);
    },
    
    // Отображение статусов пользователя
    displayUserStatuses(statuses) {
        const container = document.getElementById('userStatusesContainer');
        if (!container) {
            // Создаем контейнер если его нет
            const userInfo = document.querySelector('.user-info, .header-user');
            if (userInfo) {
                const newContainer = document.createElement('div');
                newContainer.id = 'userStatusesContainer';
                newContainer.className = 'user-statuses';
                newContainer.style.cssText = `
                    margin-top: 5px;
                    font-size: 12px;
                    color: #666;
                `;
                userInfo.appendChild(newContainer);
            }
        }
        
        // Обновляем содержимое
        const statusContainer = document.getElementById('userStatusesContainer');
        if (statusContainer && statuses.length > 0) {
            statusContainer.innerHTML = `
                <div>Статусы: ${statuses.join(', ')}</div>
                <div style="font-size: 11px; color: #888;">
                    (Уровень доступа: ${maxLevel})
                </div>
            `;
        }
    },
    
    // Обновление доступа к меню
    async updateMenuAccess() {
        // Правила доступа для элементов меню
        const accessRules = {
            // Проекты
            'Создать новый Проект': { minLevel: 5, permission: 'create-projects' },
            'Мои проекты': { minLevel: 2, permission: 'view' }, // Участник проекта и выше
            
            // Идеи
            'Предложить Идею': { minLevel: 1, permission: 'comment' }, // Все участники
            
            // События
            'Создать Событие': { minLevel: 6, permission: 'create-events' },
            'Календарь событий': { minLevel: 1, permission: 'view' },
            
            // Ресурсы
            'Предложить ресурс': { minLevel: 1, permission: 'comment' },
            
            // Услуги
            'Предложить Услуги': { minLevel: 1, permission: 'comment' },
            'Запросить Услуги': { minLevel: 3, permission: 'execute-tasks' }, // Исполнитель и выше
            
            // Темы
            'Создать Тему': { minLevel: 1, permission: 'comment' },
            
            // Участники
            'Поиск участников': { minLevel: 1, permission: 'view' },
            'Руководители и Кураторы': { minLevel: 5, permission: 'view' }
        };
        
        // Обрабатываем элементы меню
        document.querySelectorAll('.dropdown-item, .nav-link').forEach(async (item) => {
            const text = item.textContent.trim();
            const rule = accessRules[text];
            
            if (rule) {
                const hasAccess = await this.checkAccess(rule);
                
                if (!hasAccess) {
                    this.disableMenuItem(item, rule);
                } else {
                    this.enableMenuItem(item);
                }
            }
        });
    },
    
    // Проверка доступа по правилу
    async checkAccess(rule) {
        if (rule.minLevel && !(await this.hasMinLevel(rule.minLevel))) {
            return false;
        }
        
        if (rule.permission && !(await this.hasPermission(rule.permission))) {
            return false;
        }
        
        return true;
    },
    
    // Отключение элемента меню
    disableMenuItem(item, rule) {
        item.style.opacity = '0.5';
        item.style.pointerEvents = 'none';
        item.style.cursor = 'not-allowed';
        
        // Сообщение в зависимости от правила
        let message = '';
        if (rule.minLevel) {
            const requiredStatus = Object.values(this.STATUSES).find(s => s.level === rule.minLevel);
            message = `Требуется статус: ${requiredStatus ? requiredStatus.name : `уровень ${rule.minLevel}`}`;
        } else {
            message = 'Недостаточно прав';
        }
        
        item.title = message;
        
        // Блокируем действие
        item.onclick = function(e) {
            e.preventDefault();
            e.stopPropagation();
            alert(message + '\n\nДля получения доступа обратитесь к руководителю проекта или куратору.');
            return false;
        };
        
        console.log(`🔒 Заблокировано: "${item.textContent.trim()}" - ${message}`);
    },
    
    // Включение элемента меню
    enableMenuItem(item) {
        item.style.opacity = '1';
        item.style.pointerEvents = 'auto';
        item.style.cursor = 'pointer';
        item.title = '';
        item.onclick = null;
    },
    
    // Показ возможностей повышения статуса
    showStatusUpgradeOptions(currentLevel) {
        const nextLevel = currentLevel + 1;
        const nextStatus = Object.values(this.STATUSES).find(s => s.level === nextLevel);
        
        if (nextStatus) {
            console.log(`⬆️ Следующий доступный статус: ${nextStatus.name} (уровень ${nextLevel})`);
            
            // Можно показать подсказку пользователю
            if (currentLevel < 5) { // Если не руководитель проекта
                const upgradeHint = document.createElement('div');
                upgradeHint.id = 'statusUpgradeHint';
                upgradeHint.style.cssText = `
                    position: fixed;
                    bottom: 20px;
                    right: 20px;
                    background: #f8f9fa;
                    border: 1px solid #dee2e6;
                    border-radius: 5px;
                    padding: 10px 15px;
                    font-size: 12px;
                    max-width: 300px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                    z-index: 9999;
                `;
                upgradeHint.innerHTML = `
                    <strong>🎯 Повышение статуса</strong><br>
                    Для доступа к дополнительным функциям нужен статус <strong>${nextStatus.name}</strong>.<br>
                    <small>Обратитесь к руководителю вашего проекта.</small>
                `;
                
                document.body.appendChild(upgradeHint);
                
                // Автоудаление через 10 секунд
                setTimeout(() => {
                    if (upgradeHint.parentNode) {
                        upgradeHint.remove();
                    }
                }, 10000);
            }
        }
    },
    
    // Обновление статусов периодически
    startAutoRefresh(interval = 300000) { // 5 минут
        setInterval(async () => {
            const user = this.getCurrentUser();
            if (user && user.actor_id) {
                console.log('🔄 Автообновление статусов...');
                await this.fetchUserStatuses(user.actor_id);
                await this.updateUIByStatus();
            }
        }, interval);
    },
    
    // Инициализация
    init() {
        console.log('📊 Инициализация менеджера статусов');
        
        // Обновляем UI при загрузке
        document.addEventListener('DOMContentLoaded', async () => {
            await this.updateUIByStatus();
        });
        
        // Обновляем при изменении пользователя
        window.addEventListener('storage', async (e) => {
            if (e.key === 'prostvor_user') {
                setTimeout(async () => {
                    await this.updateUIByStatus();
                }, 500);
            }
        });
        
        // Запускаем автообновление
        this.startAutoRefresh();
        
        // Делаем глобально доступным
        window.StatusManager = this;
        
        console.log('✅ Менеджер статусов инициализирован');
    }
};

// Автоматическая инициализация
StatusManager.init();