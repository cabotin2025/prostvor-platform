// main-updated.js - ИСПРАВЛЕННАЯ ВЕРСИЯ
console.log('main-updated.js: Загружен');

// Объявляем переменную ДО использования
let AppUpdated;

// Проверяем, не находимся ли на странице входа
if (window.location.pathname.includes('enter-reg.html')) {
    console.log('main-updated.js: Пропускаем инициализацию на странице входа');
    
    // Минимальный заглушечный класс для совместимости
    AppUpdated = class {
        constructor() {}
        init() { console.log('AppUpdated: заглушка для enter-reg.html'); }
        static refreshAuthState() { console.log('refreshAuthState: заглушка'); }
    };
    
    // Экспортируем для других скриптов
    window.AppUpdated = AppUpdated;
    
} else {
    // Полная версия для других страниц
    AppUpdated = class {
        constructor() {
            console.log('AppUpdated инициализирован');
            this.initialized = false;
        }
        
        init() {
            if (this.initialized) return;
            console.log('AppUpdated init');
            
            // Ваш существующий код инициализации
            this.setupEventListeners();
            this.loadInitialData();
            
            this.initialized = true;
        }
        
        setupEventListeners() {
            console.log('AppUpdated: настройка обработчиков событий');
            // Ваш код
        }
        
        loadInitialData() {
            console.log('AppUpdated: загрузка начальных данных');
            // Ваш код
        }
        
        static refreshAuthState() {
            console.log('AppUpdated.refreshAuthState() вызван');
            // Обновление состояния авторизации
            if (window.updateHeaderAuthState) {
                window.updateHeaderAuthState();
            }
        }
    };
    
    // Экспортируем
    window.AppUpdated = AppUpdated;
    
    // Автоматическая инициализация при загрузке DOM
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            try {
                const app = new AppUpdated();
                app.init();
            } catch (error) {
                console.error('Ошибка инициализации AppUpdated:', error);
            }
        });
    } else {
        // DOM уже загружен
        setTimeout(() => {
            try {
                const app = new AppUpdated();
                app.init();
            } catch (error) {
                console.error('Ошибка инициализации AppUpdated:', error);
            }
        }, 100);
    }
}