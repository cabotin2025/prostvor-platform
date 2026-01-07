/**
 * Prostvor Platform API Service
 * Версия 1.0 - Работает с существующим фронтендом без изменений
 */

class ProstvorApi {
    constructor() {
        // Базовый URL API - ваш локальный сервер
        this.BASE_URL = window.location.origin;
        this.token = localStorage.getItem('prostvor_token');
        this.user = null;
        
        // Восстанавливаем пользователя из localStorage
        try {
            const userData = localStorage.getItem('prostvor_user');
            this.user = userData ? JSON.parse(userData) : null;
        } catch (e) {
            console.error('Error parsing user data:', e);
            this.user = null;
        }
        
        console.log('Prostvor API initialized. Base URL:', this.BASE_URL);
        
        // Автоматически проверяем токен при инициализации
        this.checkTokenValidity();
    }
    
    // ==================== ОСНОВНЫЕ МЕТОДЫ ====================
    
    /**
     * Универсальный метод для API запросов
     */
    async request(endpoint, method = 'GET', data = null, options = {}) {
        const url = this.BASE_URL + '/api' + endpoint;
        const headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            ...options.headers
        };
        
        // Добавляем токен если есть
        if (this.token) {
            headers['Authorization'] = `Bearer ${this.token}`;
        }
        
        const config = {
            method,
            headers,
            mode: 'cors',
            credentials: 'include',
            ...options
        };
        
        if (data && ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
            config.body = JSON.stringify(data);
        }
        
        try {
            const response = await fetch(url, config);
            
            // Обработка ошибок HTTP
            if (!response.ok) {
                const errorData = await response.text();
                let errorMessage = `HTTP ${response.status}`;
                
                try {
                    const errorJson = JSON.parse(errorData);
                    errorMessage = errorJson.error || errorJson.message || errorMessage;
                } catch (e) {
                    errorMessage = errorData.substring(0, 100) || errorMessage;
                }
                
                // Особые случаи
                if (response.status === 401) {
                    // Неавторизован - очищаем данные
                    this.clearAuth();
                    throw new Error('Сессия истекла. Пожалуйста, войдите снова.');
                }
                
                if (response.status === 403) {
                    throw new Error('Доступ запрещен');
                }
                
                if (response.status === 404) {
                    throw new Error('Ресурс не найден');
                }
                
                throw new Error(errorMessage);
            }
            
            // Парсим ответ
            const result = await response.json();
            return result;
            
        } catch (error) {
            console.error('API Request Error:', error);
            throw error;
        }
    }
    
    // ==================== АУТЕНТИФИКАЦИЯ ====================
    
    /**
     * Вход в систему
     */
    async login(email, password) {
        try {
            const result = await this.request('/auth/login', 'POST', {
                email,
                password
            });
            
            if (result.success && result.token) {
                // Сохраняем токен и данные пользователя
                this.token = result.token;
                this.user = result.user;
                
                localStorage.setItem('prostvor_token', result.token);
                localStorage.setItem('prostvor_user', JSON.stringify(result.user));
                
                // Вызываем событие об успешном входе
                this.dispatchAuthEvent('login', result.user);
                
                return result;
            } else {
                throw new Error(result.error || 'Ошибка входа');
            }
        } catch (error) {
            console.error('Login error:', error);
            throw error;
        }
    }
    
    /**
     * Регистрация нового пользователя
     */
    async register(userData) {
        return await this.request('/auth/register', 'POST', userData);
    }
    
    /**
     * Выход из системы
     */
    logout() {
        this.clearAuth();
        
        // Пытаемся сообщить серверу о выходе
        try {
            this.request('/auth/logout', 'POST').catch(() => {});
        } catch (e) {
            // Игнорируем ошибки при выходе
        }
        
        this.dispatchAuthEvent('logout');
        
        // Перенаправляем на страницу входа
        setTimeout(() => {
            if (window.location.pathname !== '/pages/enter-reg.html') {
                window.location.href = '/pages/enter-reg.html';
            }
        }, 100);
    }
    
    /**
     * Проверка валидности токена
     */
    async checkTokenValidity() {
        if (!this.token) return false;
        
        try {
            const result = await this.request('/test-auth', 'GET');
            return result.token_present === true;
        } catch (error) {
            console.log('Token validation failed:', error.message);
            this.clearAuth();
            return false;
        }
    }
    
    /**
     * Проверка авторизации
     */
    isAuthenticated() {
        return !!this.token && !!this.user;
    }
    
    /**
     * Получение текущего пользователя
     */
    getCurrentUser() {
        return this.user;
    }
    
    // ==================== ПРОЕКТЫ ====================
    
    async getProjects(filters = {}) {
        let endpoint = '/projects';
        if (Object.keys(filters).length > 0) {
            const params = new URLSearchParams(filters);
            endpoint += '?' + params.toString();
        }
        return await this.request(endpoint);
    }
    
    async getProject(id) {
        return await this.request(`/projects/${id}`);
    }
    
    async createProject(projectData) {
        return await this.request('/projects', 'POST', projectData);
    }
    
    async updateProject(id, projectData) {
        return await this.request(`/projects/${id}`, 'PUT', projectData);
    }
    
    async deleteProject(id) {
        return await this.request(`/projects/${id}`, 'DELETE');
    }
    
    // ==================== УЧАСТНИКИ ====================
    
    async getActors(filters = {}) {
        let endpoint = '/actors';
        if (Object.keys(filters).length > 0) {
            const params = new URLSearchParams(filters);
            endpoint += '?' + params.toString();
        }
        return await this.request(endpoint);
    }
    
    async getActor(id) {
        return await this.request(`/actors/${id}`);
    }
    
    // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================
    
    /**
     * Очистка данных авторизации
     */
    clearAuth() {
        this.token = null;
        this.user = null;
        localStorage.removeItem('prostvor_token');
        localStorage.removeItem('prostvor_user');
    }
    
    /**
     * Генерация события авторизации
     */
    dispatchAuthEvent(type, data = null) {
        const event = new CustomEvent('prostvor-auth', {
            detail: { type, data, timestamp: Date.now() }
        });
        window.dispatchEvent(event);
    }
    
    /**
     * Тест подключения к API
     */
    async testConnection() {
        try {
            const result = await this.request('/test');
            return {
                success: true,
                message: 'API подключен успешно',
                data: result
            };
        } catch (error) {
            return {
                success: false,
                message: 'Ошибка подключения к API',
                error: error.message
            };
        }
    }
}

// Создаем глобальный экземпляр API
console.log('Initializing Prostvor Platform API...');
window.prostvorAPI = new ProstvorApi();

// Экспортируем для использования в модулях
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { ProstvorApi };
}