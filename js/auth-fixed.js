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
    console.log('🌐 API_BASE установлен:', API_BASE);
    
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
    
    // 1. Получаем redirect URL
    const urlParams = new URLSearchParams(window.location.search);
    let redirectUrl = urlParams.get('redirect');
    
    if (!redirectUrl) {
        redirectUrl = document.referrer;
        if (redirectUrl && redirectUrl.includes('enter-reg.html')) {
            redirectUrl = '/index.html';
        }
    }
    
    if (!redirectUrl || redirectUrl === 'null') {
        redirectUrl = '/index.html';
    }
    
    console.log('📍 Redirect URL:', redirectUrl);
    
    // 2. Получаем данные из формы
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
    
    try {
        const response = await fetch(API_BASE + '/api/auth/login.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                email: email, 
                password: password,
                redirect_url: redirectUrl
            })
        });
        
        const result = await response.json();
        console.log('📥 Ответ сервера:', result);
        
        if (result.success) {
            // Сохранение данных
            localStorage.setItem('auth_token', result.token);
            localStorage.setItem('user_nickname', result.user.nickname);
            localStorage.setItem('user_id', result.user.actor_id.toString());
            localStorage.setItem('user_status', result.user.global_status);
            localStorage.setItem('user_email', result.user.email);
            localStorage.setItem('user_data', JSON.stringify(result.user));
            
            if (result.user.color_frame) {
                localStorage.setItem('user_color_frame', result.user.color_frame);
                console.log('🎨 Color frame сохранен:', result.user.color_frame);
            }
            
            console.log('💾 Токен сохранен:', result.token.substring(0, 30) + '...');
            console.log('👤 Пользователь:', result.user.nickname);
            
            alert(`✅ Вход успешен! Добро пожаловать, ${result.user.nickname}!`);
            
            // Редирект на сохранённую страницу
            setTimeout(() => {
                if (result.redirect_to) {
                    console.log('🔄 Редирект на:', result.redirect_to);
                    window.location.href = result.redirect_to;
                } else {
                    console.log('🔄 Редирект на (запасной):', redirectUrl);
                    window.location.href = redirectUrl;
                }
            }, 1500);
        }
        else {
            alert('❌ Ошибка входа: ' + (result.message || 'Неверный email или пароль'));
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
            
            // Получаем redirect URL из параметров страницы
            const urlParams = new URLSearchParams(window.location.search);
            let redirectUrl = urlParams.get('redirect') || '/index.html';

            // Проверяем тип пользователя
            const userType = document.getElementById('regTypeSelect')?.value;
            if (userType !== 'Человек') {
                alert('Для регистрации выберите тип "Человек"');
                return;
            }
            
            // Функция для генерации случайного яркого цвета - ТОЛЬКО ПРИ РЕГИСТРАЦИИ
            function generateRandomColor() {
                const brightColors = [
                    '#FF6B6B', // Красный (хорошо виден)
                    '#4ECDC4', // Бирюзовый (хорошо виден)
                    '#FFD166', // Жёлтый (хорошо виден)
                    '#06D6A0', // Зелёный (хорошо виден)
                    '#118AB2', // Синий (хорошо виден)
                    '#7209B7', // Фиолетовый (хорошо виден)
                    '#FF9E6D', // Оранжевый (хорошо виден)
                    '#83E377'  // Светло-зелёный (хорошо виден)
                ];
                return brightColors[Math.floor(Math.random() * brightColors.length)];
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
            
            // Данные для отправки - СООТВЕТСТВУЮТ ОЖИДАНИЯМ register.php
            const userData = {
                email: email,
                password: password,
                nickname: nickname,
                name: name,
                last_name: lastName,
                color_frame: generateRandomColor(), // Генерируем случайный цвет ТОЛЬКО ПРИ РЕГИСТРАЦИИ
                redirect_url: redirectUrl
            };
            
            console.log('📤 Отправляю регистрацию:', userData);
            
            try {
                // ИСПРАВЛЕНИЕ: используем реальный endpoint регистрации
                const response = await fetch('/api/auth/register.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(userData)
                });
                
                const result = await response.json();
                console.log('📥 Ответ сервера:', result);
                
                if (result.success) {
                    // УНИФИЦИРОВАННОЕ СОХРАНЕНИЕ ДАННЫХ
                    localStorage.setItem('auth_token', result.token);
                    localStorage.setItem('user_nickname', result.nickname);
                    localStorage.setItem('user_id', result.actor_id.toString());
                    localStorage.setItem('user_status', result.global_status);
                    
                    // Сохраняем color_frame при регистрации
                    if (result.color_frame) {
                        localStorage.setItem('user_color_frame', result.color_frame);
                        console.log('🎨 Color frame сохранен при регистрации:', result.color_frame);
                    }
                    
                    alert(`✅ Регистрация успешна! Добро пожаловать, ${result.nickname}!`);
                    
                       // Сообщаем другим модулям об авторизации
                        if (window.AppUpdated && AppUpdated.refreshAuthState) {
                            console.log('🔄 Вызываем AppUpdated.refreshAuthState()');
                            AppUpdated.refreshAuthState();
                        }
                        
                        // Или инициализируем main-updated если он ещё не загружен
                        if (window.updateHeaderAuthState) {
                            window.updateHeaderAuthState();
                        }
                        
                        // Генерируем событие для других слушателей
                        const authEvent = new CustomEvent('user-logged-in', {
                            detail: { user: result.user }
                        });
                        window.dispatchEvent(authEvent);

                    setTimeout(() => {
                        if (result.redirect_to) {
                            window.location.href = result.redirect_to;
                        } else {
                            // Иначе используем наш сохранённый URL
                            window.location.href = redirectUrl;
                        }
                    }, 1500);
                } else {
                    alert('❌ Ошибка: ' + (result.message || 'Неизвестная ошибка'));
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

// Устаревшие функции - ОСТАВЛЕНЫ ДЛЯ СОВМЕСТИМОСТИ
async function handleRegistration(formData) {
    console.warn('⚠️ handleRegistration устарела, используйте новую реализацию');
    try {
        const registrationData = {
            username: formData.get('username'),
            email: formData.get('email'),
            password: formData.get('password')
        };
        
        const response = await fetch('/api/auth/register.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(registrationData)
        });
        
        const data = await response.json();
        console.log('📥 Ответ сервера:', data);

        if (data.success) {
            if (data.token) {
                localStorage.setItem('auth_token', data.token);
            }
            
            const nickname = data.nickname || data.username || data.user?.nickname;
            if (nickname) {
                localStorage.setItem('user_nickname', nickname);
            }
            
            if (data.actor_id) {
                localStorage.setItem('user_id', data.actor_id.toString());
            }
            
            if (data.global_status) {
                localStorage.setItem('user_status', data.global_status);
            } else if (data.success) {
                localStorage.setItem('user_status', 'Участник ТЦ');
            }
            
            // Сохраняем color_frame если есть
            if (data.color_frame) {
                localStorage.setItem('user_color_frame', data.color_frame);
            }
            
            alert('✅ Регистрация успешна!');
            
            setTimeout(() => {
                window.location.href = '/index.html';
            }, 1000);
        } else {
            alert('❌ Ошибка регистрации: ' + (data.message || 'Неизвестная ошибка'));
        }
    } catch (error) {
        console.error('❌ Ошибка в handleRegistration:', error);
        alert('❌ Ошибка соединения с сервером');
    }
}

async function handleLogin(email, password) {
    console.warn('⚠️ handleLogin устарела, используйте новую реализацию');
    try {
        const response = await fetch('/api/auth/login.php', {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ email, password })
        });
        
        const data = await response.json();
        console.log('Ответ сервера:', data);
        
        if (data.success) {
            localStorage.setItem('auth_token', data.token);
            localStorage.setItem('user_nickname', data.user.nickname);
            localStorage.setItem('user_id', data.user.actor_id.toString());
            localStorage.setItem('user_status', data.user.global_status);
            localStorage.setItem('user_email', data.user.email);
            localStorage.setItem('user_data', JSON.stringify(data.user));
            
            // Сохраняем color_frame если он есть
            if (data.user.color_frame) {
                localStorage.setItem('user_color_frame', data.user.color_frame);
                console.log('🎨 Color frame сохранен при логине:', data.user.color_frame);
            }
            
            console.log('✅ Авторизация успешна:', data.user.nickname);
            
            alert('✅ Вход выполнен! Добро пожаловать, ' + data.user.nickname);
            
            setTimeout(() => {
                window.location.href = '/index.html';
            }, 1000);
            
            return true;
        } else {
            console.error('❌ Ошибка авторизации:', data.message);
            alert('❌ Ошибка: ' + data.message);
            return false;
        }
    } catch (error) {
        console.error('❌ Ошибка сети:', error);
        alert('❌ Ошибка подключения к серверу');
        return false;
    }
}

window.dispatchEvent(new Event('auth-state-changed'));

console.log('🚀 Auth Fixed инициализация завершена!');