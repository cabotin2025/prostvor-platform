// js/auth-updated.js - ИСПРАВЛЕННАЯ ВЕРСИЯ
document.addEventListener('DOMContentLoaded', function() {
    console.log('Auth module loaded');
    
    // Базовый URL - ИЗМЕНИТЕ если ваш PHP на другом порту!
    const API_BASE = 'http://localhost'; // или 'http://localhost:8000'
    
    // ==================== ВХОД ====================
    const loginButton = document.getElementById('loginButton');
    if (loginButton) {
        loginButton.addEventListener('click', async function(e) {
            e.preventDefault();
            
            const loginField = document.getElementById('loginField').value;
            const password = document.getElementById('passwordField').value;
            
            if (!loginField || !password) {
                alert('Заполните все поля');
                return;
            }
            
            // ПРОБЛЕМА: login.php ожидает ТОЛЬКО email
            // Но в форме может быть телефон или псевдоним
            // Пока будем считать, что это email
            const email = loginField; 
            
            try {
                const response = await fetch(API_BASE + '/api/auth/login.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, password })
                });
                
                const result = await response.json();
                console.log('Login result:', result);
                
                if (result.success) {
                    // Сохраняем токен
                    localStorage.setItem('prostvor_token', result.token);
                    localStorage.setItem('prostvor_user', JSON.stringify(result.user));
                    alert('Вход выполнен!');
                    window.location.href = '/index.html';
                } else {
                    alert('Ошибка: ' + (result.error || 'Неверные данные'));
                }
            } catch (error) {
                alert('Ошибка подключения: ' + error.message);
            }
        });
    }
    
    // ==================== РЕГИСТРАЦИЯ ====================
    const regButton = document.getElementById('regButton');
    if (regButton) {
        regButton.addEventListener('click', async function(e) {
            e.preventDefault();
            
            // 1. Собираем ОСНОВНЫЕ данные
            const nickname = document.getElementById('regNickname').value;
            const email = document.getElementById('regEmail').value;
            const password = document.getElementById('regPassword').value;
            const confirmPassword = document.getElementById('regConfirmPassword').value;
            const userType = document.getElementById('regTypeSelect').value;
            
            // 2. Проверка пароля
            if (password !== confirmPassword) {
                alert('Пароли не совпадают!');
                return;
            }
            
            if (password.length < 6) {
                alert('Пароль должен быть не менее 6 символов');
                return;
            }
            
            // 3. Проблема: для регистрации ОБЯЗАТЕЛЬНЫ name и last_name
            // Но они есть только если выбран "Человек"
            let name = '';
            let lastName = '';
            
            if (userType === 'Человек') {
                name = document.getElementById('regName')?.value || '';
                lastName = document.getElementById('regSurname')?.value || '';
                
                if (!name || !lastName) {
                    alert('Для регистрации человека обязательны Имя и Фамилия');
                    return;
                }
            } else {
                // Для Организации/Сообщества используем nickname как name
                name = nickname;
                lastName = userType; // или пустая строка
            }
            
            // 4. Согласие с условиями
            const agreementChecked = document.getElementById('regAgreementCheckbox').checked;
            if (!agreementChecked) {
                alert('Необходимо согласиться с условиями регистрации');
                return;
            }
            
            // 5. Подготовка данных для API
            const userData = {
                email: email,
                password: password,
                nickname: nickname,
                name: name,
                last_name: lastName
                // location_id можно добавить позже
            };
            
            console.log('Sending registration data:', userData);
            
            try {
                const response = await fetch(API_BASE + '/api/auth/register.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(userData)
                });
                
                const result = await response.json();
                console.log('Registration result:', result);
                
                if (result.success) {
                    // Автоматически входим после регистрации
                    localStorage.setItem('prostvor_token', result.token);
                    localStorage.setItem('prostvor_user', JSON.stringify(result.user));
                    alert('Регистрация успешна! Вы автоматически вошли в систему.');
                    window.location.href = '/index.html';
                } else {
                    alert('Ошибка регистрации: ' + (result.error || 'Неизвестная ошибка'));
                }
            } catch (error) {
                alert('Ошибка подключения: ' + error.message);
            }
        });
    }
    
    // Ссылка на условия
    const agreementLink = document.getElementById('agreementLink');
    if (agreementLink) {
        agreementLink.addEventListener('click', function(e) {
            e.preventDefault();
            window.open('Agreement.html', '_blank');
        });
    }
});