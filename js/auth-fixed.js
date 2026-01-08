
// js/auth-fixed.js - РАБОЧАЯ ВЕРСИЯ
// ДОПОЛНИТЕЛЬНАЯ ОТЛАДКА
console.log('🔧 Auth-fixed.js: Проверяем localStorage доступность');
try {
    const testKey = 'auth_test_' + Date.now();
    localStorage.setItem(testKey, 'test_value');
    const read = localStorage.getItem(testKey);
    console.log('localStorage тест:', read === 'test_value' ? '✅ Работает' : '❌ Не работает');
    localStorage.removeItem(testKey);
} catch (e) {
    console.error('localStorage ошибка:', e);
    alert('ВНИМАНИЕ: localStorage недоступен!');
}

console.log('🚀 PROSTVOR Auth Fixed - ЗАГРУЖЕН!');

// Ждем полной загрузки DOM
document.addEventListener('DOMContentLoaded', function() {
    console.log('✅ DOM готов, настраиваю кнопки...');
    
    const API_BASE = 'http://localhost:8000';
    
    // ========== КНОПКА "ВОЙТИ" ==========
    const loginBtn = document.getElementById('loginButton');
    if (loginBtn) {
        console.log('✅ Найдена кнопка ВОЙТИ');
        
        // Сбрасываем все старые обработчики
        const newLoginBtn = loginBtn.cloneNode(true);
        loginBtn.parentNode.replaceChild(newLoginBtn, loginBtn);
        
        // Добавляем новый обработчик
        newLoginBtn.addEventListener('click', async function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('🎯 Кнопка ВОЙТИ нажата!');
            
            // Получаем данные
            const emailInput = document.getElementById('loginField');
            const passwordInput = document.getElementById('passwordField');
            
            if (!emailInput || !passwordInput) {
                alert('Не найдены поля для ввода');
                return;
            }
            
            const email = emailInput.value.trim();
            const password = passwordInput.value;
            
            if (!email || !password) {
                alert('Введите email и пароль');
                return;
            }
            
            console.log('📤 Отправляю запрос входа:', email);
            alert('Выполняю вход...');
            
            try {
                const response = await fetch(API_BASE + '/api/auth/login.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, password })
                });
                
                const result = await response.json();
                console.log('📥 Ответ сервера:', result);
                
                if (result.success) {
                    // Сохраняем токен
                    localStorage.setItem('prostvor_token', result.token);
                    localStorage.setItem('prostvor_user', JSON.stringify(result.user));
                    
                    console.log('💾 Токен сохранен:', result.token.substring(0, 30) + '...');
                    console.log('👤 Пользователь:', result.user.nickname);
                    
                    // ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА:
                    console.log('✅ Проверка сразу после сохранения:');
                    console.log('- В localStorage token?', !!localStorage.getItem('prostvor_token'));
                    console.log('- В localStorage user?', !!localStorage.getItem('prostvor_user'));
                    
                    alert(`✅ Вход успешен! Добро пожаловать, ${result.user.nickname}!`);
                    
                    // Редирект
                    setTimeout(() => {
                        window.location.href = '/index.html';
                    }, 1500);
                }
                else {
                    // Обработка ошибок от сервера
                    alert('❌ Ошибка входа: ' + (result.error || 'Неверный email или пароль'));
                }
            } catch (error) {
                console.error('🔥 Ошибка при входе:', error);
                alert('🚫 Ошибка подключения к серверу');
            }
        });
    } else {
        console.error('❌ Кнопка ВОЙТИ не найдена!');
    }
    
    // ========== КНОПКА "РЕГИСТРАЦИЯ" ==========
    const regBtn = document.getElementById('regButton');
    if (regBtn) {
        console.log('✅ Найдена кнопка РЕГИСТРАЦИЯ');
        
        // Сбрасываем все старые обработчики
        const newRegBtn = regBtn.cloneNode(true);
        regBtn.parentNode.replaceChild(newRegBtn, regBtn);
        
        // Добавляем новый обработчик
        newRegBtn.addEventListener('click', async function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('🎯 Кнопка РЕГИСТРАЦИЯ нажата!');
            
            // Проверяем тип пользователя
            const userType = document.getElementById('regTypeSelect')?.value;
            if (userType !== 'Человек') {
                alert('Для регистрации выберите тип "Человек"');
                return;
            }
            
            // Получаем данные
            const getValue = (id) => document.getElementById(id)?.value?.trim() || '';
            
            const email = getValue('regEmail');
            const password = getValue('regPassword');
            const confirmPassword = getValue('regConfirmPassword');
            const nickname = getValue('regNickname');
            const name = getValue('regName');
            const lastName = getValue('regSurname');
            
            // Проверки
            if (!email || !password || !nickname || !name || !lastName) {
                alert('Заполните все обязательные поля');
                return;
            }
            
            if (password !== confirmPassword) {
                alert('Пароли не совпадают');
                return;
            }
            
            if (password.length < 6) {
                alert('Пароль должен быть не менее 6 символов');
                return;
            }
            
            // Проверка согласия
            const agreement = document.getElementById('regAgreementCheckbox');
            if (!agreement?.checked) {
                alert('Необходимо согласиться с условиями');
                return;
            }
            
            // Данные для отправки
            const userData = {
                email, password, nickname, name, last_name: lastName
            };
            
            console.log('📤 Отправляю регистрацию:', userData);
            alert('Регистрирую пользователя...');
            
            try {
                const response = await fetch(API_BASE + '/api/auth/register.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(userData)
                });
                
                const result = await response.json();
                console.log('📥 Ответ сервера:', result);
                
                if (result.success) {
                    localStorage.setItem('prostvor_token', result.token);
                    localStorage.setItem('prostvor_user', JSON.stringify(result.user));
                    
                    alert(`✅ Регистрация успешна! Добро пожаловать, ${result.user.nickname}!`);
                    
                    setTimeout(() => {
                        window.location.href = '/index.html';
                    }, 1500);
                } else {
                    alert('❌ Ошибка: ' + result.error);
                }
            } catch (error) {
                console.error('🔥 Ошибка:', error);
                alert('🚫 Ошибка подключения к серверу');
            }
        });
    } else {
        console.error('❌ Кнопка РЕГИСТРАЦИЯ не найдена!');
    }
    
    console.log('✅ Все кнопки настроены и готовы к работе!');
});

console.log('🚀 Auth Fixed инициализация начата...');

// Найти обработчик регистрации и обновить его
async function handleRegistration(formData) {
    try {
        // Только обязательные поля
        const registrationData = {
            username: formData.get('username'),
            email: formData.get('email'),
            password: formData.get('password')
            // locality_id: formData.get('locality') // ОПЦИОНАЛЬНО
        };
        
        const response = await fetch('/api/auth/register.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(registrationData)
        });
        
        const data = await response.json();
        
        if (data.success) {
            // Сохраняем токен
            localStorage.setItem('auth_token', data.token);
            // Перенаправляем
            window.location.href = '/index.html';
        } else {
            alert('Ошибка регистрации: ' + data.message);
        }
    } catch (error) {
        console.error('Registration error:', error);
        alert('Ошибка подключения к серверу');
    }
}