// main-updated.js - Полная версия с поддержкой всех функций

// Проверяем, находимся ли на странице входа
if (window.location.pathname.includes('enter-reg')) {
    console.log('main-updated.js: Пропускаем инициализацию на странице входа');
}

const AppUpdated = (function() {
    // Конфигурация
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

    // Состояние приложения
    let appState = {
        isAuthenticated: false,
        currentUser: null,
        panelsInitialized: false,
        currentLocation: null,
        locations: []
    };

    // Инициализация приложения
    async function init() {
        try {
            console.log('🚀 AppUpdated запускается...');
            console.log('🔍 Поиск элементов DOM:');
            console.log('- .enter-button:', document.querySelector('.enter-button'));
            console.log('- .header-buttons:', document.querySelector('.header-buttons'));
            console.log('- #sidebarPanels:', document.getElementById('sidebarPanels'));
            
            // Показываем прелоадер если есть
            if (elements.preloader) {
                elements.preloader.style.display = 'block';
            }
            
            // Проверяем авторизацию
            await checkAuthStatus();
            
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
            
            // Если пользователь авторизован, инициализируем панели
            if (appState.isAuthenticated && appState.currentUser) {
                initSidebarPanels();
                updateEnterButtonToProfile();
            } else {
                // Если не авторизован, скрываем кнопку профиля
                resetEnterButton();
            }
            
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
            console.log('👤 Пользователь:', appState.currentUser);
            console.log('📊 Авторизован:', appState.isAuthenticated);
            
        } catch (error) {
            console.error('❌ Ошибка инициализации приложения:', error);
            hidePreloader();
        }
    }

    // Проверка статуса авторизации
    async function checkAuthStatus() {
    console.log('🔐 Проверка авторизации...');
    
    const authToken = localStorage.getItem('auth_token');
    
    if (!authToken) {
        console.log('❌ Нет токена в localStorage');
        appState.isAuthenticated = false;
        appState.currentUser = null;
        return false;
    }
    
    try {
        // 1. Проверяем токен
        const verifyResponse = await fetch('/api/auth/verify.php', {
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        
        const verifyData = await verifyResponse.json();
        
        if (!verifyData.success || !verifyData.valid) {
            throw new Error('Токен невалиден');
        }
        
        console.log('✅ Токен валиден');
        
        // 2. Получаем данные пользователя через me.php
        const meResponse = await fetch('/api/auth/me.php', {
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        
        if (!meResponse.ok) {
            throw new Error(`HTTP ${meResponse.status}`);
        }
        
        const meData = await meResponse.json();
        
        if (!meData.success) {
            throw new Error(meData.message || 'Ошибка получения данных');
        }
        
        console.log('📦 Данные пользователя:', meData.actor);
        
        // 3. Создаем объект пользователя
        appState.isAuthenticated = true;
        appState.currentUser = {
            actor_id: meData.actor.actor_id,
            nickname: meData.actor.nickname,
            display_name: meData.actor.display_name || meData.actor.nickname,
            email: meData.actor.email,
            status_id: meData.actor.actor_status_id || 7,
            actor_status: meData.actor.actor_status || 'Участник ТЦ',
            actor_type_id: meData.actor.actor_type_id || 1,
            color_frame: meData.actor.color_frame || '#4ECDC4',
            account: meData.actor.account || ''
        };
        
        // 4. Сохраняем в localStorage для обратной совместимости
        localStorage.setItem('user_id', appState.currentUser.actor_id.toString());
        localStorage.setItem('user_nickname', appState.currentUser.nickname);
        localStorage.setItem('user_email', appState.currentUser.email);
        localStorage.setItem('user_status', appState.currentUser.actor_status);
        localStorage.setItem('user_status_id', appState.currentUser.status_id.toString());
        localStorage.setItem('user_data', JSON.stringify(appState.currentUser));
        
        console.log('✅ Пользователь авторизован:', appState.currentUser.nickname);
        return true;
        
    } catch (error) {
        console.error('❌ Ошибка проверки авторизации:', error);
        appState.isAuthenticated = false;
        appState.currentUser = null;
        localStorage.removeItem('auth_token');
        return false;
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
        switch(actorTypeId) {
            case 1: return '../images/PersActor.svg';    // Человек
            case 2: return '../images/CommActor.svg';    // Сообщество
            case 3: return '../images/OrgActor.svg';     // Организация
            default: return '../images/PersActor.svg';
        }
    }

    function formatUserStatus(status) {
        if (!status) return 'Участник ТЦ';
        
        switch(status) {
            case 'Руководитель ТЦ':
                return 'Руководитель ТЦ';
            case 'Куратор направления':
                return 'Куратор направления';
            default:
                return 'Участник ТЦ';
        }
    }

    function addLogoutLink() {
        // Проверяем, есть ли уже ссылка выхода
        if (document.getElementById('logoutLinkContainer')) {
            return;
        }
        
        const headerButtons = document.querySelector('.header-buttons');
        if (!headerButtons) return;
        
        const logoutLink = document.createElement('a');
        logoutLink.id = 'logoutLinkContainer';
        logoutLink.href = '#';
        logoutLink.className = 'logout-link';
        logoutLink.innerHTML = 'Выйти';
        logoutLink.style.cssText = `
            margin-left: 10px;
            font-size: 12px;
            color: #00B0F0 !important;
            font-weight: bold;
            text-decoration: none;
            cursor: pointer;
            display: block;
        `;
        
        logoutLink.addEventListener('click', function(e) {
            e.preventDefault();
            handleLogout();
        });
        
        headerButtons.appendChild(logoutLink);
    }

    function handleLogout() {
        if (confirm('Вы уверены, что хотите выйти?')) {
            // Очищаем localStorage
            localStorage.removeItem('auth_token');
            localStorage.removeItem('actor_nickname');
            localStorage.removeItem('actor_id');
            localStorage.removeItem('actor_status');
            localStorage.removeItem('actor_data');
            localStorage.removeItem('actor_color_frame');
            localStorage.removeItem('actor_email');
            localStorage.removeItem('actor_status_id');
            
            // Сбрасываем состояние
            appState.isAuthenticated = false;
            appState.currentUser = null;
            
            // Сбрасываем кнопку
            resetEnterButton();
            
            // Удаляем ссылку выхода
            const logoutLink = document.getElementById('logoutLinkContainer');
            if (logoutLink) {
                logoutLink.remove();
            }
            
            // Показываем уведомление
            showNotification('Вы успешно вышли из системы', 'success');
            
            // Через секунду можно перезагрузить страницу
            setTimeout(() => {
                window.location.reload();
            }, 1000);
        }
    }

    // Обновляет кнопку "Войти" на "Профиль" для авторизованных пользователей
    function updateEnterButtonToProfile() {
        if (!elements.enterButton || !appState.currentUser) {
            console.error('❌ Не могу обновить кнопку: enterButton=', elements.enterButton, 'currentUser=', appState.currentUser);
            return;
        }
        
        console.log('🔧 Обновляю кнопку входа на значок участника для:', appState.currentUser.nickname);
        
        // Проверяем, не обновили ли уже
        if (elements.enterButton.classList.contains('user-display-button')) {
            console.log('⚠️ Кнопка уже обновлена');
            return;
        }
        
        // Получаем цвет рамки из localStorage или генерируем случайный
        const colorFrame = localStorage.getItem('user_color_frame') || getRandomColor();
        
        // Получаем тип участника для иконки
        const actorTypeId = appState.currentUser.actor_type_id || 1; // По умолчанию "Человек"
        const iconPath = getActorIconPath(actorTypeId);
        
        // Форматируем статус
        const statusText = formatUserStatus(appState.currentUser.actor_status);
        
        // Создаем HTML для значка участника
        const userDisplayHTML = `
            <div class="user-display-button-content" style="
                background: #595959;
                border: 3px solid ${colorFrame};
                border-radius: 12px;
                padding: 4px 8px;
                min-width: 150px;
                text-align: left;
                cursor: pointer;
                display: flex;
                align-items: center;
                gap: 8px;
                min-height: 40px;
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            ">
                <div class="user-icon" style="width: 24px; height: 24px; flex-shrink: 0;">
                    <img src="${iconPath}" alt="Иконка участника" style="width: 100%; height: 100%; object-fit: contain;">
                </div>
                <div class="user-info" style="flex: 1; min-width: 0; overflow: hidden;">
                    <div class="user-nickname" style="
                        font-size: 12px;
                        font-weight: bold;
                        color: #FFFFFF;
                        white-space: nowrap;
                        overflow: hidden;
                        text-overflow: ellipsis;
                        text-decoration: underline;
                    ">${appState.currentUser.nickname}</div>
                    <div class="user-status" style="
                        font-size: 10px;
                        color: #FFFFFF;
                        white-space: nowrap;
                        overflow: hidden;
                        text-overflow: ellipsis;
                    ">${statusText}</div>
                </div>
            </div>
        `;
        
        // Сохраняем оригинальный HTML
        const originalHTML = elements.enterButton.innerHTML;
        elements.enterButton.setAttribute('data-original-html', originalHTML);
        
        // Меняем содержимое кнопки
        elements.enterButton.innerHTML = userDisplayHTML;
        
        // Обновляем стили кнопки
        elements.enterButton.style.padding = '0';
        elements.enterButton.style.background = 'transparent';
        elements.enterButton.style.border = 'none';
        elements.enterButton.style.minWidth = 'auto';
        
        // Удаляем старый обработчик и добавляем новый
        const newButton = elements.enterButton.cloneNode(true);
        elements.enterButton.parentNode.replaceChild(newButton, elements.enterButton);
        
        // Обновляем ссылку на элемент
        elements.enterButton = document.querySelector('.enter-button');
        
        // Добавляем обработчик для профиля
        elements.enterButton.addEventListener('click', handleProfileClick);
        
        // Добавляем класс для стилизации
        elements.enterButton.classList.add('user-display-button');
        
        // Добавляем ссылку выхода (рядом с кнопкой)
        addLogoutLink();
        
        console.log('✅ Кнопка обновлена на значок участника');
    }

    // Сброс кнопки на "Войти"
    function resetEnterButton() {
        if (!elements.enterButton) return;
        
        // Если есть сохраненный оригинальный HTML, восстанавливаем его
        const originalHTML = elements.enterButton.getAttribute('data-original-html');
        if (originalHTML) {
            elements.enterButton.innerHTML = originalHTML;
        }
        
        // Убираем класс пользовательского отображения
        elements.enterButton.classList.remove('user-display-button');
        
        // Сбрасываем стили
        elements.enterButton.style.padding = '';
        elements.enterButton.style.background = '';
        elements.enterButton.style.border = '';
        elements.enterButton.style.minWidth = '';
        
        // Обновляем обработчик
        const newButton = elements.enterButton.cloneNode(true);
        elements.enterButton.parentNode.replaceChild(newButton, elements.enterButton);
        elements.enterButton = document.querySelector('.enter-button');
        elements.enterButton.addEventListener('click', handleEnterButton);
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
            alert(`Вы вошли как: ${appState.currentUser.nickname}\nСтатус: ${appState.currentUser.actor_status}`);
        }
    }

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

    // Инициализация городов
    function initializeCities() {
        if (!elements.cityName) return;
        
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
        if (!elements.cityDropdown) return;
        
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

    // Настройка навигации
    function setupNavigation() {
        const navLinks = document.querySelectorAll('.nav-link');
        const currentPage = window.location.pathname.split('/').pop() || 'index.html';
        
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

    // Настройка шестиугольных кнопок
    function setupHexagonButtons() {
        Object.keys(config.hexagonButtons).forEach(buttonId => {
            const button = document.getElementById(buttonId);
            if (button) {
                button.addEventListener('click', () => {
                    window.location.href = config.hexagonButtons[buttonId];
                });
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
        
        if (userStatusId >= 7) { // Участник ТЦ и выше
            window.location.href = 'pages/ProjectMain.html';
        } else {
            showNotification(`Для создания проекта ваш статус "${appState.currentUser.actor_status}" недостаточен`, 'error');
        }
    }

    // Настройка обработчиков
    function setupEventListeners() {
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
            elements.enterButton.addEventListener('click', handleEnterButton);
        }

        // Ссылка "Как это работает"
        if (elements.howItWorksLink) {
            elements.howItWorksLink.addEventListener('click', function(e) {
                e.preventDefault();
                window.location.href = 'pages/HowItWorks.html';
            });
        }
    }

    // Переключение выпадающего списка
    function toggleCityDropdown(e) {
        if (!elements.cityDropdown) return;
        
        e.stopPropagation();
        elements.cityDropdown.classList.toggle('show');
    }

    // Закрытие выпадающего списка
    function closeCityDropdown() {
        if (elements.cityDropdown) {
            elements.cityDropdown.classList.remove('show');
        }
    }

    // Обработка кликов в выпадающем списке
    function handleCityDropdownClick(e) {
        e.stopPropagation();
    }

    // Показать уведомление
    function showNotification(message, type = 'info') {
        if (!elements.notification) return;
        
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

    // Публичные методы
    return {
        init: init,
        showNotification: showNotification,
        updateActiveIndicator: updateActiveIndicator,
        
        // Методы для обновления состояния
        refreshAuthState: function() {
            console.log('🔄 Обновление состояния авторизации...');
            checkAuthStatus().then(() => {
                if (appState.isAuthenticated) {
                    initSidebarPanels();
                    updateEnterButtonToProfile();
                } else {
                    resetEnterButton();
                }
            });
        },
        
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
            console.log('Элементы:', {
                sidebarPanels: !!elements.sidebarPanels,
                enterButton: !!elements.enterButton,
                cityName: !!elements.cityName
            });
            console.groupEnd();
        }
    };
})();

// Инициализация приложения
document.addEventListener('DOMContentLoaded', function() {
    AppUpdated.init();
});

// Экспорт
window.AppUpdated = AppUpdated;

// Слушаем события авторизации
window.addEventListener('auth-changed', function() {
    if (window.AppUpdated && window.AppUpdated.refreshAuthState) {
        setTimeout(() => {
            window.AppUpdated.refreshAuthState();
        }, 100);
    }
});

console.log('✅ main-updated.js загружен (полная версия)');
console.log('ℹ️ Используйте AppUpdated.refreshAuthState() после авторизации');