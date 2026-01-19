// main-updated.js - Упрощенная версия для интеграции с существующими модулями
// Версия для архитектуры "Тонкий UI-менеджер"
// Исправлено согласно структуре БД (таблица actor, статусы и т.д.)

// ========== ОБЪЯВЛЯЕМ AppUpdated В НАЧАЛЕ ==========
const AppUpdated = (function() {
    // Конфигурация UI-элементов (не API!)
    const config = {
        defaultLocations: [
            { name: 'Москва', type: 'город', region: 'Москва' },
            { name: 'Санкт-Петербург', type: 'город', region: 'Санкт-Петербург' },
            { name: 'Казань', type: 'город', region: 'Татарстан' },
            { name: 'Уфа', type: 'город', region: 'Башкортостан' },
            { name: 'Екатеринбург', type: 'город', region: 'Свердловская область' },
            { name: 'Красноярск', type: 'город', region: 'Красноярский край' },
            { name: 'Новосибирск', type: 'город', region: 'Новосибирская область' },
            { name: 'Иркутск', type: 'город', region: 'Иркутская область' },
            { name: 'Чита', type: 'город', region: 'Забайкальский край' },
            { name: 'Хабаровск', type: 'город', region: 'Хабаровский край' },
            { name: 'Владивосток', type: 'город', region: 'Приморский край' },
            { name: 'Улан-Удэ', type: 'город', region: 'Бурятия' }
        ],
        hexagonButtons: {
            'projectsBtn': 'pages/Projects.html',
            'ideasBtn': 'pages/Ideas.html',
            'actorsBtn': 'pages/actors.html',
            'resourcesBtn': 'pages/resources.html',
            'topicsBtn': 'pages/topics.html',
            'eventsBtn': 'pages/events.html'
        },
        panelSVGs: {
            'calendar': 'images/MyCalendar.svg',
            'tasks': 'images/MyTasks.svg',
            'notifications': 'images/MyNotifications.svg',
            'messages': 'images/MyMessages.svg',
            'conversations': 'images/MyConversations.svg',
            'themes': 'images/MyThemes.svg'
        },
        // Соответствие ID статусов из БД и их названий
        statusMap: {
            1: 'Руководитель ТЦ',
            2: 'Куратор направления',
            3: 'Проектный куратор',
            4: 'Руководитель проекта',
            5: 'Администратор проекта',
            6: 'Участник проекта',
            7: 'Участник ТЦ'
        }
    };

    // DOM элементы
    const elements = {
        cityName: document.getElementById('cityName'),
        cityDropdown: document.getElementById('cityDropdown'),
        newCityInput: document.getElementById('newCityInput'),
        addCityBtn: document.getElementById('addCityBtn'),
        notification: document.getElementById('notification'),
        preloader: document.getElementById('preloader'),
        sidebarPanels: document.getElementById('sidebarPanels'),
        howItWorksLink: document.getElementById('howItWorksLink'),
        headerButtons: document.querySelector('.header-buttons'),
        enterButton: document.querySelector('.enter-button'),
        helpButton: document.querySelector('.help-button')
    };

    // Состояние приложения - УПРОЩЕННАЯ ВЕРСИЯ
    let appState = {
        isAuthenticated: false,
        currentUser: null,
        panelsInitialized: false,
        currentLocation: null,
        locations: []
    };

    // ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (определяем в начале) ==========
    
    // Показать уведомление
    function showNotification(message, type = 'info') {
        if (!elements.notification) {
            console.log(`[${type}] ${message}`);
            return;
        }
        
        elements.notification.textContent = message;
        elements.notification.className = `notification ${type} show`;
        
        setTimeout(() => {
            elements.notification.classList.remove('show');
        }, 3000);
    }

    // Скрыть прелоадер
    function hidePreloader() {
        if (!elements.preloader) return;
        
        setTimeout(() => {
            elements.preloader.classList.add('hidden');
        }, 500);
    }

    // Переключение выпадающего списка городов
    function toggleCityDropdown(e) {
        if (!elements.cityDropdown) return;
        
        e.stopPropagation();
        elements.cityDropdown.classList.toggle('show');
    }

    // Закрытие выпадающего списка городов
    function closeCityDropdown() {
        if (elements.cityDropdown) {
            elements.cityDropdown.classList.remove('show');
        }
    }

    // Обработка кликов в выпадающем списке
    function handleCityDropdownClick(e) {
        e.stopPropagation();
    }

    // ========== ФУНКЦИИ ДЛЯ РАБОТЫ СО СТАТУСАМИ (согласно БД) ==========
    
    // Получить название статуса по ID из БД
    function getStatusName(statusId) {
        return config.statusMap[statusId] || 'Участник ТЦ';
    }
    
    // Проверка, может ли пользователь создать проект
    function canCreateProject(userStatusId) {
        // Создать проект может любой авторизованный пользователь
        // В БД статусы от 1 (Руководитель ТЦ) до 7 (Участник ТЦ)
        return userStatusId >= 1 && userStatusId <= 7;
    }
    
    // ========== ИНИЦИАЛИЗАЦИЯ ПРИЛОЖЕНИЯ ==========
    async function init() {
        try {
            console.log('🚀 AppUpdated запускается (упрощенная версия)...');
            console.log('🔍 Проверяем элементы DOM:', {
                cityName: !!elements.cityName,
                enterButton: !!elements.enterButton,
                sidebarPanels: !!elements.sidebarPanels
            });
            
            // Показываем прелоадер если есть
            if (elements.preloader) {
                elements.preloader.style.display = 'block';
            }
            
            // Проверяем доступность глобальных модулей
            checkGlobalDependencies();
            
            // Определяем состояние авторизации
            await refreshAuthState();
            ensureNickname();
            
            // Инициализируем систему прав (auth-permissions.js) если есть
            await initAuthPermissions();
            
            // Настраиваем обработчики событий
            setupEventListeners();
            
            // Инициализируем города/локации
            initializeCities();
            
            // Настраиваем навигацию
            setupNavigation();
            
            // Настраиваем шестиугольные кнопки
            setupHexagonButtons();
            
            // Настраиваем выпадающие меню
            setupDropdownMenu();
            
            // Обновляем UI в зависимости от статуса
            updateUIByAuthStatus();
            
            // Скрываем прелоадер
            hidePreloader();
            
            // Обновляем индикатор активной страницы
            setTimeout(() => {
                const activeLink = document.querySelector('.nav-link.active');
                if (activeLink) {
                    updateActiveIndicator(activeLink);
                }
            }, 100);
            
            console.log('✅ AppUpdated инициализирован');
            console.log('👤 Текущий пользователь:', appState.currentUser ? {
                nickname: appState.currentUser.nickname,
                status_id: appState.currentUser.status_id,
                status: appState.currentUser.status
            } : 'гость');
            
        } catch (error) {
            console.error('❌ Ошибка инициализации приложения:', error);
            hidePreloader();
            showNotification('Ошибка инициализации приложения', 'error');
        }
    }

    // ========== РАБОТА С ГЛОБАЛЬНЫМИ МОДУЛЯМИ ==========
    
    function checkGlobalDependencies() {
        const missing = [];
        
        if (!window.apiService) {
            console.warn('⚠️ window.apiService не найден. API-запросы могут не работать.');
            missing.push('apiService');
        }
        
        if (!window.authPermissions) {
            console.warn('⚠️ window.authPermissions не найден. Проверка прав может не работать.');
            missing.push('authPermissions');
        }
        
        if (missing.length > 0) {
            console.log('📋 Отсутствующие зависимости:', missing);
        }
    }
    
    async function initAuthPermissions() {
        // Инициализируем auth-permissions.js если он еще не инициализирован
        if (window.authPermissions && typeof window.authPermissions.init === 'function') {
            try {
                await window.authPermissions.init();
                console.log('✅ AuthPermissions инициализирован');
            } catch (error) {
                console.error('❌ Ошибка инициализации AuthPermissions:', error);
            }
        }
    }
    
        // ========== ОБНОВЛЕНИЕ СОСТОЯНИЯ АВТОРИЗАЦИИ ==========
        
    async function refreshAuthState() {
    console.log('🔄 Обновление состояния авторизации...');
    
    // Определяем статус авторизации - проверяем несколько источников
    const token = localStorage.getItem('auth_token');
    const userDataStr = localStorage.getItem('user_data');
    
    appState.isAuthenticated = !!(token || userDataStr);
    
    if (appState.isAuthenticated) {
        try {
            // Пробуем получить данные из разных источников
            let userData = null;
            
            // 1. Пробуем из user_data (если communications-icons.js сохранил)
            if (userDataStr) {
                try {
                    const parsedUserData = JSON.parse(userDataStr);
                    if (parsedUserData && parsedUserData.actor_id) {
                        userData = parsedUserData;
                        console.log('📦 Данные пользователя взяты из user_data:', {
                            nickname: userData.nickname,
                            actor_id: userData.actor_id
                        });
                    }
                } catch (e) {
                    console.warn('⚠️ Ошибка парсинга user_data:', e);
                }
            }
            
            // 2. Пробуем из authPermissions
            if (!userData && window.authPermissions && window.authPermissions.currentUser) {
                userData = window.authPermissions.currentUser;
                console.log('📦 Данные пользователя взяты из authPermissions:', {
                    nickname: userData.nickname,
                    actor_id: userData.actor_id
                });
            }
            // 3. Пробуем из window.currentUser
            else if (!userData && window.currentUser && window.currentUser.actor_id) {
                userData = window.currentUser;
                console.log('📦 Данные пользователя взяты из window.currentUser:', {
                    nickname: userData.nickname,
                    actor_id: userData.actor_id
                });
            }
            // 4. Собираем из localStorage отдельных полей
            else if (!userData) {
                const userId = localStorage.getItem('user_id');
                const nickname = localStorage.getItem('user_nickname');
                const statusId = localStorage.getItem('user_status_id') || '7';
                
                if (userId || nickname) {
                    userData = {
                        actor_id: userId ? parseInt(userId) : null,
                        nickname: nickname || 'Пользователь',
                        status_id: parseInt(statusId),
                        status: getStatusName(parseInt(statusId)),
                        actor_status: getStatusName(parseInt(statusId)),
                        email: localStorage.getItem('user_email') || '',
                        account: localStorage.getItem('user_account') || '',
                        color_frame: localStorage.getItem('user_color_frame') || getRandomColor(),
                        actor_type_id: parseInt(localStorage.getItem('user_type_id') || '1')
                    };
                    console.log('📦 Данные пользователя собраны из localStorage:', {
                        nickname: userData.nickname,
                        actor_id: userData.actor_id
                    });
                }
            }
            
            appState.currentUser = userData;
            
            if (!userData) {
                console.warn('⚠️ Есть токен/user_data, но не удалось получить данные пользователя');
                appState.isAuthenticated = false;
            }
            
        } catch (error) {
            console.error('❌ Ошибка получения данных пользователя:', error);
            appState.currentUser = null;
            appState.isAuthenticated = false;
        }
    } else {
        appState.currentUser = null;
        console.log('👤 Пользователь не авторизован (нет токена и user_data)');
    }
    
    console.log('📊 Текущий статус:', {
        isAuthenticated: appState.isAuthenticated,
        user: appState.currentUser ? appState.currentUser.nickname : 'гость',
        status_id: appState.currentUser ? appState.currentUser.status_id : 'нет',
        full_user_object: appState.currentUser
    });
    
    return appState.isAuthenticated;
}

// Функция для принудительного обновления nickname
function ensureNickname() {
    if (appState.currentUser && !appState.currentUser.nickname) {
        // Пробуем получить nickname из разных источников
        const sources = [
            localStorage.getItem('user_nickname'),
            localStorage.getItem('user_data') ? JSON.parse(localStorage.getItem('user_data')).nickname : null,
            window.currentUser?.nickname,
            window.authPermissions?.currentUser?.nickname
        ];
        
        for (const source of sources) {
            if (source) {
                appState.currentUser.nickname = source;
                console.log('✅ Nickname установлен из источника:', source);
                return;
            }
        }
        
        // Если ничего не найдено, установите значение по умолчанию
        appState.currentUser.nickname = 'Пользователь';
        console.log('⚠️ Nickname установлен по умолчанию');
    }
}
    
    // ========== ОБНОВЛЕНИЕ UI ==========
    
    function updateUIByAuthStatus() {
    console.log('🎨 Обновление UI по статусу авторизации...', {
        isAuthenticated: appState.isAuthenticated,
        user: appState.currentUser ? appState.currentUser.nickname : 'гость'
    });
    
    // Обновляем кнопку входа/профиля
    updateEnterButton();
    
    // Инициализируем или скрываем панели
    if (appState.isAuthenticated && appState.currentUser) {
        console.log('👤 Показываем панели для авторизованного пользователя');
        initSidebarPanels();
    } else {
        console.log('👥 Скрываем панели для гостя');
        // Скрываем панели для гостей
        if (elements.sidebarPanels) {
            elements.sidebarPanels.style.display = 'none';
        }
        // Также сбрасываем флаг инициализации
        appState.panelsInitialized = false;
    }
    
    // Применяем права к UI (через authPermissions если есть)
    if (window.authPermissions && typeof window.authPermissions.applyPermissionsToUI === 'function') {
        try {
            window.authPermissions.applyPermissionsToUI();
        } catch (error) {
            console.error('Ошибка применения прав к UI:', error);
        }
    }
    }
    
    // ========== ОБНОВЛЕНИЕ КНОПКИ ВХОДА ==========
    
    function updateEnterButton() {
        if (!elements.enterButton) {
            console.error('❌ Кнопка входа не найдена');
            return;
        }
        
        console.log('🔄 Обновление кнопки входа, статус:', appState.isAuthenticated ? 'авторизован' : 'гость');
        
        if (appState.isAuthenticated && appState.currentUser) {
            updateEnterButtonToProfile();
        } else {
            resetEnterButton();
        }
    }
    
    // Функции для обновления кнопки входа на профиль
    function getRandomColor() {
        const colors = [
            '#FF6B6B', '#4ECDC4', '#FFD166', '#06D6A0',
            '#118AB2', '#7209B7', '#FF9E6D', '#83E377'
        ];
        return colors[Math.floor(Math.random() * colors.length)];
    }
    
    function getActorIconPath(actorTypeId) {
        const typeId = actorTypeId || 1;
        switch(typeId) {
            case 1: return '../images/PersActor.svg';
            case 2: return '../images/CommActor.svg';
            case 3: return '../images/OrgActor.svg';
            default: return '../images/PersActor.svg';
        }
    }
    
    function addLogoutLink() {
        if (document.getElementById('logoutLinkContainer')) {
            return;
        }
        
        const headerButtons = document.querySelector('.header-buttons');
        if (!headerButtons) return;
        
        const logoutLink = document.createElement('a');
        logoutLink.id = 'logoutLinkContainer';
        logoutLink.href = '#';
        logoutLink.className = 'logout-link';
        logoutLink.textContent = 'Выйти';
        
        logoutLink.addEventListener('click', function(e) {
            e.preventDefault();
            handleLogout();
        });
        
        headerButtons.appendChild(logoutLink);
    }
    
    function handleLogout() {
    if (confirm('Вы уверены, что хотите выйти?')) {
        console.log('🚪 Начало выхода из системы...');
        
        // 1. Очищаем ВСЕ данные авторизации в localStorage
        const keysToRemove = [
            'auth_token',
            'user_data',           // Ключ из communications-icons.js
            'user_nickname',
            'user_id',
            'user_status_id',
            'user_status',
            'user_email',
            'user_account',
            'user_color_frame',
            'user_type_id',
            'token',
            'prostvor_token',
            // Ключи для обратной совместимости
            'actor_nickname',
            'actor_id',
            'actor_status',
            'actor_data',
            'actor_color_frame',
            'actor_email',
            'actor_status_id'
        ];
        
        keysToRemove.forEach(key => {
            if (localStorage.getItem(key)) {
                localStorage.removeItem(key);
                console.log(`🗑️ Удален ключ: ${key}`);
            }
        });
        
        // 2. Также очищаем sessionStorage на всякий случай
        sessionStorage.clear();
        console.log('🗑️ sessionStorage очищен');
        
        // 3. Сбрасываем глобальные объекты если они есть
        if (window.currentUser) {
            window.currentUser = {
                actor_id: null,
                global_status: 'Гость',
                project_roles: {},
                permissions: {}
            };
            console.log('🔄 window.currentUser сброшен');
        }
        
        if (window.authPermissions) {
            try {
                window.authPermissions.setGuestMode();
                console.log('🔄 authPermissions переведен в режим гостя');
            } catch (e) {
                console.error('Ошибка сброса authPermissions:', e);
            }
        }
        
        // 4. Отправляем глобальное событие о выходе
        window.dispatchEvent(new CustomEvent('user-logged-out', {
            detail: { timestamp: Date.now() }
        }));
        console.log('📢 Отправлено событие user-logged-out');
        
        // 5. Сбрасываем состояние AppUpdated
        appState.isAuthenticated = false;
        appState.currentUser = null;
        appState.panelsInitialized = false;
        
        // 6. Удаляем кастомные CSS переменные
        document.documentElement.style.removeProperty('--user-color-frame');
        
        // 7. Сбрасываем кнопку входа (ОЧЕНЬ ВАЖНО!)
        resetEnterButton();
        
        // 8. Скрываем панели для гостей
        if (elements.sidebarPanels) {
            elements.sidebarPanels.style.display = 'none';
        }
        
        // 9. Очищаем данные communications-icons.js
        if (window.CommunicationsManager) {
            try {
                // Вызываем метод сброса если он есть
                if (typeof window.CommunicationsManager.reset === 'function') {
                    window.CommunicationsManager.reset();
                }
                // Или сбрасываем глобальные переменные
                if (window.CommunicationsManager.currentUser) {
                    window.CommunicationsManager.currentUser = null;
                }
                if (window.CommunicationsManager.selectedItem) {
                    window.CommunicationsManager.selectedItem = null;
                }
                console.log('🔄 CommunicationsManager сброшен');
            } catch (e) {
                console.error('Ошибка сброса CommunicationsManager:', e);
            }
        }
        
        // 10. Показываем уведомление
        showNotification('Вы успешно вышли из системы', 'success');
        
        console.log('✅ Выход выполнен, перезагружаем страницу...');
        
        // 11. Перезагружаем страницу через секунду
        setTimeout(() => {
            window.location.reload();
        }, 1000);
    }
    }
    
    // Обновляет кнопку "Войти" на "Профиль" для авторизованных пользователей
    function updateEnterButtonToProfile() {
        if (!elements.enterButton || !appState.currentUser) {
            console.error('❌ Не могу обновить кнопку: enterButton или currentUser отсутствует');
            return;
        }
        
        const user = appState.currentUser;
        console.log('🔧 Обновляю кнопку входа на значок участника для:', user.nickname);
        
        // Проверяем, не обновили ли уже
        if (elements.enterButton.classList.contains('user-display-button')) {
            console.log('⚠️ Кнопка уже обновлена');
            return;
        }

        // ВАЖНО: Принудительно показываем кнопку
            elements.enterButton.style.display = 'block';
            elements.enterButton.style.visibility = 'visible';
            elements.enterButton.style.opacity = '1';
        
        // Получаем цвет рамки из localStorage или генерируем случайный
        const colorFrame = user.color_frame || localStorage.getItem('user_color_frame') || getRandomColor();
        
        // Сохраняем цвет в CSS переменной
        document.documentElement.style.setProperty('--user-color-frame', colorFrame);
        
        // Получаем тип участника для иконки (по умолчанию 1 - Человек)
        const actorTypeId = user.actor_type_id || 1;
        const iconPath = getActorIconPath(actorTypeId);
        
        // Получаем статус пользователя
        const statusText = user.status || user.actor_status || getStatusName(user.status_id) || 'Участник ТЦ';
        
        // Создаем HTML для значка участника
        const userDisplayHTML = `
            <div class="user-display-button-content">
                <div class="user-icon">
                    <img src="${iconPath}" alt="Иконка участника">
                </div>
                <div class="user-info">
                    <div class="user-nickname">${user.nickname}</div>
                    <div class="user-status">${statusText}</div>
                </div>
            </div>
        `;
        
        // Сохраняем оригинальный HTML
        const originalHTML = elements.enterButton.innerHTML;
        elements.enterButton.setAttribute('data-original-html', originalHTML);
        
        // Меняем содержимое кнопки
        elements.enterButton.innerHTML = userDisplayHTML;
        
        // Обновляем стили кнопки через класс
        elements.enterButton.classList.add('user-display-button');
        
        // Удаляем старый обработчик и добавляем новый
        const oldEnterButton = elements.enterButton;
        const newButton = oldEnterButton.cloneNode(true);
        oldEnterButton.parentNode.replaceChild(newButton, oldEnterButton);
        
        // Обновляем ссылку на элемент
        elements.enterButton = document.querySelector('.enter-button');
        
        // Добавляем обработчик для профиля
        elements.enterButton.addEventListener('click', handleProfileClick);
        
        // Добавляем ссылку выхода
        addLogoutLink();
        
        console.log('✅ Кнопка обновлена на значок участника');
    }
    
    // Сброс кнопки на "Войти"
    function resetEnterButton() {
        if (!elements.enterButton) {
            console.error('❌ Кнопка входа не найдена для сброса');
            return;
        }
        
        console.log('🔄 Сброс кнопки входа (выход из системы)');
        
        // 1. Удаляем CSS переменную
        document.documentElement.style.removeProperty('--user-color-frame');
        
        // 2. Убираем класс пользовательского отображения
        elements.enterButton.classList.remove('user-display-button');
        
        // 3. ОЧИЩАЕМ ВСЕ существующие обработчики (клонируем элемент)
        const newButton = elements.enterButton.cloneNode(true);
        elements.enterButton.parentNode.replaceChild(newButton, elements.enterButton);
        
        // 4. Обновляем ссылку на элемент
        elements.enterButton = document.querySelector('.enter-button');
        
        // 5. Устанавливаем стандартное содержимое для кнопки входа
        elements.enterButton.innerHTML = `
            <img src="images/enter-reg.svg" alt="Войти/Зарегистрироваться" class="enter-button-img">
        `;
        
        // 6. Удаляем все возможные обработчики onclick
        elements.enterButton.onclick = null;
        elements.enterButton.removeAttribute('onclick');
        
        // 7. Добавляем НОВЫЙ обработчик для перехода на страницу входа
        elements.enterButton.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('🎯 Кнопка "Войти" нажата (после выхода)');
            window.location.href = 'pages/enter-reg.html';
        });
        
        // 8. Убедимся, что кнопка видима
        elements.enterButton.style.display = 'block';
        elements.enterButton.style.visibility = 'visible';
        elements.enterButton.style.opacity = '1';
        elements.enterButton.style.pointerEvents = 'auto';
        
        // 9. Удаляем ссылку выхода
        const logoutLink = document.getElementById('logoutLinkContainer');
        if (logoutLink) {
            logoutLink.remove();
            console.log('🗑️ Ссылка "Выйти" удалена');
        }
        
        // 10. Также скрываем любой возможный user-display-container
        const userDisplayContainer = document.querySelector('.user-display-container');
        if (userDisplayContainer) {
            userDisplayContainer.style.display = 'none';
        }
        
        console.log('✅ Кнопка входа полностью сброшена');
    }
    
    // Обработка кнопки входа
    function handleEnterButton() {
        if (appState.isAuthenticated && appState.currentUser) {
            handleProfileClick();
        } else {
            window.location.href = 'pages/enter-reg.html';
        }
    }
    
    // Обработка клика по профилю
    function handleProfileClick() {
        if (appState.currentUser) {
            const user = appState.currentUser;
            const statusText = user.status || user.actor_status || getStatusName(user.status_id) || 'Участник ТЦ';
            alert(`Вы вошли как: ${user.nickname}\nСтатус: ${statusText}\nID: ${user.actor_id}`);
        }
    }
    
    // ========== БОКОВЫЕ ПАНЕЛИ ==========
    
    // Инициализация боковых панелей
    function initSidebarPanels() {
        if (appState.panelsInitialized || !elements.sidebarPanels) return;
        
        try {
            console.log('🎯 Инициализация боковых панелей...');
            
            // Показываем панели
            elements.sidebarPanels.style.display = 'block';
            
            // Инициализируем счетчики
            initializePanelCounters();
            
            // Настраиваем обработчики
            setupPanelEventListeners();
            
            // Загружаем SVG изображения
            loadPanelSVGs();
            
            appState.panelsInitialized = true;
            console.log('✅ Боковые панели инициализированы');
            
        } catch (error) {
            console.error('❌ Ошибка инициализации боковых панелей:', error);
        }
    }

    // Инициализация счетчиков панелей
    function initializePanelCounters() {
        const panels = ['calendar', 'tasks', 'notifications', 'messages', 'conversations', 'themes'];
        
        panels.forEach(panelId => {
            let count = localStorage.getItem(`panel_${panelId}_count`);
            if (!count) {
                count = Math.floor(Math.random() * 10).toString();
                localStorage.setItem(`panel_${panelId}_count`, count);
            }
            
            updatePanelDisplay(panelId, parseInt(count));
        });
    }

    // Обновление отображения счетчика панели
    function updatePanelDisplay(panelId, count) {
        const counterElement = document.getElementById(`${panelId}Count`);
        if (counterElement) {
            counterElement.textContent = count;
        }
        
        const labelElement = document.querySelector(`.panel-label[data-panel="${panelId}"]`);
        if (labelElement) {
            labelElement.setAttribute('data-count', count);
        }
    }

    // Настройка обработчиков событий для панелей
    function setupPanelEventListeners() {
        const panelLabels = document.querySelectorAll('.panel-label');
        panelLabels.forEach(label => {
            label.addEventListener('click', function(e) {
                e.stopPropagation();
                const panelId = this.getAttribute('data-panel');
                togglePanel(panelId);
            });
        });
        
        const closeButtons = document.querySelectorAll('.panel-close');
        closeButtons.forEach(button => {
            button.addEventListener('click', function(e) {
                e.stopPropagation();
                const panel = this.closest('.sidebar-panel');
                if (panel) {
                    panel.classList.remove('active');
                }
            });
        });
        
        document.addEventListener('click', function(e) {
            if (!e.target.closest('.sidebar-panel')) {
                const activePanels = document.querySelectorAll('.sidebar-panel.active');
                activePanels.forEach(panel => {
                    panel.classList.remove('active');
                });
            }
        });
    }

    // Переключение панели
    function togglePanel(panelId) {
        const panel = document.querySelector(`.sidebar-panel[data-panel="${panelId}"]`);
        if (!panel) return;
        
        const allPanels = document.querySelectorAll('.sidebar-panel.active');
        allPanels.forEach(p => {
            if (p !== panel) {
                p.classList.remove('active');
            }
        });
        
        panel.classList.toggle('active');
        
        if (panel.classList.contains('active')) {
            updatePanelCounter(panelId);
        }
    }

    // Обновление счетчика панели
    function updatePanelCounter(panelId) {
        const randomCount = Math.floor(Math.random() * 10);
        updatePanelDisplay(panelId, randomCount);
        localStorage.setItem(`panel_${panelId}_count`, randomCount.toString());
    }

    // Загрузка SVG изображений для панелей
    function loadPanelSVGs() {
        const panelContents = document.querySelectorAll('.panel-content');
        
        panelContents.forEach(panelContent => {
            const panelId = panelContent.closest('.sidebar-panel').dataset.panel;
            const svgPath = config.panelSVGs[panelId];
            
            if (svgPath) {
                const placeholder = panelContent.querySelector('.panel-placeholder');
                if (placeholder) {
                    const img = document.createElement('img');
                    img.src = svgPath;
                    img.alt = panelId;
                    img.style.width = '100%';
                    img.style.height = '100%';
                    img.style.objectFit = 'contain';
                    
                    placeholder.innerHTML = '';
                    placeholder.appendChild(img);
                }
            }
        });
    }

    // ========== ГОРОДА И ЛОКАЦИИ ==========
    
    // Инициализация городов
    function initializeCities() {
        if (!elements.cityName) {
            console.warn('⚠️ Элемент cityName не найден');
            return;
        }
        
        const savedCity = localStorage.getItem('selectedCity') || 'Улан-Удэ';
        elements.cityName.textContent = savedCity;
        
        loadCities();
    }

    // Загрузка городов
    function loadCities() {
        const savedCities = JSON.parse(localStorage.getItem('citiesList') || 'null');
        if (savedCities && Array.isArray(savedCities)) {
            renderCitiesList(savedCities);
        } else {
            // Используем только названия городов из defaultLocations
            const cityNames = config.defaultLocations.map(loc => loc.name);
            renderCitiesList(cityNames);
            localStorage.setItem('citiesList', JSON.stringify(cityNames));
        }
    }

    // Рендер списка городов
    function renderCitiesList(cities) {
        if (!elements.cityDropdown) {
            console.warn('⚠️ Элемент cityDropdown не найден');
            return;
        }
        
        const addCityForm = document.querySelector('.add-city');
        
        // Очищаем только элементы городов
        const cityItems = elements.cityDropdown.querySelectorAll('.city-item:not(.no-results)');
        cityItems.forEach(item => item.remove());
        
        const noResults = elements.cityDropdown.querySelector('.no-results');
        if (noResults) noResults.remove();
        
        // Добавляем города
        cities.forEach(city => {
            const cityItem = document.createElement('div');
            cityItem.className = 'city-item';
            cityItem.textContent = city;
            cityItem.style.padding = '10px';
            cityItem.style.cursor = 'pointer';
            cityItem.style.borderBottom = '1px solid #eee';
            
            cityItem.addEventListener('mouseenter', function() {
                this.style.backgroundColor = '#f5f5f5';
            });
            
            cityItem.addEventListener('mouseleave', function() {
                this.style.backgroundColor = '';
            });
            
            cityItem.addEventListener('click', function() {
                selectCity(city);
            });
            
            if (addCityForm) {
                elements.cityDropdown.insertBefore(cityItem, addCityForm);
            } else {
                elements.cityDropdown.appendChild(cityItem);
            }
        });
    }

    // Выбор города
    function selectCity(city) {
        if (elements.cityName) {
            elements.cityName.textContent = city;
        }
        
        if (elements.cityDropdown) {
            elements.cityDropdown.classList.remove('show');
        }
        
        localStorage.setItem('selectedCity', city);
        showNotification(`Город изменён на: ${city}`, 'success');
    }

    // Добавление нового города
    function addNewCity(e) {
        e.preventDefault();
        
        if (!elements.newCityInput) return;
        
        const newCity = elements.newCityInput.value.trim();
        
        if (!newCity) {
            showNotification('Введите название города', 'warning');
            return;
        }
        
        if (newCity.length < 2) {
            showNotification('Название должно содержать не менее 2 символов', 'warning');
            return;
        }
        
        try {
            const savedCities = JSON.parse(localStorage.getItem('citiesList') || 'null') || 
                               config.defaultLocations.map(loc => loc.name);
            
            if (savedCities.some(city => city.toLowerCase() === newCity.toLowerCase())) {
                showNotification(`Город "${newCity}" уже есть в списке!`, 'warning');
                return;
            }
            
            savedCities.push(newCity);
            localStorage.setItem('citiesList', JSON.stringify(savedCities));
            
            renderCitiesList(savedCities);
            elements.newCityInput.value = '';
            selectCity(newCity);
            
            showNotification(`Город "${newCity}" добавлен`, 'success');
            
        } catch (error) {
            console.error('Ошибка добавления города:', error);
            showNotification('Ошибка при добавлении города', 'error');
        }
    }

    // ========== НАВИГАЦИЯ ==========
    
    // Настройка навигации
    function setupNavigation() {
        const navLinks = document.querySelectorAll('.nav-link');
        const currentPage = window.location.pathname.split('/').pop() || 'index.html';
        
        console.log('📍 Текущая страница:', currentPage);
        
        navLinks.forEach(link => {
            link.classList.remove('active');
            
            const linkHref = link.getAttribute('href');
            const linkPage = linkHref ? linkHref.split('/').pop() : '';
            
            if (linkPage === currentPage || 
                (currentPage === '' && linkHref === 'index.html') ||
                (currentPage === 'index.html' && linkHref === 'index.html')) {
                
                link.classList.add('active');
                updateActiveIndicator(link);
            }
        });
    }

    // Обновление индикатора
    function updateActiveIndicator(activeLink) {
        const activeIndicator = document.getElementById('activeIndicator');
        if (!activeIndicator || !activeLink) return;
        
        const linkRect = activeLink.getBoundingClientRect();
        const navContainer = activeLink.closest('.nav-container');
        const containerRect = navContainer.getBoundingClientRect();
        
        const left = linkRect.left - containerRect.left;
        const width = linkRect.width;
        
        activeIndicator.style.left = left + 'px';
        activeIndicator.style.width = width + 'px';
        activeIndicator.style.transition = 'all 0.3s ease';
    }

    // Настройка шестиугольных кнопки
    function setupHexagonButtons() {
        Object.keys(config.hexagonButtons).forEach(buttonId => {
            const button = document.getElementById(buttonId);
            if (button) {
                button.addEventListener('click', () => {
                    window.location.href = config.hexagonButtons[buttonId];
                });
            } else {
                console.warn(`⚠️ Кнопка ${buttonId} не найдена`);
            }
        });
    }

    // Настройка выпадающих меню навигации
    function setupDropdownMenu() {
        const navItems = document.querySelectorAll('.nav-item');
        
        navItems.forEach(navItem => {
            const dropdown = navItem.querySelector('.nav-dropdown');
            if (!dropdown) return;
            
            const dropdownItems = dropdown.querySelectorAll('.dropdown-item');
            
            dropdownItems.forEach(item => {
                if (item.textContent.trim() === 'Создать новый Проект') {
                    item.addEventListener('click', function(e) {
                        e.preventDefault();
                        handleCreateProjectFromMenu();
                    });
                }
            });
        });
    }

    // Обработка создания проекта из меню
    function handleCreateProjectFromMenu() {
        console.log('🎯 Проверка прав для создания проекта');
        
        if (!appState.isAuthenticated || !appState.currentUser) {
            showNotification('Для создания проекта необходимо авторизоваться', 'warning');
            return;
        }
        
        const userStatusId = appState.currentUser.status_id;
        
        if (canCreateProject(userStatusId)) {
            window.location.href = 'pages/ProjectMain.html';
        } else {
            const statusName = getStatusName(userStatusId);
            showNotification(`Для создания проекта ваш статус "${statusName}" недостаточен`, 'error');
        }
    }

    // ========== НАСТРОЙКА ОБРАБОТЧИКОВ СОБЫТИЙ ==========
    function setupEventListeners() {
        console.log('🔧 Настройка обработчиков событий...');
        
        // Городской селектор
        if (elements.cityName) {
            elements.cityName.addEventListener('click', toggleCityDropdown);
            document.addEventListener('click', closeCityDropdown);
        }
        
        if (elements.cityDropdown) {
            elements.cityDropdown.addEventListener('click', handleCityDropdownClick);
        }
        
        if (elements.addCityBtn) {
            elements.addCityBtn.addEventListener('click', addNewCity);
        }
        
        if (elements.newCityInput) {
            elements.newCityInput.addEventListener('keypress', function(e) {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    addNewCity(e);
                }
            });
        }

        // Кнопки в шапке
        if (elements.helpButton) {
            elements.helpButton.addEventListener('click', function() {
                showNotification('Функционал помощи в разработке', 'info');
            });
        }
        
        if (elements.enterButton) {
            // Обработчик будет установлен в resetEnterButton или updateEnterButtonToProfile
        }

        // Ссылка "Как это работает"
        if (elements.howItWorksLink) {
            elements.howItWorksLink.addEventListener('click', function(e) {
                e.preventDefault();
                window.location.href = 'pages/HowItWorks.html';
            });
        }
        
        console.log('✅ Обработчики событий настроены');
    }

    // ========== ПУБЛИЧНЫЕ МЕТОДЫ ==========
    return {
        init: init,
        showNotification: showNotification,
        updateActiveIndicator: updateActiveIndicator,
        
        // Метод для обновления состояния авторизации
        refreshAuthState: refreshAuthState,
        
        // Метод для обновления UI
        updateUI: updateUIByAuthStatus,
        
        // Вспомогательные методы
        getStatusName: getStatusName,
        canCreateProject: canCreateProject,
        
        // Геттеры
        getState: function() {
            return {
                isAuthenticated: appState.isAuthenticated,
                currentUser: appState.currentUser,
                panelsInitialized: appState.panelsInitialized
            };
        },
        
        // Отладочный метод
        debugInfo: function() {
            console.group('📊 AppUpdated Debug Info');
            console.log('Состояние:', this.getState());
            console.log('Глобальные объекты:', {
                apiService: !!window.apiService,
                authPermissions: !!window.authPermissions,
                currentUser: !!window.currentUser
            });
            console.log('Элементы:', {
                sidebarPanels: !!elements.sidebarPanels,
                enterButton: !!elements.enterButton,
                cityName: !!elements.cityName
            });
            console.groupEnd();
        }
    };
})();

// ========== ГЛОБАЛЬНАЯ ИНИЦИАЛИЗАЦИЯ ==========

// Проверяем, находимся ли на странице входа
if (window.location.pathname.includes('enter-reg')) {
    console.log('main-updated.js: Пропускаем инициализацию на странице входа');
} else {
    // Инициализация приложения
    document.addEventListener('DOMContentLoaded', function() {
        // Ждем немного, чтобы другие скрипты успели загрузиться
        setTimeout(() => {
            AppUpdated.init();
        }, 100);
    });
}

// Экспорт для глобального использования
window.AppUpdated = AppUpdated;

// Слушаем события авторизации
window.addEventListener('auth-changed', function() {
    console.log('🎯 Событие auth-changed получено');
    if (window.AppUpdated && window.AppUpdated.refreshAuthState) {
        setTimeout(() => {
            window.AppUpdated.refreshAuthState();
            window.AppUpdated.updateUI();
        }, 100);
    }
});

window.addEventListener('user-logged-in', function(e) {
    console.log('🎯 Событие user-logged-in получено', e.detail);
    if (AppUpdated.refreshAuthState) {
        AppUpdated.refreshAuthState();
        AppUpdated.updateUI();
    }
});

// Также слушаем изменения localStorage
window.addEventListener('storage', function(e) {
    if (e.key === 'auth_token' || e.key === 'user_nickname' || e.key === 'user_status_id') {
        console.log('📦 Изменение в localStorage:', e.key);
        setTimeout(() => {
            if (AppUpdated.refreshAuthState) {
                AppUpdated.refreshAuthState();
                AppUpdated.updateUI();
            }
        }, 100);
    }
});

// Слушаем собственное событие выхода
window.addEventListener('user-logged-out', function() {
    console.log('🎯 AppUpdated получил событие выхода');
    appState.isAuthenticated = false;
    appState.currentUser = null;
    updateUIByAuthStatus();
});

console.log('✅ main-updated.js загружен (упрощенная версия для интеграции)');
console.log('ℹ️ Используйте AppUpdated.refreshAuthState() после авторизации');
