// auth-fixed.js - УНИВЕРСАЛЬНАЯ ВЕРСИЯ
console.log('🔧 Auth-fixed.js: Проверяем localStorage доступность');
try {
    const testKey = 'auth_test_' + Date.now();
    localStorage.setItem(testKey, 'test_value');
    const read = localStorage.getItem(testKey);
    console.log('localStorage тест:', read === 'test_value' ? '✅ Работает' : '❌ Не работает');
    localStorage.removeItem(testKey);
} catch (e) {
    console.error('localStorage ошибка:', e);
}

console.log('🚀 PROSTVOR Auth Fixed - ЗАГРУЖЕН!');
console.log('📍 Текущая страница:', window.location.pathname);

// Ждем полной загрузки DOM
document.addEventListener('DOMContentLoaded', function() {
    console.log('✅ DOM готов, проверяю страницу...');
    
    // Проверяем, находимся ли на странице входа/регистрации
    const isEnterRegPage = window.location.pathname.includes('enter-reg.html') || 
                          document.body.classList.contains('enter-reg-page') ||
                          document.querySelector('.auth-tabs') !== null;
    
    if (isEnterRegPage) {
        console.log('✅ Это страница входа/регистрации, настраиваю формы...');
        setupAuthForms();
    } else {
        console.log('⚠️ Это не страница входа, пропускаю настройку форм');
        setupGlobalAuth();
    }
});

// ========== НАСТРОЙКА ФОРМ НА СТРАНИЦЕ ВХОДА ==========
function setupAuthForms() {
    const API_BASE = window.location.protocol + '//' + window.location.hostname + (window.location.port ? ':' + window.location.port : '');
    console.log('🌐 API_BASE установлен:', API_BASE);
    
    // ========== КНОПКА "ВОЙТИ" ==========
    const loginForm = document.getElementById('login-form');
    if (loginForm) {
        const loginBtn = loginForm.querySelector('button[type="submit"]');
        
        if (loginBtn && loginBtn.textContent.includes('ВОЙТИ')) {
            console.log('✅ Найдена кнопка ВОЙТИ');
            
            loginForm.addEventListener('submit', function(e) {
                e.preventDefault();
                handleLogin(API_BASE);
            });
            
            loginBtn.addEventListener('click', function(e) {
                e.preventDefault();
                handleLogin(API_BASE);
            });
        }
    }
    
    // ========== КНОПКА "РЕГИСТРАЦИЯ" ==========
    const registerForm = document.getElementById('register-form');
    if (registerForm) {
        const registerBtn = registerForm.querySelector('button[type="submit"]');
        
        if (registerBtn && registerBtn.textContent.includes('РЕГИСТРАЦИЯ')) {
            console.log('✅ Найдена кнопка РЕГИСТРАЦИЯ');
            
            registerForm.addEventListener('submit', function(e) {
                e.preventDefault();
                handleRegistration(API_BASE);
            });
            
            registerBtn.addEventListener('click', function(e) {
                e.preventDefault();
                handleRegistration(API_BASE);
            });
        }
    }
    
    // ========== ПЕРЕКЛЮЧЕНИЕ МЕЖДУ ВКЛАДКАМИ ==========
    const tabButtons = document.querySelectorAll('.tab-btn');
    const tabContents = document.querySelectorAll('.tab-content');
    
    tabButtons.forEach(button => {
        button.addEventListener('click', function() {
            const tabId = this.getAttribute('data-tab');
            
            tabButtons.forEach(btn => btn.classList.remove('active'));
            this.classList.add('active');
            
            tabContents.forEach(content => content.classList.remove('active'));
            const targetTab = document.getElementById(tabId + '-tab');
            if (targetTab) {
                targetTab.classList.add('active');
            }
        });
    });
    
    console.log('✅ Формы на странице входа настроены!');
}

// ========== ГЛОБАЛЬНЫЕ АВТОРИЗАЦИОННЫЕ ФУНКЦИИ ==========
function setupGlobalAuth() {
    console.log('🌐 Настраиваю глобальные функции авторизации');
    
    // Можно добавить глобальные обработчики для других страниц
    const logoutBtn = document.getElementById('logout-btn') || 
                     document.querySelector('[data-action="logout"]');
    
    if (logoutBtn) {
        logoutBtn.addEventListener('click', function(e) {
            e.preventDefault();
            localStorage.clear();
            window.location.href = '/pages/enter-reg.html';
        });
        console.log('✅ Кнопка выхода настроена');
    }
}

// ========== ОБЩИЕ ФУНКЦИИ (оставляем как были) ==========
async function handleLogin(API_BASE) {
    console.log('🎯 Обработка входа...');
    
    const urlParams = new URLSearchParams(window.location.search);
    let redirectUrl = urlParams.get('redirect') || '/index.html';
    
    const emailInput = document.getElementById('login-email');
    const passwordInput = document.getElementById('login-password');
    
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
            saveAuthData(result);
            alert(`✅ Вход успешен! Добро пожаловать, ${result.user.nickname}!`);
            
            setTimeout(() => {
                window.location.href = result.redirect_to || redirectUrl;
            }, 1500);
        } else {
            alert('❌ Ошибка входа: ' + (result.message || 'Неверный email или пароль'));
        }
    } catch (error) {
        console.error('🔥 Ошибка при входе:', error);
        alert('🚫 Ошибка подключения к серверу');
    }
}

async function handleRegistration(API_BASE) {
    console.log('🎯 Обработка регистрации...');
    
    const urlParams = new URLSearchParams(window.location.search);
    let redirectUrl = urlParams.get('redirect') || '/index.html';

    const getValue = (id) => {
        const element = document.getElementById(id);
        return element ? element.value.trim() : '';
    };
    
    const email = getValue('reg-email');
    const password = getValue('reg-password');
    const confirmPassword = getValue('reg-confirm-password');
    const nickname = getValue('reg-nickname');
    const name = getValue('reg-name');
    const lastName = getValue('reg-surname');
    const agreement = document.getElementById('reg-agreement');
    
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
    
    if (!agreement || !agreement.checked) {
        alert('Необходимо согласиться с условиями');
        return;
    }
    
    // Генерация цвета
    function generateRandomColor() {
        const brightColors = [
            '#FF6B6B', '#4ECDC4', '#FFD166', '#06D6A0',
            '#118AB2', '#7209B7', '#FF9E6D', '#83E377'
        ];
        return brightColors[Math.floor(Math.random() * brightColors.length)];
    }
    
    // Данные для отправки
    const userData = {
        email: email,
        password: password,
        nickname: nickname,
        name: name,
        last_name: lastName,
        color_frame: generateRandomColor(),
        redirect_url: redirectUrl
    };
    
    console.log('📤 Отправляю регистрацию:', userData);
    
    try {
        const response = await fetch(API_BASE + '/api/auth/register.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(userData)
        });
        
        const result = await response.json();
        console.log('📥 Ответ сервера:', result);
        
        if (result.success) {
            saveAuthData(result);
            alert(`✅ Регистрация успешна! Добро пожаловать, ${result.nickname}!`);
            
            setTimeout(() => {
                window.location.href = result.redirect_to || redirectUrl;
            }, 1500);
        } else {
            alert('❌ Ошибка: ' + (result.message || 'Неизвестная ошибка'));
        }
    } catch (error) {
        console.error('🔥 Ошибка:', error);
        alert('🚫 Ошибка подключения к серверу');
    }
}

function saveAuthData(result) {
    if (result.token) {
        localStorage.setItem('auth_token', result.token);
    }
    if (result.user && result.user.nickname) {
        localStorage.setItem('user_nickname', result.user.nickname);
    } else if (result.nickname) {
        localStorage.setItem('user_nickname', result.nickname);
    }
    if (result.user && result.user.actor_id) {
        localStorage.setItem('user_id', result.user.actor_id.toString());
    } else if (result.actor_id) {
        localStorage.setItem('user_id', result.actor_id.toString());
    }
    if (result.user && result.user.global_status) {
        localStorage.setItem('user_status', result.user.global_status);
    } else if (result.global_status) {
        localStorage.setItem('user_status', result.global_status);
    } else {
        localStorage.setItem('user_status', 'Участник ТЦ');
    }
    
    // Сохраняем цвет если есть
    const colorFrame = (result.user && result.user.color_frame) || result.color_frame;
    if (colorFrame) {
        localStorage.setItem('user_color_frame', colorFrame);
        console.log('🎨 Color frame сохранен:', colorFrame);
    }
    
    console.log('💾 Данные авторизации сохранены');
}

console.log('🚀 Auth Fixed инициализация завершена!');