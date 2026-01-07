// init-api.js - исправленная версия
console.log('🌐 init-api.js загружен');

document.addEventListener('DOMContentLoaded', function() {
    console.log('🌐 Инициализация API...');
    
    // Проверяем, какой API доступен
    if (window.prostvorAPI) {
        console.log('✅ ProstvorAPI доступен');
        setupProstvorAPI();
    } else if (window.api) {
        console.log('✅ window.api доступен');
        setupLegacyAPI();
    } else {
        console.warn('⚠️ API не найден, использую localStorage');
        setupFallback();
    }
});

function setupProstvorAPI() {
    const api = window.prostvorAPI;
    
    // Проверяем авторизацию
    if (api.isAuthenticated && api.isAuthenticated()) {
        console.log('👤 Авторизован через ProstvorAPI');
        const user = api.getCurrentUser();
        if (user) {
            updateUIForAuthenticatedUser(user);
        }
    } else {
        console.log('👤 Не авторизован');
        updateUIForGuest();
    }
}

function setupLegacyAPI() {
    // Для совместимости со старым кодом
    console.log('Использую legacy API');
    // ... можно добавить логику для window.api
}

function setupFallback() {
    console.log('Использую fallback (только localStorage)');
    
    const token = localStorage.getItem('prostvor_token');
    const userStr = localStorage.getItem('prostvor_user');
    
    if (token && userStr) {
        try {
            const user = JSON.parse(userStr);
            updateUIForAuthenticatedUser(user);
        } catch (e) {
            updateUIForGuest();
        }
    } else {
        updateUIForGuest();
    }
}

function updateUIForAuthenticatedUser(user) {
    console.log('Обновляю UI для пользователя:', user.nickname);
    
    // Показываем боковые панели
    const sidebarPanels = document.getElementById('sidebarPanels');
    if (sidebarPanels) {
        sidebarPanels.style.display = 'block';
        console.log('📊 Боковые панели активированы');
    }
    
    // Обновляем имя пользователя
    const userElements = document.querySelectorAll('[data-user-info]');
    userElements.forEach(el => {
        const field = el.dataset.userInfo;
        if (user[field]) {
            el.textContent = user[field];
        }
    });
}

function updateUIForGuest() {
    console.log('Показываю UI для гостя');
    const sidebarPanels = document.getElementById('sidebarPanels');
    if (sidebarPanels) {
        sidebarPanels.style.display = 'none';
    }
}