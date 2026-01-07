// auth-updated.js - УНИВЕРСАЛЬНАЯ ВЕРСИЯ
document.addEventListener('DOMContentLoaded', function() {
    console.log('Auth module loaded');
    
    // Определяем базовый URL API
    const API_BASE = window.location.origin; // или 'http://localhost:8000'
    console.log('API Base URL:', API_BASE);
    
    // Обработчик формы входа
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        console.log('Login form found');
        loginForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            console.log('Login form submitted');
            
            const email = document.getElementById('email')?.value;
            const password = document.getElementById('password')?.value;
            
            console.log('Email:', email, 'Password:', password ? '***' : 'empty');
            
            if (!email || !password) {
                alert('Заполните все поля');
                return;
            }
            
            try {
                const response = await fetch(API_BASE + '/api/auth/login.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ email, password })
                });
                
                const result = await response.json();
                console.log('Login response:', result);
                
                if (result.success) {
                    // Сохраняем данные
                    if (result.token) {
                        localStorage.setItem('prostvor_token', result.token);
                    }
                    if (result.user) {
                        localStorage.setItem('prostvor_user', JSON.stringify(result.user));
                    }
                    
                    alert('Вход выполнен успешно!');
                    window.location.href = '/index.html';
                } else {
                    alert('Ошибка: ' + (result.error || 'Неизвестная ошибка'));
                }
            } catch (error) {
                console.error('Login error:', error);
                alert('Ошибка подключения: ' + error.message);
            }
        });
    }
    
    // Обработчик формы регистрации
    const registerForm = document.getElementById('registerForm');
    if (registerForm) {
        console.log('Register form found');
        registerForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            console.log('Register form submitted');
            
            // Собираем данные формы
            const formData = {};
            const inputs = registerForm.querySelectorAll('input');
            inputs.forEach(input => {
                if (input.name && input.value) {
                    formData[input.name] = input.value;
                }
            });
            
            console.log('Form data:', formData);
            
            try {
                const response = await fetch(API_BASE + '/api/auth/register.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(formData)
                });
                
                const result = await response.json();
                console.log('Register response:', result);
                
                if (result.success) {
                    alert('Регистрация успешна! Теперь вы можете войти.');
                    
                    // Если на одной странице обе формы
                    if (loginForm && registerForm) {
                        registerForm.style.display = 'none';
                        loginForm.style.display = 'block';
                    }
                } else {
                    alert('Ошибка регистрации: ' + (result.error || 'Неизвестная ошибка'));
                }
            } catch (error) {
                console.error('Register error:', error);
                alert('Ошибка подключения: ' + error.message);
            }
        });
    }
});