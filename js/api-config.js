// Конфигурация API для фронтенда
const API_CONFIG = {
     BASE_URL: '/api',
    
    // Endpoints
    ENDPOINTS: {
        AUTH: {
            LOGIN: '/api/auth/login',
            REGISTER: '/api/auth/register',
            LOGOUT: '/api/auth/logout'
        },
        PROJECTS: {
            LIST: '/api/projects',
            CREATE: '/api/projects',
            DETAIL: (id) => `/api/projects/${id}`,
            UPDATE: (id) => `/api/projects/${id}`,
            DELETE: (id) => `/api/projects/${id}`
        },
        ACTORS: {
            LIST: '/api/actors',
            DETAIL: (id) => `/api/actors/${id}`
        }
    },
    
    // Функции для работы с API
    async request(endpoint, method = 'GET', data = null) {
        const token = localStorage.getItem('token');
        const url = this.BASE_URL + endpoint;
        
        const options = {
            method,
            headers: {
                'Content-Type': 'application/json',
                ...(token && { 'Authorization': `Bearer ${token}` })
            }
        };
        
        if (data) {
            options.body = JSON.stringify(data);
        }
        
        try {
            const response = await fetch(url, options);
            const result = await response.json();
            
            if (!response.ok) {
                throw new Error(result.error || 'API request failed');
            }
            
            return result;
        } catch (error) {
            console.error('API Error:', error);
            throw error;
        }
    },
    
    // Вспомогательные методы
    async login(email, password) {
        return this.request(this.ENDPOINTS.AUTH.LOGIN, 'POST', { email, password });
    },
    
    async register(userData) {
        return this.request(this.ENDPOINTS.AUTH.REGISTER, 'POST', userData);
    },
    
    async getProjects() {
        return this.request(this.ENDPOINTS.PROJECTS.LIST);
    },
    
    async getActors() {
        return this.request(this.ENDPOINTS.ACTORS.LIST);
    }
};

// Экспорт для использования в других файлах
window.API = API_CONFIG;