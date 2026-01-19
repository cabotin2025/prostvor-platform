// js/config.js - УНИФИЦИРОВАННАЯ ВЕРСИЯ
(function() {
    'use strict';
    
    // Определяем базовый URL
    const getBaseUrl = () => {
        const hostname = window.location.hostname;
        const port = window.location.port;
        
        if (hostname === 'localhost' || hostname === '127.0.0.1') {
            return `http://${hostname}:${port || '8000'}`;
        }
        
        return 'http://creative-center.site';
    };
    
    const API_CONFIG = {
        BASE_URL: getBaseUrl(),
        TIMEOUT: 10000,
        DEBUG: true,
        
        // Структурированные endpoints
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
        
        // Основная функция запроса
        async request(endpoint, method = 'GET', data = null) {
            const url = `${this.BASE_URL}${endpoint}`;
            const token = localStorage.getItem('token');
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), this.TIMEOUT);
            
            try {
                const response = await fetch(url, {
                    method,
                    signal: controller.signal,
                    headers: {
                        'Accept': 'application/json',
                        'Content-Type': 'application/json',
                        ...(token && { 'Authorization': `Bearer ${token}` })
                    },
                    ...(data && { body: JSON.stringify(data) })
                });
                
                clearTimeout(timeoutId);
                
                // Проверяем, что ответ JSON
                const contentType = response.headers.get('content-type');
                if (!contentType || !contentType.includes('application/json')) {
                    throw new Error(`Ожидался JSON, но получен: ${contentType}`);
                }
                
                const result = await response.json();
                
                if (!response.ok) {
                    throw new Error(result.error || 'API request failed');
                }
                
                return result;
                
            } catch (error) {
                clearTimeout(timeoutId);
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
    
    // Экспорт для глобального использования
    window.API = API_CONFIG;
    console.log('🌐 API Config loaded:', window.API);
})();