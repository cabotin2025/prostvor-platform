// /js/requests_manager.js - Полный менеджер запросов ресурсов
// Интегрирован с API, авторизацией и уведомлениями

const RequestsManager = (function() {
    // Конфигурация API
    const API_ENDPOINT = '/api/requests';

    // Соответствие статусов UI и БД
    const STATUS_MAP = {
        'active': 'действующий',
        'suspended': 'приостановлен',
        'cancelled': 'отменён',
        'completed': 'завершён'
    };

    // Типы ресурсов для UI
    const RESOURCE_TYPES = {
        'venue': 'Локация',
        'matresource': 'Материальный ресурс',
        'finresource': 'Финансовый ресурс',
        'service': 'Услуга',
        'idea': 'Идея',
        'function': 'Функция'
    };

    // Приватное состояние
    let currentRequestId = null;
    let requestsCache = new Map();
    let refreshInterval = null;

    // ==================== ПУБЛИЧНЫЙ API ====================

    return {
        /**
         * Инициализация менеджера (вызывается при загрузке страницы)
         */
        init: function() {
            console.log('🚀 RequestsManager инициализирован');
            this.setupAutoRefresh();
            this.bindGlobalEvents();
            this.checkForExpiredRequests();
        },

        /**
         * Создание нового запроса
         * @param {Object} requestData - Данные запроса
         */
        createRequest: async function(requestData) {
            try {
                console.log('📝 Создание запроса:', requestData);

                // Автоматически заполняем недостающие поля
                const enrichedData = this.enrichRequestData(requestData);

                // Отправляем запрос через глобальный ApiService
                const response = await window.apiService.post(`${API_ENDPOINT}/index.php`, enrichedData);

                if (response.success) {
                    console.log('✅ Запрос создан:', response.data);
                    
                    // Кэшируем созданный запрос
                    requestsCache.set(response.data.request_id, response.data);
                    
                    // Показываем уведомление о разных локациях (если есть)
                    if (response.notification) {
                        this.showLocationNotification(response.notification);
                    }
                    
                    // Обновляем UI
                    this.dispatchEvent('request-created', response.data);
                    
                    return response.data;
                } else {
                    throw new Error(response.message || 'Ошибка создания запроса');
                }
            } catch (error) {
                console.error('❌ Ошибка создания запроса:', error);
                this.showError('Не удалось создать запрос', error.message);
                throw error;
            }
        },

        /**
         * Получение информации о запросе
         */
        getRequest: async function(requestId) {
            // Проверяем кэш
            if (requestsCache.has(requestId)) {
                return requestsCache.get(requestId);
            }

            try {
                const response = await window.apiService.get(`${API_ENDPOINT}/index.php`, { 
                    request_id: requestId 
                });

                if (response.success) {
                    requestsCache.set(requestId, response.data);
                    return response.data;
                }
            } catch (error) {
                console.error('Ошибка получения запроса:', error);
            }
            return null;
        },

        /**
         * Обновление статуса запроса (универсальный метод)
         */
        updateRequestStatus: async function(requestId, newStatus, reason = '') {
            try {
                // Проверяем права доступа
                const canUpdate = await this.checkUpdatePermission(requestId, newStatus);
                if (!canUpdate) {
                    throw new Error('Недостаточно прав для изменения статуса');
                }

                const response = await window.apiService.post(`${API_ENDPOINT}/update_status.php`, {
                    request_id: requestId,
                    new_status: newStatus,
                    reason: reason,
                    update_date: new Date().toISOString()
                });

                if (response.success) {
                    console.log(`✅ Статус запроса ${requestId} изменен на "${newStatus}"`);
                    
                    // Обновляем кэш
                    const updatedRequest = { ...response.data, request_status: newStatus };
                    requestsCache.set(requestId, updatedRequest);
                    
                    // Отправляем событие
                    this.dispatchEvent('request-status-updated', {
                        request_id: requestId,
                        old_status: response.data.old_status,
                        new_status: newStatus,
                        reason: reason
                    });
                    
                    return response.data;
                }
            } catch (error) {
                console.error('Ошибка обновления статуса:', error);
                this.showError('Ошибка изменения статуса', error.message);
                throw error;
            }
        },

        /**
         * Отмена запроса (с обработкой удаления через 1 минуту)
         */
        cancelRequest: async function(requestId, reason = 'Отменен пользователем') {
            try {
                const result = await this.updateRequestStatus(requestId, 'cancelled', reason);
                
                if (result) {
                    // Запускаем таймер для визуального отсчета удаления
                    this.startDeletionTimer(requestId);
                    
                    // Показываем подтверждение пользователю
                    this.showNotification(
                        'Запрос отменен',
                        'Запрос будет полностью удален через 1 минуту. Данные сохранены в статистике.',
                        'info'
                    );
                }
                return result;
            } catch (error) {
                throw error;
            }
        },

        /**
         * Приостановка запроса
         */
        suspendRequest: async function(requestId, reason = '') {
            return this.updateRequestStatus(requestId, 'suspended', reason);
        },

        /**
         * Возобновление запроса (из приостановленного в действующий)
         */
        resumeRequest: async function(requestId) {
            return this.updateRequestStatus(requestId, 'active', 'Возобновлен пользователем');
        },

        /**
         * Отметка запроса как завершенного (при создании договора)
         */
        completeRequest: async function(requestId, contractId) {
            return this.updateRequestStatus(requestId, 'completed', `Договор №${contractId}`);
        },

        /**
         * Получение списка запросов с фильтрацией
         */
        getRequests: async function(filters = {}) {
            try {
                const response = await window.apiService.get(`${API_ENDPOINT}/index.php`, filters);
                
                if (response.success) {
                    // Кэшируем все полученные запросы
                    response.data.forEach(request => {
                        requestsCache.set(request.request_id, request);
                    });
                    return response.data;
                }
                return [];
            } catch (error) {
                console.error('Ошибка получения списка запросов:', error);
                return [];
            }
        },

        /**
         * Проверка истекших запросов (по validity_period)
         */
        checkForExpiredRequests: async function() {
            try {
                const response = await window.apiService.get(`${API_ENDPOINT}/index.php`, {
                    check_expired: true
                });
                
                if (response.success && response.data.expired_requests > 0) {
                    console.log(`⚠️ Найдено ${response.data.expired_requests} просроченных запросов`);
                }
            } catch (error) {
                console.error('Ошибка проверки просроченных запросов:', error);
            }
        },

        /**
         * Проверка прав на обновление статуса
         */
        checkUpdatePermission: async function(requestId, newStatus) {
            // Для простых операций (отмена, приостановка самим создателем)
            // проверяем локально через authPermissions
            
            const request = await this.getRequest(requestId);
            if (!request) return false;

            const currentUser = window.authPermissions?.currentUser;
            if (!currentUser) return false;

            // Создатель запроса может отменять/приостанавливать свои запросы
            if (request.requester_id === currentUser.actor_id) {
                return ['cancelled', 'suspended', 'active'].includes(newStatus);
            }

            // Руководители/администраторы проектов могут менять статусы связанных запросов
            if (request.project_id && window.authPermissions.hasProjectRole) {
                const requiredRole = newStatus === 'cancelled' ? 'admin' : 'leader';
                return window.authPermissions.hasProjectRole(request.project_id, requiredRole);
            }

            return false;
        },

        // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

        /**
         * Обогащение данных запроса перед отправкой
         */
        enrichRequestData: function(requestData) {
            const enriched = { ...requestData };
            const currentUser = window.authPermissions?.currentUser || window.currentUser;
            
            // Автоматически заполняем поля, если они не указаны
            if (!enriched.requester_id && currentUser) {
                enriched.requester_id = currentUser.actor_id;
            }
            
            if (!enriched.location_id && currentUser?.locality_id) {
                enriched.location_id = currentUser.locality_id;
            }
            
            // Преобразуем resource_type в request_type_id если нужно
            if (enriched.resource_type && !enriched.request_type_id) {
                // Здесь должна быть логика преобразования
                // Пока оставляем как есть, бэкенд обработает
            }
            
            // Устанавливаем дефолтный статус
            if (!enriched.request_status) {
                enriched.request_status = 'active';
            }
            
            return enriched;
        },

        /**
         * Таймер для визуализации удаления отмененного запроса
         */
        startDeletionTimer: function(requestId) {
            const timerElement = document.querySelector(`[data-request-id="${requestId}"] .deletion-timer`);
            if (!timerElement) return;

            let secondsLeft = 60;
            
            const interval = setInterval(() => {
                secondsLeft--;
                timerElement.textContent = `Удаление через ${secondsLeft}с`;
                timerElement.style.display = 'block';
                
                if (secondsLeft <= 0) {
                    clearInterval(interval);
                    timerElement.textContent = 'Запрос удален';
                    
                    // Удаляем элемент из UI через 2 секунды
                    setTimeout(() => {
                        const requestElement = document.querySelector(`[data-request-id="${requestId}"]`);
                        if (requestElement) {
                            requestElement.style.opacity = '0.5';
                            setTimeout(() => requestElement.remove(), 1000);
                        }
                    }, 2000);
                }
            }, 1000);
        },

        /**
         * Автоматическое обновление статусов (для фоновой проверки)
         */
        setupAutoRefresh: function() {
            // Обновляем статусы каждые 30 секунд (для демонстрации)
            // В реальности это может быть реже или по событию
            if (refreshInterval) clearInterval(refreshInterval);
            
            refreshInterval = setInterval(() => {
                this.checkForExpiredRequests();
                
                // Проверяем изменения статусов проектов/событий
                this.checkDependentStatuses();
            }, 30000); // 30 секунд
        },

        /**
         * Проверка статусов связанных проектов/событий
         */
        checkDependentStatuses: async function() {
            // Эта логика будет на бэкенде, но можно сделать и предварительную проверку
            console.log('🔄 Проверка зависимых статусов...');
        },

        /**
         * Показ уведомления о разных локациях
         */
        showLocationNotification: function(notification) {
            if (!notification || !notification.show) return;
            
            const confirmMessage = 
                `⚠️ Внимание! Владелец ресурса находится в другом населенном пункте.\n\n` +
                `Ваша локация: ${notification.requester_location}\n` +
                `Локация владельца: ${notification.owner_location}\n\n` +
                `Вы хотите продолжить создание запроса?`;
            
            if (confirm(confirmMessage)) {
                // Пользователь подтвердил - запрос будет создан
                return true;
            } else {
                // Пользователь отменил - выбрасываем ошибку
                throw new Error('Пользователь отменил запрос из-за разных локаций');
            }
        },

        /**
         * Универсальный показ ошибок
         */
        showError: function(title, message) {
            console.error(`${title}: ${message}`);
            
            // Используем существующую систему уведомлений или стандартный alert
            if (window.showNotification) {
                window.showNotification(`${title}: ${message}`, 'error');
            } else {
                alert(`${title}\n\n${message}`);
            }
        },

        /**
         * Показ уведомлений
         */
        showNotification: function(title, message, type = 'info') {
            console.log(`[${type.toUpperCase()}] ${title}: ${message}`);
            
            // Интеграция с существующей системой уведомлений
            if (window.showNotification) {
                window.showNotification(message, type);
            } else if (type === 'error') {
                alert(`❌ ${title}\n\n${message}`);
            } else {
                alert(`✅ ${title}\n\n${message}`);
            }
        },

        /**
         * Диспетчер событий для обновления UI
         */
        dispatchEvent: function(eventName, detail) {
            const event = new CustomEvent(`requests:${eventName}`, { 
                detail,
                bubbles: true 
            });
            document.dispatchEvent(event);
        },

        /**
         * Привязка глобальных событий
         */
        bindGlobalEvents: function() {
            // Реагируем на изменение статуса проекта
            document.addEventListener('project-status-changed', (e) => {
                this.handleProjectStatusChange(e.detail);
            });
            
            // Реагируем на изменение статуса события
            document.addEventListener('event-status-changed', (e) => {
                this.handleEventStatusChange(e.detail);
            });
            
            // Реагируем на выход пользователя
            document.addEventListener('user-logged-out', () => {
                this.clearCache();
            });
        },

        /**
         * Обработка изменения статуса проекта
         */
        handleProjectStatusChange: async function(projectData) {
            console.log('📊 Изменен статус проекта:', projectData);
            
            // Эта логика в основном на бэкенде, но можно обновить UI
            const requests = await this.getRequests({ project_id: projectData.project_id });
            
            requests.forEach(request => {
                this.dispatchEvent('request-auto-updated', {
                    request_id: request.request_id,
                    reason: `Изменен статус проекта на "${projectData.new_status}"`
                });
            });
        },

        /**
         * Обработка изменения статуса события
         */
        handleEventStatusChange: async function(eventData) {
            console.log('📊 Изменен статус события:', eventData);
            
            const requests = await this.getRequests({ event_id: eventData.event_id });
            
            requests.forEach(request => {
                this.dispatchEvent('request-auto-updated', {
                    request_id: request.request_id,
                    reason: `Изменен статус события на "${eventData.new_status}"`
                });
            });
        },

        /**
         * Очистка кэша
         */
        clearCache: function() {
            requestsCache.clear();
            if (refreshInterval) {
                clearInterval(refreshInterval);
                refreshInterval = null;
            }
            console.log('🧹 Кэш запросов очищен');
        }
    };
})();

// Автоматическая инициализация при загрузке страницы
document.addEventListener('DOMContentLoaded', function() {
    if (window.apiService && window.authPermissions) {
        // Даем время инициализироваться другим модулям
        setTimeout(() => {
            RequestsManager.init();
            console.log('✅ RequestsManager автоматически инициализирован');
        }, 1000);
    } else {
        console.warn('⚠️ RequestsManager: apiService или authPermissions не найдены');
    }
});

// Экспорт для глобального использования
window.RequestsManager = RequestsManager;