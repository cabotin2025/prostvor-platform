// Упрощенная версия - используем window.checkAuth()
document.addEventListener('DOMContentLoaded', function() {
    window.checkAuth();
    
    // Показываем информацию о пользователе если авторизован
    if (window.api && window.api.isAuthenticated()) {
        const user = window.api.getCurrentUser();
        const userElements = document.querySelectorAll('[data-user-info]');
        
        userElements.forEach(el => {
            const field = el.dataset.userInfo;
            if (user[field]) {
                el.textContent = user[field];
            }
        });
    }
});