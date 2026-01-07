// js/auth-check.js - ЕДИНЫЙ МОДУЛЬ ПРОВЕРКИ АВТОРИЗАЦИИ
console.log('🔐 auth-check.js загружен');

// Основная функция проверки
function checkAuthentication() {
    console.log('=== ПРОВЕРКА АВТОРИЗАЦИИ ===');
    
    // 1. Проверяем ВСЕ возможные места хранения
    const tokenSources = [
        { name: 'localStorage', token: localStorage.getItem('prostvor_token'), user: localStorage.getItem('prostvor_user') },
        { name: 'sessionStorage', token: sessionStorage.getItem('prostvor_token'), user: sessionStorage.getItem('prostvor_user') },
        { name: 'cookie', token: getCookie('prostvor_token'), user: getCookie('prostvor_user') }
    ];
    
    let foundToken = null;
    let foundUser = null;
    let source = '';
    
    for (const sourceInfo of tokenSources) {
        if (sourceInfo.token && sourceInfo.user) {
            foundToken = sourceInfo.token;
            foundUser = sourceInfo.user;
            source = sourceInfo.name;
            console.log(`✅ Найден токен в ${source}`);
            break;
        }
    }
    
    // 2. Если нашли - обрабатываем
    if (foundToken && foundUser) {
        try {
            const user = JSON.parse(foundUser);
            console.log(`👤 Авторизован: ${user.nickname} (из ${source})`);
            
            // Показываем боковые панели
            showSidebarPanels();
            
            // Обновляем UI
            updateUserUI(user);
            
            // Синхронизируем все хранилища
            synchronizeStorages(foundToken, foundUser);
            
            return { authenticated: true, user: user };
            
        } catch (e) {
            console.error('❌ Ошибка парсинга пользователя:', e);
        }
    }
    
    // 3. Не авторизован
    console.log('❌ Пользователь не авторизован');
    hideSidebarPanels();
    
    // Если на главной странице - редирект на вход
    if (window.location.pathname === '/' || window.location.pathname === '/index.html') {
        console.log('🔄 Редирект на страницу входа через 3 секунды...');
        setTimeout(() => {
            window.location.href = '/pages/enter-reg.html';
        }, 3000);
    }
    
    return { authenticated: false, user: null };
}

// Вспомогательные функции
function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return decodeURIComponent(parts.pop().split(';').shift());
    return null;
}

function showSidebarPanels() {
    const sidebar = document.getElementById('sidebarPanels');
    if (sidebar) {
        sidebar.style.display = 'block';
        console.log('📊 Боковые панели показаны');
        
        // Инициализируем панели если есть функции
        if (typeof CalendarPanelUpdated !== 'undefined' && CalendarPanelUpdated.init) {
            CalendarPanelUpdated.init();
        }
        if (typeof TasksPanelUpdated !== 'undefined' && TasksPanelUpdated.init) {
            TasksPanelUpdated.init();
        }
    }
}

function hideSidebarPanels() {
    const sidebar = document.getElementById('sidebarPanels');
    if (sidebar) {
        sidebar.style.display = 'none';
    }
}

function updateUserUI(user) {
    // Обновляем имя пользователя
    document.querySelectorAll('.user-name, [data-user-name]').forEach(el => {
        el.textContent = user.nickname || user.email;
    });
    
    // Показываем элементы для авторизованных
    document.querySelectorAll('.auth-only').forEach(el => {
        el.style.display = 'block';
    });
    document.querySelectorAll('.guest-only').forEach(el => {
        el.style.display = 'none';
    });
}

function synchronizeStorages(token, user) {
    // Синхронизируем все хранилища
    localStorage.setItem('prostvor_token', token);
    localStorage.setItem('prostvor_user', user);
    sessionStorage.setItem('prostvor_token', token);
    sessionStorage.setItem('prostvor_user', user);
    
    // Также в cookie на 1 день
    setCookie('prostvor_token', token, 1);
    setCookie('prostvor_user', user, 1);
}

function setCookie(name, value, days) {
    const expires = new Date(Date.now() + days * 864e5).toUTCString();
    document.cookie = `${name}=${encodeURIComponent(value)}; expires=${expires}; path=/`;
}

// Инициализация при загрузке
document.addEventListener('DOMContentLoaded', function() {
    console.log('🔐 DOM готов, проверяю авторизацию...');
    const authResult = checkAuthentication();
    
    // Для совместимости со старым кодом
    window.authInfo = authResult;
    window.isAuthenticated = () => authResult.authenticated;
    window.getCurrentUser = () => authResult.user;
});

// Делаем функцию доступной глобально
window.checkAuth = checkAuthentication;
window.showSidebar = showSidebarPanels;