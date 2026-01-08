// Основной класс для работы с API
class ApiService {
    constructor() {
        this.baseURL = window.API_CONFIG?.BASE_URL || '/api';
        this.permissionErrorHandler = null;
    }
    
    setPermissionErrorHandler(handler) {
        this.permissionErrorHandler = handler;
    }
    
    async request(method, endpoint, data = null, params = null) {
        try {
            // Формируем URL
            let url = `${this.baseURL}${endpoint}`;
            
            // Добавляем параметры к URL для GET запросов
            if (params && method === 'GET') {
                const queryParams = new URLSearchParams(params).toString();
                url += `?${queryParams}`;
            }
            
            // Настройки запроса
            const options = {
                method: method,
                headers: {
                    'Content-Type': 'application/json',
                }
            };
            
            // Добавляем токен авторизации, если он есть
            const token = localStorage.getItem('auth_token');
            if (token) {
                options.headers['Authorization'] = `Bearer ${token}`;
            }
            
            // Добавляем тело запроса для не-GET запросов
            if (data && method !== 'GET') {
                options.body = JSON.stringify(data);
            }
            
            // Выполняем запрос
            const response = await fetch(url, options);
            
            // Обрабатываем ответ
            const responseData = await response.json().catch(() => ({}));
            
            if (!response.ok) {
                // Обработка ошибок прав доступа (403)
                if (response.status === 403) {
                    this.handlePermissionError(responseData, endpoint);
                }
                
                throw new Error(responseData.message || `HTTP error! status: ${response.status}`);
            }
            
            return responseData;
            
        } catch (error) {
            console.error('API request failed:', error);
            throw error;
        }
    }
    
    handlePermissionError(errorData, endpoint) {
        const errorMsg = errorData.message || 'Доступ запрещен';
        
        // Логируем ошибку прав
        console.warn(`Permission denied for ${endpoint}:`, errorMsg);
        
        // Показываем пользователю понятное сообщение
        const userMessage = this.formatPermissionError(errorMsg, errorData);
        
        // Если есть кастомный обработчик, вызываем его
        if (this.permissionErrorHandler) {
            this.permissionErrorHandler(errorData, endpoint);
        } else {
            // Дефолтная обработка - показываем alert
            this.showPermissionAlert(userMessage, errorData);
        }
    }
    
    formatPermissionError(errorMsg, errorData) {
        let message = `Недостаточно прав для выполнения действия.\n\n`;
        
        if (errorData.required_status) {
            message += `Требуемый статус: ${errorData.required_status}\n`;
        }
        
        if (errorData.required_role) {
            message += `Требуемая роль: ${errorData.required_role}\n`;
        }
        
        if (errorData.current_status) {
            message += `Ваш текущий статус: ${errorData.current_status}\n`;
        }
        
        message += `\nОперация: ${errorMsg}`;
        
        return message;
    }
    
    showPermissionAlert(message, errorData) {
        // Проверяем, не находимся ли мы уже на странице ошибки
        if (window.location.pathname.includes('error')) {
            return;
        }
        
        // Показываем alert только если это не фоновая операция
        if (!errorData.silent) {
            alert(message);
        }
        
        // Перенаправляем на соответствующую страницу в зависимости от типа ошибки
        this.redirectOnPermissionError(errorData);
    }
    
    redirectOnPermissionError(errorData) {
        const currentPath = window.location.pathname;
        
        // Если нет доступа к проекту, перенаправляем на список проектов
        if (currentPath.includes('/Project') && 
            (errorData.message?.includes('project') || errorData.required_role)) {
            window.location.href = '/pages/Projects.html';
        }
        
        // Если нет доступа к административным функциям, перенаправляем на главную
        else if (errorData.required_status?.includes('Руководитель') || 
                 errorData.required_status?.includes('Куратор')) {
            if (!currentPath.includes('index.html') && !currentPath.includes('Projects.html')) {
                window.location.href = '/index.html';
            }
        }
    }
    
    // Метод для проверки прав доступа к проекту
    async checkProjectPermission(projectId, requiredRole) {
        try {
            // Проверяем локальные права сначала
            if (window.currentUser && window.currentUser.project_roles) {
                const userRole = window.currentUser.project_roles[projectId];
                if (userRole) {
                    const roleHierarchy = {
                        'leader': 4,
                        'admin': 3,
                        'curator': 3,
                        'member': 2
                    };
                    
                    const userLevel = roleHierarchy[userRole.role_type] || 0;
                    const requiredLevel = roleHierarchy[requiredRole] || 0;
                    
                    if (userLevel >= requiredLevel) {
                        return true;
                    }
                }
            }
            
            // Если локальной проверки недостаточно, делаем запрос к серверу
            const response = await this.get(`/api/projects/${projectId}/permissions`, {
                required_role: requiredRole
            });
            
            return response.has_access || false;
            
        } catch (error) {
            console.error('Permission check failed:', error);
            return false;
        }
    }
    
    // Метод для проверки глобального статуса
    async checkGlobalStatus(requiredStatus) {
        try {
            // Проверяем локальные данные
            if (window.currentUser && window.currentUser.global_status === requiredStatus) {
                return true;
            }
            
            // Делаем запрос к серверу для точной проверки
            const response = await this.get('/api/auth/check-status', {
                required_status: requiredStatus
            });
            
            return response.has_status || false;
            
        } catch (error) {
            console.error('Status check failed:', error);
            return false;
        }
    }
    
    // Методы для удобства
    async get(endpoint, params = null) {
        return this.request('GET', endpoint, null, params);
    }
    
    async post(endpoint, data) {
        return this.request('POST', endpoint, data);
    }
    
    async put(endpoint, data) {
        return this.request('PUT', endpoint, data);
    }
    
    async delete(endpoint) {
        return this.request('DELETE', endpoint);
    }
}

// Создаем экземпляр для глобального использования
window.apiService = new ApiService();

// Устанавливаем обработчик ошибок прав по умолчанию
window.apiService.setPermissionErrorHandler((errorData, endpoint) => {
    console.warn('Permission error handled by default handler:', errorData);
});