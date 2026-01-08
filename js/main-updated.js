// main-updated.js - Обновленный основной модуль приложения с поддержкой LocacityDatabase
if (window.location.pathname.includes('enter-reg')) {
    // Не инициализируемся на странице входа
    console.log('main-updated.js: Пропускаем инициализацию на странице входа');
    return;
}

const AppUpdated = (function() {
    // Конфигурация
    const config = {
        defaultCities: [
            'Москва', 'Санкт-Петербург', 'Казань', 'Уфа', 
            'Екатеринбург', 'Красноярск', 'Новосибирск', 
            'Иркутск', 'Чита', 'Хабаровск', 'Владивосток'
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
            'calendar': '../images/MyCalendar.svg',
            'tasks': '../images/MyTasks.svg',
            'notifications': '../images/MyNotifications.svg',
            'messages': '../images/MyMessages.svg',
            'conversations': '../images/MyConversations.svg',
            'themes': '../images/MyThemes.svg'
        },
        api: {
            baseURL: 'http://localhost:5000/api',
            endpoints: {
                cities: '/cities',
                actors: '/actors',
                functions: '/functions',
                projects: '/projects'
            }
        }
    };

    // Элементы DOM
    const elements = {
        cityName: document.getElementById('cityName'),
        cityDropdown: document.getElementById('cityDropdown'),
        newCityInput: document.getElementById('newCityInput'),
        addCityBtn: document.getElementById('addCityBtn'),
        notification: document.getElementById('notification'),
        preloader: document.getElementById('preloader'),
        sidebarPanels: document.getElementById('sidebarPanels'),
        howItWorksLink: document.getElementById('howItWorksLink'),
        headerButtons: document.querySelector('.header-buttons')
    };

    // Состояние приложения
    let appState = {
        isAuthenticated: false,
        currentUser: null,
        panelsInitialized: false,
        databases: {
            actors: null,
            locacities: null,
            functions: null,
            directions: null
        }
    };

    // Инициализация приложения
    function init() {
        try {
            // Инициализация баз данных
            initDatabases();
            
            // Проверяем авторизацию
            checkAuthStatus();
            
            setupEventListeners();
            initializeCities();
            setupNavigation();
            setupHexagonButtons();
            setupDropdownMenu();
            
            // Если пользователь авторизован, инициализируем панели
            if (appState.isAuthenticated) {
                initSidebarPanels();
            }
            
            hidePreloader();
            
            setTimeout(() => {
                const activeLink = document.querySelector('.nav-link.active');
                if (activeLink) {
                    updateActiveIndicator(activeLink);
                }
            }, 100);
        } catch (error) {
            console.error('Ошибка инициализации приложения:', error);
            showNotification('Произошла ошибка при загрузке страницы', 'error');
        }
    }

    // Инициализация баз данных
    function initDatabases() {
        try {
            // Проверяем доступность всех баз данных
            appState.databases = {
                actors: typeof ActorsDatabase !== 'undefined' ? ActorsDatabase : null,
                locacities: typeof LocacityDatabase !== 'undefined' ? LocacityDatabase : null,
                functions: typeof FunctionsDatabase !== 'undefined' ? FunctionsDatabase : null,
                directions: typeof CreativeDirectionDatabase !== 'undefined' ? CreativeDirectionDatabase : null
            };
            
            // Логирование статуса загрузки баз данных
            console.log('📊 Статус загрузки баз данных:');
            Object.entries(appState.databases).forEach(([name, db]) => {
                if (db) {
                    console.log(`  ✓ ${name} загружена`);
                } else {
                    console.warn(`  ✗ ${name} не найдена`);
                }
            });
            
            // Особый лог для LocacityDatabase
            if (appState.databases.locacities) {
                const locacityCount = appState.databases.locacities.getAllLocacities().length;
                console.log(`  ✓ LocacityDatabase: ${locacityCount} населённых пунктов загружено`);
            }
            
        } catch (error) {
            console.error('Ошибка инициализации баз данных:', error);
        }
    }

    // Проверка статуса авторизации
    function checkAuthStatus() {
        console.log('🔐 main-updated: проверка авторизации');
        
        // Используем наш единый модуль
        if (window.authInfo) {
            return window.authInfo.authenticated;
        }
        
        // Или проверяем самостоятельно
        const token = localStorage.getItem('prostvor_token') || 
                      sessionStorage.getItem('prostvor_token');
        
        if (token) {
            console.log('✅ main-updated: токен найден');
            return true;
        }
        
        console.log('❌ main-updated: токен не найден');
        return false;
    }

    // Инициализация боковых панелей
    function initSidebarPanels() {
        if (appState.panelsInitialized || !elements.sidebarPanels) return;
        
        try {
            // Показываем панели
            elements.sidebarPanels.style.display = 'block';
            
            // Инициализируем счетчики
            initializePanelCounters();
            
            // Настраиваем обработчики
            setupPanelEventListeners();
            
            // Загружаем данные для панелей
            loadPanelData();
            
            // Загружаем SVG изображения
            loadPanelSVGs();
            
            appState.panelsInitialized = true;
            
        } catch (error) {
            console.error('Ошибка инициализации боковых панелей:', error);
        }
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

    // Инициализация счетчиков панелей
    function initializePanelCounters() {
        const panels = ['calendar', 'tasks', 'notifications', 'messages', 'conversations', 'themes'];
        
        panels.forEach(panelId => {
            // Получаем сохраненное значение или генерируем случайное
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
        // Обновляем счетчик в заголовке
        const counterElement = document.getElementById(`${panelId}Count`);
        if (counterElement) {
            counterElement.textContent = count;
        }
        
        // Обновляем счетчик на метке
        const labelElement = document.querySelector(`.panel-label[data-panel="${panelId}"]`);
        if (labelElement) {
            labelElement.setAttribute('data-count', count);
        }
    }

    // Настройка обработчиков событий для панелей
    function setupPanelEventListeners() {
        // Обработчики для меток панелей
        const panelLabels = document.querySelectorAll('.panel-label');
        panelLabels.forEach(label => {
            label.addEventListener('click', function(e) {
                e.stopPropagation();
                const panelId = this.getAttribute('data-panel');
                togglePanel(panelId);
            });
        });
        
        // Обработчики для кнопок закрытия
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
        
        // Закрытие панелей при клике вне их
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
        
        // Закрываем все другие панели
        const allPanels = document.querySelectorAll('.sidebar-panel.active');
        allPanels.forEach(p => {
            if (p !== panel) {
                p.classList.remove('active');
            }
        });
        
        // Переключаем текущую панель
        panel.classList.toggle('active');
        
        // Обновляем счетчик при открытии
        if (panel.classList.contains('active')) {
            updatePanelCounter(panelId);
        }
    }

    // Обновление счетчика панели
    function updatePanelCounter(panelId) {
        // В реальном приложении здесь был бы запрос к API
        // Для демонстрации обновляем случайным образом
        const randomCount = Math.floor(Math.random() * 10);
        updatePanelDisplay(panelId, randomCount);
        
        // Сохраняем в localStorage
        localStorage.setItem(`panel_${panelId}_count`, randomCount.toString());
    }

    // Загрузка данных для панелей
    function loadPanelData() {
        // В реальном приложении здесь загружались бы данные
        console.log('Загрузка данных для боковых панелей...');
        
        // Имитируем загрузку данных
        setTimeout(() => {
            const mockData = {
                calendar: 7,
                tasks: 4,
                notifications: 1,
                messages: 3,
                conversations: 5,
                themes: 2
            };
            
            Object.entries(mockData).forEach(([panelId, count]) => {
                updatePanelDisplay(panelId, count);
            });
        }, 1000);
    }

    // Настройка выпадающих меню навигации
    function setupDropdownMenu() {
        // Находим все элементы навигации
        const navItems = document.querySelectorAll('.nav-item');
        
        navItems.forEach(navItem => {
            // Находим выпадающее меню
            const dropdown = navItem.querySelector('.nav-dropdown');
            if (!dropdown) return;
            
            // Находим все ссылки в выпадающем меню
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
        
        // Используем нашу систему прав
        if (window.AuthPermissions && window.AuthPermissions.canCreateProjects) {
            if (window.AuthPermissions.canCreateProjects()) {
                // Пользователь может создавать проекты
                window.location.href = '../pages/ProjectMain.html';
            } else {
                // Показываем сообщение о недостаточных правах
                const user = window.AuthPermissions.getCurrentUser();
                const message = user 
                    ? `Для создания проекта ваш статус "${user.status}" недостаточен. Требуется статус "Руководитель проекта" или выше.`
                    : 'Для создания проекта необходимо авторизоваться со статусом "Руководитель проекта" или выше.';
                
                alert(message);
                
                // Можно предложить перейти к профилю или регистрации
                if (confirm('Хотите перейти на страницу профиля?')) {
                    window.location.href = '/pages/profile.html';
                }
            }
        } else {
            // Запасной вариант
            alert('Система проверки прав не загружена. Попробуйте позже.');
        }
    }

    // Показать боковые панели (публичный метод)
    function showSidebarPanels() {
        initSidebarPanels();
    }

    // Настройка обработчиков событий
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
            elements.newCityInput.addEventListener('input', handleCityInput);
            elements.newCityInput.addEventListener('keypress', handleCityInputKeypress);
            elements.newCityInput.addEventListener('focus', showSearchResults);
        }

        // Кнопки в шапке
        const helpButton = document.querySelector('.help-button');
        const enterButton = document.querySelector('.enter-button');
        
        if (helpButton) {
            helpButton.addEventListener('click', handleHelpButton);
        }
        
        if (enterButton && !appState.isAuthenticated) {
            enterButton.addEventListener('click', handleEnterButton);
        }

        // Ссылка "Как это работает"
        if (elements.howItWorksLink) {
            elements.howItWorksLink.addEventListener('click', handleHowItWorksClick);
        }
    }

    // Обработка кнопки входа
    function handleEnterButton() {
        // Сначала проверяем через AuthUpdated
        if (appState.isAuthenticated && appState.currentUser) {
            // Если пользователь авторизован, показываем профиль
            handleProfileClick();
        } else {
            // Проверяем через sessionStorage как запасной вариант
            const currentUser = sessionStorage.getItem('current_user');
            if (currentUser) {
                try {
                    const user = JSON.parse(currentUser);
                    showNotification(`Вы вошли как: ${user.nickname}`, 'info');
                } catch {
                    // Если не авторизован, переходим на страницу входа
                    window.location.href = '../pages/enter-reg.html';
                }
            } else {
                // Если не авторизован, переходим на страницу входа
                const currentPath = window.location.pathname;
                const isPagesFolder = currentPath.includes('/pages/');
                if (isPagesFolder) {
                    window.location.href = 'enter-reg.html';
                } else {
                    window.location.href = 'pages/enter-reg.html';
                }
            }
        }
    }

    // Обработка клика по профилю
    function handleProfileClick() {
        if (appState.currentUser) {
            let statusText = appState.currentUser.statusOfActor;
            if (Array.isArray(statusText)) {
                statusText = statusText.join(', ');
            }
            showNotification(`Вы вошли как: ${appState.currentUser.nickname} (${statusText})`, 'info');
        }
    }

    // Функция для получения заголовков с токеном
    function getAuthHeaders() {
        const token = localStorage.getItem('token');
        return {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
        };
    }

    // Получить города пользователя с сервера
    async function getUserCities() {
        try {
            const response = await fetch(`${config.api.baseURL}${config.api.endpoints.cities}`, {
                headers: getAuthHeaders()
            });
            
            if (!response.ok) throw new Error('Ошибка загрузки городов');
            
            return await response.json();
        } catch (error) {
            console.error('Ошибка получения городов:', error);
            return getSavedCities(); // Возвращаем локальные данные как запасной вариант
        }
    }

    // Добавить город на сервер
    async function addCityToServer(cityData) {
        try {
            const response = await fetch(`${config.api.baseURL}${config.api.endpoints.cities}`, {
                method: 'POST',
                headers: getAuthHeaders(),
                body: JSON.stringify(cityData)
            });
            
            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.message || 'Ошибка добавления города');
            }
            
            return await response.json();
        } catch (error) {
            console.error('Ошибка добавления города:', error);
            throw error;
        }
    }

    // ОБНОВЛЕННАЯ ФУНКЦИЯ: Добавление города с использованием LocacityDatabase
    async function addNewCity(e) {
        e.preventDefault();
        
        if (!elements.newCityInput) return;
        
        const newCity = elements.newCityInput.value.trim();
        
        if (!newCity) {
            showNotification('Введите название населённого пункта', 'warning');
            return;
        }
        
        if (newCity.length < 2) {
            showNotification('Название должно содержать не менее 2 символов', 'warning');
            return;
        }
        
        // Валидация названия
        const validation = validateCityInput(newCity);
        if (!validation.valid) {
            showNotification(validation.message, 'warning');
            return;
        }
        
        try {
            // Проверяем, существует ли уже такой город в сохранённом списке
            const savedCities = getSavedCities();
            
            if (savedCities.some(city => city.toLowerCase() === newCity.toLowerCase())) {
                showNotification(`Населённый пункт "${newCity}" уже есть в списке!`, 'warning');
                return;
            }
            
            // Проверяем через LocacityDatabase, есть ли город в базе данных
            let cityData = null;
            if (appState.databases.locacities) {
                cityData = appState.databases.locacities.findLocacityByName(newCity);
            }
            
            // Если город найден в базе данных
            if (cityData) {
                console.log(`Город "${newCity}" найден в LocacityDatabase:`, cityData);
                
                // Добавляем в сохранённые города
                savedCities.push(newCity);
                localStorage.setItem('citiesList', JSON.stringify(savedCities));
                
                // Обновляем список
                renderCitiesList(savedCities);
                
                // Очищаем поле ввода
                elements.newCityInput.value = '';
                
                // Выбираем город
                selectCity(newCity);
                
                showNotification(`Населённый пункт "${newCity}" добавлен (${cityData.LocacityRegion})`, 'success');
                
            } else {
                // Город не найден в базе данных - предлагаем добавить как пользовательский
                const confirmAdd = confirm(`"${newCity}" не найден в нашей базе данных.\n\nХотите добавить его как пользовательский населённый пункт?\n\nВы сможете указать регион и другие данные позже.`);
                
                if (confirmAdd) {
                    // Добавляем как пользовательский
                    savedCities.push(newCity);
                    localStorage.setItem('citiesList', JSON.stringify(savedCities));
                    
                    // Обновляем список
                    renderCitiesList(savedCities);
                    
                    // Очищаем поле ввода
                    elements.newCityInput.value = '';
                    
                    // Выбираем город
                    selectCity(newCity);
                    
                    showNotification(`Пользовательский населённый пункт "${newCity}" добавлен`, 'info');
                    
                    // Опционально: сохраняем в LocacityDatabase
                    try {
                        if (appState.databases.locacities && appState.databases.locacities.addLocacity) {
                            const userLocacity = {
                                LocacityName: newCity,
                                LocacityType: 'город',
                                LocacityRegion: 'Не указано',
                                LocacityCountry: 'Россия',
                                LocacityDescription: 'Пользовательский населённый пункт',
                                LocacityPopulation: 0
                            };
                            
                            // В реальном приложении здесь был бы вызов addLocacity
                            console.log('Пользовательский населённый пункт для добавления в базу:', userLocacity);
                        }
                    } catch (error) {
                        console.warn('Не удалось добавить в LocacityDatabase:', error);
                    }
                } else {
                    showNotification('Добавление отменено', 'info');
                }
            }
            
        } catch (error) {
            console.error('Ошибка при добавлении населённого пункта:', error);
            showNotification(error.message || 'Произошла ошибка при добавлении населённого пункта', 'error');
        }
    }

    // ОБНОВЛЕННАЯ ФУНКЦИЯ: Инициализация городов с LocacityDatabase
    async function initializeCities() {
        try {
            // Проверяем, доступна ли LocacityDatabase
            if (!appState.databases.locacities) {
                console.warn('LocacityDatabase не доступна, использую локальные данные');
            }
            
            if (appState.isAuthenticated && config.api.baseURL) {
                // Загружаем города с сервера
                const serverCities = await getUserCities();
                
                // Объединяем с локальными данными
                const localCities = getSavedCities();
                const allCities = [...new Set([...serverCities.map(c => c.name), ...localCities])];
                
                if (allCities.length > 0) {
                    renderCitiesList(allCities);
                    
                    // Получаем выбранный город пользователя
                    const selected = localStorage.getItem('selectedCity') || 
                                    (serverCities.length > 0 ? serverCities[0].name : 'Улан-Удэ');
                    
                    if (elements.cityName) {
                        elements.cityName.textContent = selected;
                    }
                }
            } else {
                // Используем только локальные данные
                const savedCities = getSavedCities();
                const savedCity = getSavedCity();
                
                if (elements.cityName) {
                    elements.cityName.textContent = savedCity;
                }
                
                if (elements.cityDropdown) {
                    renderCitiesList(savedCities);
                }
            }
            
            // Логируем информацию о городах
            if (appState.databases.locacities) {
                const locacityCount = appState.databases.locacities.getAllLocacities().length;
                console.log(`🌍 LocacityDatabase: ${locacityCount} населённых пунктов доступно`);
                
                // Проверяем наличие города по умолчанию
                const defaultCity = getSavedCity();
                const cityInfo = appState.databases.locacities.findLocacityByName(defaultCity);
                if (cityInfo) {
                    console.log(`📍 Город по умолчанию: ${defaultCity} (${cityInfo.LocacityRegion})`);
                }
            }
            
        } catch (error) {
            console.error('Ошибка при инициализации городов:', error);
            // Используем локальные данные как запасной вариант
            const savedCities = getSavedCities();
            const savedCity = getSavedCity();
            
            if (elements.cityName) {
                elements.cityName.textContent = savedCity;
            }
            
            if (elements.cityDropdown) {
                renderCitiesList(savedCities);
            }
        }
    }

    // Получение сохранённых городов
    function getSavedCities() {
        try {
            return JSON.parse(localStorage.getItem('citiesList')) || config.defaultCities;
        } catch {
            return config.defaultCities;
        }
    }

    // Получение сохранённого города
    function getSavedCity() {
        return localStorage.getItem('selectedCity') || 'Улан-Удэ';
    }

    // ОБНОВЛЕННАЯ ФУНКЦИЯ: Рендер списка городов с использованием LocacityDatabase
    function renderCitiesList(cities) {
        if (!elements.cityDropdown) return;
        
        const addCityForm = document.querySelector('.add-city');
        
        // Сохраняем текущее значение поля ввода
        const currentInputValue = addCityForm ? addCityForm.querySelector('input').value : '';
        
        // Очищаем только элементы городов, сохраняя форму ввода
        const cityItems = elements.cityDropdown.querySelectorAll('.city-item:not(.no-results)');
        cityItems.forEach(item => item.remove());
        
        const noResults = elements.cityDropdown.querySelector('.no-results');
        if (noResults) noResults.remove();
        
        // Добавляем популярные города из LocacityDatabase
        if (appState.databases.locacities) {
            const popularCities = appState.databases.locacities.getTopCities(15);
            popularCities.forEach(city => {
                if (!cities.includes(city.LocacityName)) {
                    const cityItem = createCityItem(
                        city.LocacityName, 
                        city.LocacityRegion, 
                        city.LocacityPopulation,
                        city.LocacityType
                    );
                    if (addCityForm) {
                        elements.cityDropdown.insertBefore(cityItem, addCityForm);
                    } else {
                        elements.cityDropdown.appendChild(cityItem);
                    }
                }
            });
        }

        // Добавляем сохранённые города пользователя
        cities.forEach(cityName => {
            let cityData = null;
            if (appState.databases.locacities) {
                cityData = appState.databases.locacities.findLocacityByName(cityName);
            }
            
            const cityItem = createCityItem(
                cityName, 
                cityData ? cityData.LocacityRegion : '', 
                cityData ? cityData.LocacityPopulation : null,
                cityData ? cityData.LocacityType : null
            );
            
            if (addCityForm) {
                elements.cityDropdown.insertBefore(cityItem, addCityForm);
            } else {
                elements.cityDropdown.appendChild(cityItem);
            }
        });
        
        // Восстанавливаем значение поля ввода
        if (addCityForm && addCityForm.querySelector('input')) {
            addCityForm.querySelector('input').value = currentInputValue;
        }
        
        // Сохраняем обновлённый список городов
        try {
            localStorage.setItem('citiesList', JSON.stringify(cities));
        } catch (error) {
            console.error('Ошибка при сохранении списка городов:', error);
        }
    }

    // ОБНОВЛЕННАЯ ФУНКЦИЯ: Создание элемента города с данными из LocacityDatabase
    function createCityItem(name, region = '', population = null, type = null) {
        const cityItem = document.createElement('div');
        cityItem.className = 'city-item';
        cityItem.setAttribute('role', 'option');
        cityItem.setAttribute('tabindex', '0');
        cityItem.setAttribute('data-city', name);
        
        // Проверяем, есть ли город в LocacityDatabase
        let cityData = null;
        if (appState.databases.locacities) {
            cityData = appState.databases.locacities.findLocacityByName(name);
        }
        
        // Создаем основной текст
        const nameSpan = document.createElement('span');
        nameSpan.className = 'city-name';
        nameSpan.textContent = name;
        cityItem.appendChild(nameSpan);
        
        // Добавляем информацию о регионе, если есть
        if (cityData && cityData.LocacityRegion) {
            const regionSpan = document.createElement('span');
            regionSpan.className = 'city-region';
            regionSpan.textContent = ` (${cityData.LocacityRegion})`;
            regionSpan.style.fontSize = '0.9em';
            regionSpan.style.color = '#ccc';
            regionSpan.style.marginLeft = '5px';
            cityItem.appendChild(regionSpan);
            
            // Добавляем тип населенного пункта, если это не город
            if (cityData.LocacityType && cityData.LocacityType !== 'город') {
                const typeSpan = document.createElement('span');
                typeSpan.className = 'city-type';
                typeSpan.textContent = ` [${cityData.LocacityType}]`;
                typeSpan.style.fontSize = '0.8em';
                typeSpan.style.color = '#A8E40A';
                typeSpan.style.marginLeft = '3px';
                typeSpan.style.fontStyle = 'italic';
                cityItem.appendChild(typeSpan);
            }
        } else if (region) {
            // Если данных из базы нет, но есть переданный регион
            const regionSpan = document.createElement('span');
            regionSpan.className = 'city-region';
            regionSpan.textContent = ` (${region})`;
            regionSpan.style.fontSize = '0.9em';
            regionSpan.style.color = '#999';
            regionSpan.style.marginLeft = '5px';
            cityItem.appendChild(regionSpan);
        } else {
            // Пользовательский город - добавляем специальную пометку
            const userBadge = document.createElement('span');
            userBadge.className = 'user-city-badge';
            userBadge.textContent = ' (пользовательский)';
            userBadge.style.color = '#A8E40A';
            userBadge.style.fontSize = '0.9em';
            userBadge.style.marginLeft = '5px';
            userBadge.style.fontStyle = 'italic';
            userBadge.style.backgroundColor = 'rgba(168, 228, 10, 0.1)';
            userBadge.style.padding = '2px 5px';
            userBadge.style.borderRadius = '3px';
            cityItem.appendChild(userBadge);
            
            // Добавляем иконку или индикатор
            const userIcon = document.createElement('span');
            userIcon.innerHTML = ' ★';
            userIcon.style.color = '#FFD700';
            userIcon.style.fontSize = '0.9em';
            cityItem.insertBefore(userIcon, userBadge);
        }
        
        // Добавляем обработчики событий
        cityItem.addEventListener('click', () => selectCity(name));
        cityItem.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' || e.key === ' ') {
                selectCity(name);
            }
        });
        
        // Добавляем эффект при наведении
        cityItem.addEventListener('mouseenter', function() {
            this.style.backgroundColor = 'rgba(168, 228, 10, 0.1)';
        });
        
        cityItem.addEventListener('mouseleave', function() {
            this.style.backgroundColor = '';
        });
        
        return cityItem;
    }

    // ОБНОВЛЕННАЯ ФУНКЦИЯ: Обработка ввода в поле поиска
    function handleCityInput(e) {
        const query = e.target.value.trim();
        if (query.length >= 2) {
            showSearchResults(query);
        } else if (query.length === 0) {
            // Если поле очищено, показываем стандартный список
            const savedCities = getSavedCities();
            renderCitiesList(savedCities);
        }
    }

    // ОБНОВЛЕННАЯ ФУНКЦИЯ: Показать результаты поиска с использованием LocacityDatabase
    function showSearchResults(query = '') {
        if (!elements.cityDropdown) return;
        
        // Сохраняем ссылку на поле ввода
        const addCityForm = document.querySelector('.add-city');
        const addCityInput = addCityForm ? addCityForm.querySelector('input') : null;
        
        if (!query || query.trim().length === 0) {
            // Показываем стандартный список при пустом запросе
            const savedCities = getSavedCities();
            renderCitiesList(savedCities);
            return;
        }

        let searchResults = [];
        if (appState.databases.locacities) {
            // Используем новый метод searchLocacities
            searchResults = appState.databases.locacities.searchLocacities(query, 10);
            console.log(`🔍 Поиск "${query}": найдено ${searchResults.length} результатов`);
        } else {
            console.warn('LocacityDatabase не доступна для поиска');
        }
        
        // Сохраняем текущее значение поля ввода
        const currentInputValue = addCityInput ? addCityInput.value : '';
        
        // Очищаем только элементы городов, сохраняя форму ввода
        const cityItems = elements.cityDropdown.querySelectorAll('.city-item:not(.no-results)');
        cityItems.forEach(item => item.remove());
        
        const noResults = elements.cityDropdown.querySelector('.no-results');
        if (noResults) noResults.remove();
        
        if (searchResults.length > 0) {
            searchResults.forEach(locacity => {
                const cityItem = createCityItem(
                    locacity.LocacityName, 
                    locacity.LocacityRegion, 
                    locacity.LocacityPopulation,
                    locacity.LocacityType
                );
                // Вставляем перед формой ввода
                if (addCityForm) {
                    elements.cityDropdown.insertBefore(cityItem, addCityForm);
                } else {
                    elements.cityDropdown.appendChild(cityItem);
                }
            });
            
            // Добавляем информационное сообщение
            const infoElement = document.createElement('div');
            infoElement.className = 'city-item search-info';
            infoElement.textContent = `Найдено: ${searchResults.length} населённых пунктов`;
            infoElement.style.fontSize = '0.8em';
            infoElement.style.color = '#A8E40A';
            infoElement.style.fontStyle = 'italic';
            infoElement.style.padding = '5px 10px';
            infoElement.style.borderTop = '1px solid #333';
            
            if (addCityForm) {
                elements.cityDropdown.insertBefore(infoElement, addCityForm);
            } else {
                elements.cityDropdown.appendChild(infoElement);
            }
            
        } else {
            const noResultsElement = document.createElement('div');
            noResultsElement.className = 'city-item no-results';
            noResultsElement.textContent = 'Населённый пункт не найден';
            noResultsElement.style.color = '#999';
            noResultsElement.style.fontStyle = 'italic';
            
            // Вставляем перед формой ввода
            if (addCityForm) {
                elements.cityDropdown.insertBefore(noResultsElement, addCityForm);
            } else {
                elements.cityDropdown.appendChild(noResultsElement);
            }
            
            // Предложение добавить новый город
            const suggestionElement = document.createElement('div');
            suggestionElement.className = 'city-item suggestion';
            suggestionElement.innerHTML = `Хотите добавить <strong>"${query}"</strong> в список?`;
            suggestionElement.style.color = '#A8E40A';
            suggestionElement.style.fontSize = '0.9em';
            suggestionElement.style.padding = '5px 10px';
            suggestionElement.style.cursor = 'pointer';
            
            suggestionElement.addEventListener('click', function() {
                if (elements.newCityInput) {
                    elements.newCityInput.value = query;
                    // Фокус остается на поле ввода
                    elements.newCityInput.focus();
                }
            });
            
            if (addCityForm) {
                elements.cityDropdown.insertBefore(suggestionElement, addCityForm);
            } else {
                elements.cityDropdown.appendChild(suggestionElement);
            }
        }
        
        // Восстанавливаем значение поля ввода и фокус
        if (addCityInput) {
            addCityInput.value = currentInputValue;
            // Устанавливаем фокус обратно на поле ввода
            setTimeout(() => {
                addCityInput.focus();
                // Устанавливаем курсор в конец текста
                addCityInput.selectionStart = addCityInput.selectionEnd = currentInputValue.length;
            }, 0);
        }
    }

    // ОБНОВЛЕННАЯ ФУНКЦИЯ: Выбор города с использованием LocacityDatabase
    function selectCity(city) {
        if (elements.cityName) {
            elements.cityName.textContent = city;
        }
        
        if (elements.cityDropdown) {
            elements.cityDropdown.classList.remove('show');
        }
        
        if (elements.cityName) {
            elements.cityName.setAttribute('aria-expanded', 'false');
        }
        
        // Очищаем поле поиска при выборе города
        if (elements.newCityInput) {
            elements.newCityInput.value = '';
        }
        
        try {
            localStorage.setItem('selectedCity', city);
            
            // Получаем дополнительную информацию о городе из LocacityDatabase
            let cityInfo = null;
            if (appState.databases.locacities) {
                cityInfo = appState.databases.locacities.findLocacityByName(city);
            }
            
            // Добавляем город в список сохранённых, если его там нет
            const savedCities = getSavedCities();
            if (!savedCities.includes(city)) {
                savedCities.push(city);
                localStorage.setItem('citiesList', JSON.stringify(savedCities));
            }
            
            // Обновляем локальный список для отображения
            showSearchResults('');
            
            // Показываем уведомление с дополнительной информацией
            let notificationText = `Населённый пункт изменён на: ${city}`;
            if (cityInfo && cityInfo.LocacityRegion) {
                notificationText += ` (${cityInfo.LocacityRegion})`;
            }
            if (cityInfo && cityInfo.LocacityType && cityInfo.LocacityType !== 'город') {
                notificationText += ` [${cityInfo.LocacityType}]`;
            }
            
            showNotification(notificationText, 'success');
            
            // Логируем выбор города
            console.log(`📍 Выбран город: ${city}`, cityInfo || '');
            
        } catch (error) {
            console.error('Ошибка при сохранении выбранного города:', error);
            showNotification(`Ошибка при выборе города: ${city}`, 'error');
        }
    }

    // Функция для сохранения и восстановления фокуса
    function preserveFocus(callback) {
        const activeElement = document.activeElement;
        const selectionStart = activeElement.selectionStart;
        const selectionEnd = activeElement.selectionEnd;
        
        callback();
        
        // Восстанавливаем фокус после небольшой задержки
        setTimeout(() => {
            if (activeElement && activeElement.tagName === 'INPUT') {
                activeElement.focus();
                activeElement.selectionStart = selectionStart;
                activeElement.selectionEnd = selectionEnd;
            }
        }, 10);
    }

    // Переключение выпадающего списка городов
    function toggleCityDropdown(e) {
        if (!elements.cityDropdown) return;
        
        e.stopPropagation();
        const isExpanded = elements.cityDropdown.classList.toggle('show');
        if (elements.cityName) {
            elements.cityName.setAttribute('aria-expanded', isExpanded.toString());
        }
        
        // При открытии показываем стандартный список и устанавливаем фокус на поле ввода
        if (isExpanded && elements.newCityInput) {
            elements.newCityInput.value = '';
            const savedCities = getSavedCities();
            renderCitiesList(savedCities);
            
            // Устанавливаем фокус на поле ввода после небольшой задержки
            setTimeout(() => {
                elements.newCityInput.focus();
            }, 10);
        }
    }

    // Закрытие выпадающего списка городов
    function closeCityDropdown() {
        if (elements.cityDropdown) {
            elements.cityDropdown.classList.remove('show');
        }
        
        if (elements.cityName) {
            elements.cityName.setAttribute('aria-expanded', 'false');
        }
    }

    // Обработка кликов в выпадающем списке городов
    function handleCityDropdownClick(e) {
        e.stopPropagation();
    }

    // Функция для проверки валидности города
    function validateCityInput(cityName) {
        if (!cityName || cityName.trim().length === 0) {
            return { valid: false, message: 'Введите название населённого пункта' };
        }
        
        if (cityName.length < 2) {
            return { valid: false, message: 'Название должно содержать не менее 2 символов' };
        }
        
        if (cityName.length > 50) {
            return { valid: false, message: 'Название не должно превышать 50 символов' };
        }
        
        // Проверяем, не является ли ввод числом
        if (!isNaN(cityName)) {
            return { valid: false, message: 'Название населённого пункта не может быть числом' };
        }
        
        // Проверяем наличие только букв, дефисов, пробелов и апострофов
        const validCharsRegex = /^[а-яА-ЯёЁa-zA-Z\s\-\'']+$/;
        if (!validCharsRegex.test(cityName)) {
            return { valid: false, message: 'Название может содержать только буквы, пробелы, дефисы и апострофы' };
        }
        
        return { valid: true, message: '' };
    }

    // Обработка ввода в поле города
    function handleCityInputKeypress(e) {
        if (e.key === 'Enter') {
            e.preventDefault();
            addNewCity(e);
        }
    }

    // Настройка навигации
    function setupNavigation() {
        const navLinks = document.querySelectorAll('.nav-link');
        
        // Получаем текущий URL и нормализуем его
        const currentPath = window.location.pathname;
        const currentPage = currentPath.split('/').pop(); // "Projects.html"
        
        // Убираем активное состояние у всех ссылок
        navLinks.forEach(link => {
            link.classList.remove('active');
        });
        
        // Устанавливаем активное состояние на основе текущей страницы
        navLinks.forEach(link => {
            const linkHref = link.getAttribute('href');
            const linkPage = linkHref.split('/').pop(); // "Projects.html"
            
            // Проверяем соответствие текущей страницы
            if (linkPage === currentPage || 
                (currentPage === '' && linkHref === 'index.html') ||
                (currentPage === 'index.html' && linkHref === 'index.html')) {
                
                link.classList.add('active');
                updateActiveIndicator(link);
            }
        });
        
        // Если ни одна ссылка не активна, активируем по умолчанию
        const hasActive = document.querySelector('.nav-link.active');
        if (!hasActive && currentPage === 'Projects.html') {
            // Находим ссылку на Проекты и делаем её активной
            const projectsLink = document.querySelector('.nav-link[href*="Projects"]');
            if (projectsLink) {
                projectsLink.classList.add('active');
                updateActiveIndicator(projectsLink);
            }
        }
    }

    // Обновление позиции и размера индикатора
    function updateActiveIndicator(activeLink, isHover = false) {
        const activeIndicator = document.getElementById('activeIndicator');
        if (!activeIndicator || !activeLink) return;
        
        const linkRect = activeLink.getBoundingClientRect();
        const navContainer = activeLink.closest('.nav-container');
        const containerRect = navContainer.getBoundingClientRect();
        
        // Рассчитываем позицию относительно контейнера навигации
        const left = linkRect.left - containerRect.left;
        const width = linkRect.width;
        
        // Устанавливаем позицию и размер индикатор

        // Устанавливаем позицию и размер индикатора
        activeIndicator.style.left = left + 'px';
        activeIndicator.style.width = width + 'px';
        
        // Добавляем класс для анимации только при реальном переходе, а не при hover
        if (!isHover) {
            activeIndicator.style.transition = 'all 0.3s ease';
        }
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

    // Обработка кнопки помощи
    function handleHelpButton() {
        showNotification('Функционал поддержки PROSTVOR будет реализован в ближайшее время', 'info');
    }

    // Обработка ссылки "Как это работает"
    function handleHowItWorksClick(e) {
        e.preventDefault();
        window.location.href = 'pages/HowItWorks.html';
    }

    // Показать уведомление
    function showNotification(message, type = 'info') {
        if (!elements.notification) return;
        
        elements.notification.textContent = message;
        elements.notification.className = `notification ${type} show`;
        
        setTimeout(() => {
            if (elements.notification) {
                elements.notification.classList.remove('show');
            }
        }, 3000);
    }

    // Скрыть прелоадер
    function hidePreloader() {
        if (!elements.preloader) return;
        
        setTimeout(() => {
            elements.preloader.classList.add('hidden');
        }, 500);
    }

    // =============== НОВЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С LocacityDatabase ===============

    /**
     * Получить информацию о текущем выбранном городе из LocacityDatabase
     * @returns {Object|null} Информация о городе или null
     */
    function getCurrentCityInfo() {
        if (!appState.databases.locacities) return null;
        
        const currentCity = getSavedCity();
        return appState.databases.locacities.findLocacityByName(currentCity);
    }

    /**
     * Получить города по региону текущего города
     * @returns {Array} Города в том же регионе
     */
    function getCitiesInSameRegion() {
        if (!appState.databases.locacities) return [];
        
        const currentCityInfo = getCurrentCityInfo();
        if (!currentCityInfo || !currentCityInfo.LocacityRegion) return [];
        
        return appState.databases.locacities.getLocacitiesByRegion(currentCityInfo.LocacityRegion);
    }

    /**
     * Получить статистику по городам для отображения
     * @returns {Object} Форматированная статистика
     */
    function getFormattedCityStats() {
        if (!appState.databases.locacities) return { total: 0, message: 'База данных не загружена' };
        
        const stats = appState.databases.locacities.getStatistics();
        return {
            total: stats.total,
            cities: stats.citiesCount,
            towns: stats.townsCount,
            villages: stats.villagesCount,
            population: stats.populationTotal.toLocaleString('ru-RU'),
            message: `В базе: ${stats.total} населённых пунктов (${stats.citiesCount} городов, ${stats.townsCount} посёлков)`
        };
    }

    /**
     * Поиск городов с расширенными параметрами
     * @param {string} query - Поисковый запрос
     * @param {string} region - Регион для фильтрации (опционально)
     * @param {string} type - Тип населённого пункта (опционально)
     * @returns {Array} Результаты поиска
     */
    function searchCitiesAdvanced(query, region = null, type = null) {
        if (!appState.databases.locacities) return [];
        
        let results = appState.databases.locacities.searchLocacities(query, 50);
        
        // Применяем дополнительные фильтры
        if (region) {
            results = results.filter(city => 
                city.LocacityRegion && 
                city.LocacityRegion.toLowerCase().includes(region.toLowerCase())
            );
        }
        
        if (type) {
            results = results.filter(city => city.LocacityType === type);
        }
        
        return results;
    }

    // =============== ПУБЛИЧНЫЕ МЕТОДЫ ===============

    return {
        init: init,
        showNotification: showNotification,
        showSidebarPanels: showSidebarPanels,
        updateActiveIndicator: updateActiveIndicator,
        
        // Методы для работы с базами данных
        getDatabase: function(name) {
            return appState.databases[name] || null;
        },
        isActorExists: function(nickname) {
            if (!appState.databases.actors) return false;
            return !!appState.databases.actors.findActorByNickname(nickname);
        },
        getLocacityInfo: function(locacityName) {
            if (!appState.databases.locacities) return null;
            return appState.databases.locacities.findLocacityByName(locacityName);
        },
        searchFunctions: function(query) {
            if (!appState.databases.functions) return [];
            return appState.databases.functions.searchFunctions(query);
        },
        searchDirections: function(query) {
            if (!appState.databases.directions) return [];
            return appState.databases.directions.searchDirections(query);
        },
        
        // Новые методы для работы с LocacityDatabase
        getCurrentCityInfo: getCurrentCityInfo,
        getCitiesInSameRegion: getCitiesInSameRegion,
        getFormattedCityStats: getFormattedCityStats,
        searchCitiesAdvanced: searchCitiesAdvanced,
        
        // Для обратной совместимости
        searchSettlements: function(query) {
            if (appState.databases.locacities) {
                return appState.databases.locacities.searchLocacities(query);
            }
            return [];
        },
        getAllSettlements: function() {
            if (appState.databases.locacities) {
                return appState.databases.locacities.getAllLocacities();
            }
            return [];
        },
        
        // Геттеры для состояния
        getState: function() {
            return {
                isAuthenticated: appState.isAuthenticated,
                currentUser: appState.currentUser,
                databases: Object.keys(appState.databases).filter(key => appState.databases[key] !== null),
                currentCity: getSavedCity(),
                cityInfo: getCurrentCityInfo()
            };
        },
        
        // Отладочный метод
        debugInfo: function() {
            console.group('📊 AppUpdated Debug Info');
            console.log('Состояние:', this.getState());
            
            if (appState.databases.locacities) {
                console.log('LocacityDatabase:');
                console.log('  - Записей:', appState.databases.locacities.getAllLocacities().length);
                console.log('  - Регионов:', appState.databases.locacities.getAllRegions().length);
                
                const currentCity = getSavedCity();
                const cityInfo = appState.databases.locacities.findLocacityByName(currentCity);
                console.log('  - Текущий город:', currentCity, cityInfo || '(не найден в базе)');
            }
            
            console.groupEnd();
        }
    };
})();

// Инициализация приложения после загрузки DOM
document.addEventListener('DOMContentLoaded', function() {
    AppUpdated.init();
});

// Экспорт для глобального доступа
if (typeof window !== 'undefined') {
    window.AppUpdated = AppUpdated;
}

// Отладочные команды для консоли
console.log('🚀 AppUpdated загружен. Для отладки используйте AppUpdated.debugInfo()');
console.log('📍 Для тестирования LocacityDatabase используйте: LocacityDatabase.searchLocacities("Москва")');

// Обработка ошибок загрузки изображений
window.addEventListener('error', function(e) {
    if (e.target.tagName === 'IMG') {
        console.error('Ошибка загрузки изображения:', e.target.src);
        e.target.style.display = 'none';
    }
}, true);

// Инициализация системы прав при загрузке
document.addEventListener('DOMContentLoaded', function() {
    // Проверяем доступ к текущей странице
    checkPageAccess();
    
    // Настраиваем кнопки в зависимости от прав
    setupPermissionBasedButtons();
});

async function checkPageAccess() {
    const currentPath = window.location.pathname;
    const urlParams = new URLSearchParams(window.location.search);
    const projectId = urlParams.get('project');
    
    // Если это страница конкретного проекта
    if (currentPath.includes('ProjectMain.html') || 
        currentPath.includes('ProjectMedia.html') || 
        currentPath.includes('ProjectKanban.html')) {
        
        if (!projectId) {
            window.location.href = '/pages/Projects.html';
            return;
        }
        
        // Проверяем права доступа к проекту
        try {
            const response = await window.apiService.get('/api/projects/permissions.php', {
                project_id: projectId
            });
            
            if (!response.has_access) {
                window.authPermissions.showPermissionAlert(
                    `У вас нет доступа к этому проекту. ${response.access_reason}`,
                    {
                        requiredStatus: response.required_role ? 
                            `Роль в проекте: ${response.required_role}` : null,
                        currentStatus: response.global_status
                    }
                );
                
                // Перенаправляем через 3 секунды
                setTimeout(() => {
                    window.location.href = '/pages/Projects.html';
                }, 3000);
            }
        } catch (error) {
            console.error('Failed to check project access:', error);
        }
    }
}

function setupPermissionBasedButtons() {
    // Настройка кнопки создания проекта
    const createProjectBtn = document.getElementById('create-project-btn');
    if (createProjectBtn) {
        if (!window.authPermissions.canCreateProject()) {
            createProjectBtn.style.display = 'none';
        } else {
            createProjectBtn.addEventListener('click', createProject);
        }
    }
    
    // Настройка кнопок в проекте
    const projectId = new URLSearchParams(window.location.search).get('project');
    if (projectId) {
        // Кнопка редактирования проекта
        const editProjectBtn = document.getElementById('edit-project-btn');
        if (editProjectBtn) {
            if (!window.authPermissions.canEditProject(projectId)) {
                editProjectBtn.style.display = 'none';
            }
        }
        
        // Кнопка создания задачи
        const createTaskBtn = document.getElementById('create-task-btn');
        if (createTaskBtn) {
            if (!window.authPermissions.canCreateTask(projectId)) {
                createTaskBtn.style.display = 'none';
            }
        }
        
        // Кнопка приглашения в проект
        const inviteBtn = document.getElementById('invite-to-project-btn');
        if (inviteBtn) {
            if (!window.authPermissions.canInviteToProject(projectId)) {
                inviteBtn.style.display = 'none';
            } else {
                inviteBtn.addEventListener('click', showInviteModal);
            }
        }
        
        // Кнопка проверки проекта
        const verifyBtn = document.getElementById('verify-project-btn');
        if (verifyBtn) {
            if (!window.authPermissions.canVerifyProject(projectId)) {
                verifyBtn.style.display = 'none';
            }
        }
        
        // Кнопка приостановки проекта
        const suspendBtn = document.getElementById('suspend-project-btn');
        if (suspendBtn) {
            if (!window.authPermissions.canSuspendProject(projectId)) {
                suspendBtn.style.display = 'none';
            }
        }
    }
}

async function createProject() {
    if (!window.authPermissions.canCreateProject()) {
        window.authPermissions.showPermissionAlert(
            'Только участники ТЦ могут создавать новые проекты',
            { currentStatus: window.authPermissions.currentUser.global_status }
        );
        return;
    }
    
    // Логика создания проекта
    const title = prompt('Введите название проекта:');
    const description = prompt('Введите описание проекта:');
    
    if (title && description) {
        try {
            const response = await window.apiService.post('/api/projects/index.php', {
                title,
                description
            });
            
            if (response.success) {
                alert('Проект успешно создан!');
                // Перенаправляем на страницу проекта
                window.location.href = `/pages/ProjectMain.html?project=${response.project_id}`;
            }
        } catch (error) {
            alert('Ошибка при создании проекта: ' + error.message);
        }
    }
}

function showInviteModal() {
    const projectId = new URLSearchParams(window.location.search).get('project');
    
    if (!window.authPermissions.canInviteToProject(projectId)) {
        window.authPermissions.showPermissionAlert(
            'Только руководитель и администратор проекта могут приглашать участников',
            { currentStatus: window.authPermissions.currentUser.global_status }
        );
        return;
    }
    
    // Логика показа модального окна приглашения
    const modal = document.createElement('div');
    modal.className = 'invite-modal';
    modal.innerHTML = `
        <div class="modal-content">
            <h3>Пригласить в проект</h3>
            <input type="text" id="invite-username" placeholder="Имя пользователя или email">
            <select id="invite-role">
                <option value="member">Участник проекта</option>
                <option value="admin">Администратор проекта</option>
                <option value="curator">Проектный куратор</option>
            </select>
            <div class="modal-buttons">
                <button onclick="sendInvite(${projectId})">Пригласить</button>
                <button onclick="this.parentElement.parentElement.parentElement.remove()">Отмена</button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
}

async function sendInvite(projectId) {
    const usernameInput = document.getElementById('invite-username');
    const roleSelect = document.getElementById('invite-role');
    
    if (!usernameInput.value) {
        alert('Введите имя пользователя или email');
        return;
    }
    
    try {
        // Сначала находим пользователя по username/email
        const findUserResponse = await window.apiService.get('/api/actors/search.php', {
            query: usernameInput.value
        });
        
        if (!findUserResponse.success || findUserResponse.actors.length === 0) {
            alert('Пользователь не найден');
            return;
        }
        
        const targetActor = findUserResponse.actors[0];
        
        // Отправляем приглашение
        const response = await window.apiService.post('/api/projects/permissions.php', {
            project_id: projectId,
            actor_id: targetActor.actor_id,
            role_type: roleSelect.value
        });
        
        if (response.success) {
            alert('Приглашение отправлено!');
            document.querySelector('.invite-modal').remove();
        }
    } catch (error) {
        alert('Ошибка при отправке приглашения: ' + error.message);
    }
}