// check-auth.js - МИНИМАЛЬНАЯ РАБОЧАЯ ВЕРСИЯ
console.log('🔐 check-auth.js загружен');

document.addEventListener('DOMContentLoaded', function() {
    console.log('🔐 Проверка авторизации начата');
    
    // Проверяем токен
    const token = localStorage.getItem('prostvor_token');
    const userStr = localStorage.getItem('prostvor_user');
    
    console.log('Токен в localStorage:', token ? '✅ Есть' : '❌ Нет');
    console.log('Пользователь в localStorage:', userStr ? '✅ Есть' : '❌ Нет');
    
    if (token && userStr) {
        try {
            const user = JSON.parse(userStr);
            console.log('✅ Авторизован:', user.nickname);
            
            // Показываем панели
            const sidebar = document.getElementById('sidebarPanels');
            if (sidebar) {
                sidebar.style.display = 'block';
                console.log('📊 Панели показаны');
            }
            
            // Заполняем имя пользователя
            document.querySelectorAll('.user-name').forEach(el => {
                el.textContent = user.nickname;
            });
            
        } catch (e) {
            console.error('Ошибка парсинга пользователя:', e);
        }
    } else {
        console.log('❌ Не авторизован');
        
        // Если не авторизован, редирект на вход
        if (!window.location.pathname.includes('enter-reg')) {
            console.log('🔄 Редирект на страницу входа');
            setTimeout(() => {
                window.location.href = '/pages/enter-reg.html';
            }, 2000);
        }
    }
});

// Для совместимости со старым кодом
window.checkAuth = function() {
    return !!localStorage.getItem('prostvor_token');
};