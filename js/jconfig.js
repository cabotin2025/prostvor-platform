// js/config.js
const APP_CONFIG = {
    API: {
        // Ваш PHP-сервер (измените порт если нужно)
        BASE_URL: 'http://localhost',
        // Или если PHP на отдельном порту: 'http://localhost:8000'
        ENDPOINTS: {
            AUTH: {
                LOGIN: '/api/auth/login.php',
                REGISTER: '/api/auth/register.php',
                LOGOUT: '/api/auth/logout.php'
            },
            PROJECTS: '/api/projects/index.php',
            ACTORS: '/api/actors/index.php'
        }
    },
    STORAGE_KEYS: {
        TOKEN: 'prostvor_token',
        USER: 'prostvor_user'
    }
};

window.APP_CONFIG = APP_CONFIG;