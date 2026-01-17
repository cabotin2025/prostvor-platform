// js/config.js - ФИНАЛЬНАЯ ВЕРСИЯ
(function() {
    'use strict';
    
    // Определяем базовый URL
    const getBaseUrl = () => {
        const hostname = window.location.hostname;
        const port = window.location.port;
        
        // Локальная разработка
        if (hostname === 'localhost' || hostname === '127.0.0.1') {
            return `http://${hostname}:${port || '8000'}/api`;
        }
        
        // Продакшен
        return 'http://creative-center.site/api';
    };
    
    window.API_CONFIG = {
        BASE_URL: getBaseUrl(),
        TIMEOUT: 10000,
        DEBUG: true
    };
    
    console.log('🌐 API Config loaded:', window.API_CONFIG);
    
    // Глобальная функция для API вызовов
    window.prostvorAPI = {
        async request(endpoint, options = {}) {
            const url = `${API_CONFIG.BASE_URL}${endpoint}`;
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), API_CONFIG.TIMEOUT);
            
            try {
                const response = await fetch(url, {
                    ...options,
                    signal: controller.signal,
                    headers: {
                        'Accept': 'application/json',
                        'Content-Type': 'application/json',
                        ...options.headers
                    }
                });
                
                clearTimeout(timeoutId);
                
                // Проверяем, что ответ JSON
                const contentType = response.headers.get('content-type');
                if (!contentType || !contentType.includes('application/json')) {
                    throw new Error(`Ожидался JSON, но получен: ${contentType}`);
                }
                
                return await response.json();
                
            } catch (error) {
                clearTimeout(timeoutId);
                console.error('API Error:', error);
                throw error;
            }
        }
    };
})();