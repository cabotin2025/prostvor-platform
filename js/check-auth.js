// check-auth.js - упрощенная версия
document.addEventListener('DOMContentLoaded', function() {
    // Просто проверяем, есть ли токен
    const token = localStorage.getItem('prostvor_token');
    const user = localStorage.getItem('prostvor_user');
    
    if (token && user) {
        console.log('✅ Пользователь авторизован');
        // Можно обновить UI
    } else {
        console.log('❌ Пользователь не авторизован');
    }
});