// js/auth-updated.js - РАБОЧАЯ ВЕРСИЯ (последняя)
console.log('🔐 PROSTVOR Auth Module v3.0 - ЗАГРУЖЕН');

// Ждем полной загрузки DOM
document.addEventListener('DOMContentLoaded', function() {
    console.log('✅ DOM загружен, настраиваю обработчики');
    
    const API_BASE = 'http://localhost:8000';
    
    // Функция для уведомлений
    function showAlert(message, type = 'info') {
        const alertDiv = document.createElement('div');
        alertDiv.style.cssText = `
            position: fixed; top: 20px; right: 20px;
            padding: 12px 20px; border-radius: 6px; z-index: 10000;
            background: ${type === 'error' ? '#dc3545' : type === 'success' ? '#28a745' : '#17a2b8'};
            color: white; font-family: Arial, sans-serif; font-size: 14px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            animation: slideIn 0.3s ease-out;
        `;
        alertDiv.textContent = message;
        document.body.appendChild(alertDiv);
        
        // Добавляем анимацию
        if (!document.querySelector('#alert-styles')) {
            const style = document.createElement('style');
            style.id = 'alert-styles';
            style.textContent = `
                @keyframes slideIn {
                    from { transform: translateX(100%); opacity: 0; }
                    to { transform: translateX(0); opacity: 1; }
                }
            `;
            document.head.appendChild(style);
        }
        
        setTimeout(() => {
            alertDiv.style.animation = 'slideIn 0.3s ease-out reverse';
            setTimeout(() => alertDiv.remove(), 300);
        }, 4000);
    }
    
    // ==================== ОБРАБОТЧИК ДЛЯ КНОПКИ "ВОЙТИ" ====================
    const loginButton = document.getElementById('loginButton');
    if (loginButton) {
        console.log('✅ Найдена кнопка "Войти" (id="loginButton")');
        
        // Удаляем старый элемент и создаем новый (сбрасываем обработчики)
        const newLoginButton = loginButton.cloneNode(true);
        loginButton.parentNode.replaceChild(newLoginButton, loginButton);
        
        // Добавляем обработчик клика
        newLoginButton.addEventListener('click', async function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('🎯 Нажата кнопка "Войти"');
            
            // Получаем данные из формы
            const emailInput = document.getElementById('loginField');
            const passwordInput = document.getElementById('passwordField');
            
            if (!emailInput || !passwordInput) {
                showAlert('Не найдены поля формы', 'error');
                return;
            }
            
            const email = emailInput.value.trim();
            const password = passwordInput.value;
            
            if (!email || !password) {
                showAlert('Введите email и пароль', 'error');
                return;
            }
            
            console.log('📤 Отправка запроса входа для:', email);
            showAlert('Выполняю вход...', 'info');
            
            try {
                const response = await fetch(API_BASE + '/api/auth/login.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        email: email,
                        password: password
                    })
                });
                
                console.log('📥 Статус ответа:', response.status);
                
                if (!response.ok) {
                    throw new Error(`HTTP ошибка: ${response.status}`);
                }
                
                const result = await response.json();
                console.log('📥 Ответ сервера:', result);
                
                if (result.success) {
                    // Сохраняем данные авторизации
                    localStorage.setItem('prostvor_token', result.token);
                    localStorage.setItem('prostvor_user', JSON.stringify(result.user));
                    
                    console.log('💾 Токен сохранен');
                    console.log('👤 Пользователь:', result.user.nickname);
                    
                    showAlert(`✅ Вход успешен! Добро пожаловать, ${result.user.nickname}!`, 'success');
                    
                    // Редирект на главную через 1.5 секунды
                    setTimeout(() => {
                        console.log('🔄 Перенаправление на /index.html');
                        window.location.href = '/index.html';
                    }, 1500);
                    
                } else {
                    console.error('❌ Ошибка входа:', result.error);
                    showAlert('❌ ' + result.error, 'error');
                }
                
            } catch (error) {
                console.error('🔥 Ошибка запроса:', error);
                showAlert('🚫 Ошибка подключения к серверу', 'error');
            }
        });
        
    } else {
        console.error('❌ Кнопка "Войти" не найдена! Проверьте HTML.');
    }
    
    // ==================== ОБРАБОТЧИК ДЛЯ КНОПКИ "РЕГИСТРАЦИЯ" ====================
    const regButton = document.getElementById('regButton');
    if (regButton) {
        console.log('✅ Найдена кнопка "Зарегистрироваться" (id="regButton")');
        
        // Удаляем старый элемент и создаем новый
        const newRegButton = regButton.cloneNode(true);
        regButton.parentNode.replaceChild(newRegButton, regButton);
        
        // Добавляем обработчик клика
        newRegButton.addEventListener('click', async function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('🎯 Нажата кнопка "Зарегистрироваться"');
            
            // Проверяем тип пользователя
            const userTypeSelect = document.getElementById('regTypeSelect');
            if (!userTypeSelect) {
                showAlert('Не найден выбор типа пользователя', 'error');
                return;
            }
            
            const userType = userTypeSelect.value;
            if (userType !== 'Человек') {
                showAlert('Для регистрации выберите тип "Человек"', 'error');
                return;
            }
            
            // Функция для получения значения поля
            const getValue = (id) => {
                const elem = document.getElementById(id);
                return elem ? elem.value.trim() : '';
            };
            
            // Получаем значения полей
            const email = getValue('regEmail');
            const password = getValue('regPassword');
            const confirmPassword = getValue('regConfirmPassword');
            const nickname = getValue('regNickname');
            const name = getValue('regName');
            const lastName = getValue('regSurname');
            
            // Валидация
            if (!email || !password || !nickname || !name || !lastName) {
                showAlert('Заполните все обязательные поля', 'error');
                return;
            }
            
            if (password !== confirmPassword) {
                showAlert('Пароли не совпадают', 'error');
                return;
            }
            
            if (password.length < 6) {
                showAlert('Пароль должен быть не менее 6 символов', 'error');
                return;
            }
            
            // Проверка согласия с условиями
            const agreementCheckbox = document.getElementById('regAgreementCheckbox');
            if (!agreementCheckbox || !agreementCheckbox.checked) {
                showAlert('Необходимо согласиться с условиями регистрации', 'error');
                return;
            }
            
            // Подготовка данных для API
            const userData = {
                email: email,
                password: password,
                nickname: nickname,
                name: name,
                last_name: lastName
            };
            
            console.log('📤 Отправка запроса регистрации:', userData);
            showAlert('Регистрирую нового пользователя...', 'info');
            
            try {
                const response = await fetch(API_BASE + '/api/auth/register.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(userData)
                });
                
                console.log('📥 Статус ответа:', response.status);
                
                if (!response.ok) {
                    throw new Error(`HTTP ошибка: ${response.status}`);
                }
                
                const result = await response.json();
                console.log('📥 Ответ сервера:', result);
                
                if (result.success) {
                    // Сохраняем данные авторизации
                    localStorage.setItem('prostvor_token', result.token);
                    localStorage.setItem('prostvor_user', JSON.stringify(result.user));
                    
                    console.log('💾 Токен сохранен');
                    console.log('👤 Новый пользователь:', result.user.nickname);
                    
                    showAlert(`✅ Регистрация успешна! Добро пожаловать, ${result.user.nickname}!`, 'success');
                    
                    // Редирект на главную через 1.5 секунды
                    setTimeout(() => {
                        console.log('🔄 Перенаправление на /index.html');
                        window.location.href = '/index.html';
                    }, 1500);
                    
                } else {
                    console.error('❌ Ошибка регистрации:', result.error);
                    showAlert('❌ ' + result.error, 'error');
                }
                
            } catch (error) {
                console.error('🔥 Ошибка запроса:', error);
                showAlert('🚫 Ошибка подключения к серверу', 'error');
            }
        });
        
    } else {
        console.error('❌ Кнопка "Зарегистрироваться" не найдена! Проверьте HTML.');
    }
    
    // ==================== ДОПОЛНИТЕЛЬНЫЕ ЭЛЕМЕНТЫ ====================
    
    // Ссылка "Условия"
    const agreementLink = document.getElementById('agreementLink');
    if (agreementLink) {
        agreementLink.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('📄 Открываю условия регистрации');
            window.open('Agreement.html', '_blank');
        });
    }
    
    // Ссылка "Не помню пароль"
    const forgotPasswordLink = document.getElementById('forgotPasswordLink');
    if (forgotPasswordLink) {
        forgotPasswordLink.addEventListener('click', function(e) {
            console.log('🔑 Переход к восстановлению пароля');
            // Переход уже настроен через href
        });
    }
    
    console.log('✅ Модуль авторизации полностью инициализирован');
    console.log('📍 Готов к работе! Пробуйте войти или зарегистрироваться.');
    
    // Проверяем, не авторизован ли пользователь уже
    const token = localStorage.getItem('prostvor_token');
    if (token) {
        console.log('🔐 Обнаружен сохраненный токен');
        try {
            const user = JSON.parse(localStorage.getItem('prostvor_user') || '{}');
            if (user.nickname) {
                console.log(`👤 Вы авторизованы как: ${user.nickname}`);
                
                // Если на странице входа, но уже авторизован
                if (window.location.pathname.includes('enter-reg')) {
                    console.log('ℹ️ Вы уже авторизованы. Можно перейти на главную.');
                    
                    // Создаем кнопку для перехода на главную
                    const goToMainBtn = document.createElement('button');
                    goToMainBtn.textContent = 'Перейти на главную';
                    goToMainBtn.style.cssText = `
                        position: fixed; bottom: 20px; right: 20px;
                        padding: 10px 20px; background: #6f42c1;
                        color: white; border: none; border-radius: 5px;
                        cursor: pointer; z-index: 9999;
                    `;
                    goToMainBtn.onclick = () => window.location.href = '/index.html';
                    document.body.appendChild(goToMainBtn);
                }
            }
        } catch (e) {
            console.error('Ошибка чтения данных пользователя:', e);
        }
    }
});

console.log('🔐 Auth module initialization started...');