// js/auth-updated.js - МИНИМАЛЬНАЯ РАБОЧАЯ ВЕРСИЯ
console.log('🎯 AUTH: Загружен на enter-reg.html');

// Ждем загрузки DOM
document.addEventListener('DOMContentLoaded', function() {
    console.log('🎯 AUTH: DOM готов');
    
    const API_BASE = 'http://localhost:8000';
    
    // 1. КНОПКА "ВОЙТИ"
    const loginBtn = document.getElementById('loginButton');
    if (loginBtn) {
        console.log('✅ Кнопка ВОЙТИ найдена');
        
        loginBtn.addEventListener('click', async function(e) {
            e.preventDefault();
            console.log('🎯 Нажата ВОЙТИ');
            
            const email = document.getElementById('loginField')?.value || 'test2@example.com';
            const password = document.getElementById('passwordField')?.value || 'test123';
            
            console.log('Вход для:', email);
            alert('Вхожу...');
            
            try {
                const response = await fetch(API_BASE + '/api/auth/login.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, password })
                });
                
                const result = await response.json();
                console.log('Ответ:', result);
                
                if (result.success) {
                    localStorage.setItem('prostvor_token', result.token);
                    localStorage.setItem('prostvor_user', JSON.stringify(result.user));
                    alert('✅ Вход успешен!');
                    window.location.href = '/index.html';
                } else {
                    alert('❌ ' + result.error);
                }
            } catch (error) {
                alert('🚫 Ошибка подключения');
            }
        });
    }
    
    // 2. КНОПКА "РЕГИСТРАЦИЯ"
    const regBtn = document.getElementById('regButton');
    if (regBtn) {
        console.log('✅ Кнопка РЕГИСТРАЦИЯ найдена');
        
        regBtn.addEventListener('click', async function(e) {
            e.preventDefault();
            console.log('🎯 Нажата РЕГИСТРАЦИЯ');
            alert('Заполните форму и нажмите еще раз');
        });
    }
    
    console.log('✅ AUTH: Все кнопки настроены');
});