// Удалите старый код и оставьте только это:
document.addEventListener('DOMContentLoaded', function() {
    // Проверяем авторизацию
    if (!window.checkAuth && window.location.pathname.includes('enter-reg.html')) {
        return; // На странице входа не проверяем
    }
    
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            
            try {
                const result = await window.api.login(email, password);
                
                if (result.success) {
                    // Перенаправляем на главную страницу
                    window.location.href = '/index.html';
                } else {
                    alert(result.error || 'Ошибка входа');
                }
            } catch (error) {
                alert('Ошибка подключения к серверу');
            }
        });
    }
});