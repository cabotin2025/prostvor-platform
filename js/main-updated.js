// main-updated.js - Обновленный основной модуль приложения
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
        panelsInitialized: false
    };

    // Инициализация приложения
    function init() {
        try {
            // Проверяем авторизацию
            checkAuthStatus();
            
            // Проверяем, что база данных городов доступна
            if (typeof RussianCitiesDatabase === 'undefined') {
                console.warn('База данных городов не загружена');
            }
            
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

    // Проверка статуса авторизации
    function checkAuthStatus() {
        try {
            const currentUser = AuthUpdated ? AuthUpdated.getCurrentUser() : null;
            
            if (currentUser) {
                appState.isAuthenticated = true;
                appState.currentUser = currentUser;
                console.log('Пользователь авторизован:', currentUser.nickname);
            } else {
                appState.isAuthenticated = false;
                appState.currentUser = null;
            }
        } catch (error) {
            console.error('Ошибка при проверке авторизации:', error);
            appState.isAuthenticated = false;
        }
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
        // Проверяем авторизацию
        if (!appState.isAuthenticated) {
            showNotification('Создавать Проекты могут только авторизованные Участники', 'warning');
            return;
        }
        
        // Пользователь авторизован - переходим на страницу создания проекта
        window.location.href = '../pages/ProjectMain.html';
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
                // Проверяем текущий путь для правильного редиректа
                const currentPath = window.location.pathname;
                const isPagesFolder = currentPath.includes('/pages/');
                // Просто перенаправляем на страницу входа
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
            showNotification(`Вы вошли как: ${appState.currentUser.nickname} (${appState.currentUser.statusOfActor})`, 'info');
        }
    }

    // Конфигурация API
const API_BASE_URL = 'http://localhost:5000/api';

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
        const response = await fetch(`${API_BASE_URL}/cities`, {
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
        const response = await fetch(`${API_BASE_URL}/cities`, {
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

// Обновлённая функция добавления города
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
    
    try {
        // Проверяем авторизацию
        if (!appState.isAuthenticated) {
            // Если не авторизован, сохраняем локально
            const currentCities = getSavedCities();
            
            if (currentCities.some(city => city.toLowerCase() === newCity.toLowerCase())) {
                showNotification(`Населённый пункт "${newCity}" уже есть в списке!`, 'warning');
                return;
            }
            
            currentCities.push(newCity);
            localStorage.setItem('citiesList', JSON.stringify(currentCities));
            renderCitiesList(currentCities);
            elements.newCityInput.value = '';
            selectCity(newCity);
            
            showNotification(`Населённый пункт "${newCity}" добавлен (локально)`, 'info');
            return;
        }
        
        // Если авторизован, сохраняем на сервере
        const cityData = {
            name: newCity,
            isCustom: true
        };
        
        // Проверяем, есть ли город в базе данных
        if (typeof RussianCitiesDatabase !== 'undefined') {
            const cityInDB = RussianCitiesDatabase.findSettlementByName(newCity);
            if (cityInDB) {
                cityData.region = cityInDB.region;
                cityData.population = cityInDB.population;
                cityData.isCustom = false;
            }
        }
        
        const response = await addCityToServer(cityData);
        
        // Обновляем локальный список
        const currentCities = getSavedCities();
        if (!currentCities.includes(newCity)) {
            currentCities.push(newCity);
            localStorage.setItem('citiesList', JSON.stringify(currentCities));
        }
        
        renderCitiesList(currentCities);
        elements.newCityInput.value = '';
        selectCity(newCity);
        
        showNotification(`Населённый пункт "${newCity}" добавлен`, 'success');
        
    } catch (error) {
        console.error('Ошибка при добавлении населённого пункта:', error);
        showNotification(error.message || 'Произошла ошибка при добавлении населённого пункта', 'error');
    }
}

// Обновлённая функция инициализации городов
async function initializeCities() {
    try {
        if (appState.isAuthenticated) {
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

    // Инициализация функционала городов
    function initializeCities() {
        try {
            const savedCities = getSavedCities();
            const savedCity = getSavedCity();
            
            if (elements.cityName) {
                elements.cityName.textContent = savedCity;
            }
            
            if (elements.cityDropdown) {
                renderCitiesList(savedCities);
            }
            
        } catch (error) {
            console.error('Ошибка при инициализации городов:', error);
            if (elements.cityDropdown) {
                renderCitiesList(config.defaultCities);
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

    // Рендер списка городов
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
        
        // Добавляем популярные города из базы данных
        if (typeof RussianCitiesDatabase !== 'undefined') {
            const popularCities = RussianCitiesDatabase.getTopCities(15);
            popularCities.forEach(city => {
                if (!cities.includes(city.name)) {
                    const cityItem = createCityItem(city.name, city.region, city.population);
                    if (addCityForm) {
                        elements.cityDropdown.insertBefore(cityItem, addCityForm);
                    } else {
                        elements.cityDropdown.appendChild(cityItem);
                    }
                }
            });
        }

        // Добавляем сохранённые города пользователя (и из базы данных, и пользовательские)
        cities.forEach(city => {
            let cityData = null;
            if (typeof RussianCitiesDatabase !== 'undefined') {
                cityData = RussianCitiesDatabase.findSettlementByName(city);
            }
            const cityItem = createCityItem(city, cityData ? cityData.region : '', cityData ? cityData.population : null);
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

    // Создание элемента города
    function createCityItem(name, region = '', population = null) {
        const cityItem = document.createElement('div');
        cityItem.className = 'city-item';
        
        let displayText = name;
        
        // Проверяем, есть ли город в базе данных
        let cityData = null;
        if (typeof RussianCitiesDatabase !== 'undefined') {
            cityData = RussianCitiesDatabase.findSettlementByName(name);
        }
        
        if (cityData) {
            // Город из базы данных - показываем только регион (без населения)
            if (cityData.region) {
                const regionSpan = document.createElement('span');
                regionSpan.className = 'city-region';
                regionSpan.textContent = ` (${cityData.region})`;
                regionSpan.style.fontSize = '0.9em';
                regionSpan.style.color = '#ccc';
                regionSpan.style.marginLeft = '5px';
                
                cityItem.textContent = displayText;
                cityItem.appendChild(regionSpan);
            } else {
                cityItem.textContent = displayText;
            }
        } else {
            // Пользовательский город - добавляем специальную пометку
            const userBadge = document.createElement('span');
            userBadge.className = 'user-city-badge';
            userBadge.textContent = ' (пользовательский)';
            userBadge.style.color = '#A8E40A';
            userBadge.style.fontSize = '0.9em';
            userBadge.style.marginLeft = '5px';
            userBadge.style.fontStyle = 'italic';
            
            cityItem.textContent = displayText;
            cityItem.appendChild(userBadge);
        }
        
        cityItem.setAttribute('role', 'option');
        cityItem.setAttribute('tabindex', '0');
        cityItem.setAttribute('data-city', name);
        
        cityItem.addEventListener('click', () => selectCity(name));
        cityItem.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' || e.key === ' ') {
                selectCity(name);
            }
        });
        
        return cityItem;
    }

    // Обработка ввода в поле поиска
    function handleCityInput(e) {
        const query = e.target.value.trim();
        if (query.length >= 2) {
            showSearchResults(query);
        }
    }

    // Показать результаты поиска
    function showSearchResults(query = '') {
        if (!elements.cityDropdown) return;
        
        // Сохраняем ссылку на поле ввода
        const addCityForm = document.querySelector('.add-city');
        const addCityInput = addCityForm ? addCityForm.querySelector('input') : null;
        
        if (!query) {
            // Показываем стандартный список при пустом запросе
            const savedCities = getSavedCities();
            renderCitiesList(savedCities);
            return;
        }

        let searchResults = [];
        if (typeof RussianCitiesDatabase !== 'undefined') {
            searchResults = RussianCitiesDatabase.searchSettlements(query, 10);
        }
        
        // Сохраняем текущее значение поля ввода
        const currentInputValue = addCityInput ? addCityInput.value : '';
        
        // Очищаем только элементы городов, сохраняя форму ввода
        const cityItems = elements.cityDropdown.querySelectorAll('.city-item:not(.no-results)');
        cityItems.forEach(item => item.remove());
        
        const noResults = elements.cityDropdown.querySelector('.no-results');
        if (noResults) noResults.remove();
        
        if (searchResults.length > 0) {
            searchResults.forEach(settlement => {
                const cityItem = createCityItem(
                    settlement.name, 
                    settlement.region, 
                    settlement.population
                );
                // Вставляем перед формой ввода
                if (addCityForm) {
                    elements.cityDropdown.insertBefore(cityItem, addCityForm);
                } else {
                    elements.cityDropdown.appendChild(cityItem);
                }
            });
        } else {
            const noResultsElement = document.createElement('div');
            noResultsElement.className = 'city-item no-results';
            noResultsElement.textContent = 'Населённый пункт не найден';
            // Вставляем перед формой ввода
            if (addCityForm) {
                elements.cityDropdown.insertBefore(noResultsElement, addCityForm);
            } else {
                elements.cityDropdown.appendChild(noResultsElement);
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

    // Выбор города
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
            
            // Добавляем город в список сохранённых, если его там нет
            const savedCities = getSavedCities();
            if (!savedCities.includes(city)) {
                savedCities.push(city);
                localStorage.setItem('citiesList', JSON.stringify(savedCities));
            }
            
            showNotification(`Населённый пункт изменён на: ${city}`, 'success');
        } catch (error) {
            console.error('Ошибка при сохранении выбранного города:', error);
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
        if (!cityName || cityName.length < 2) {
            return { valid: false, message: 'Название должно содержать не менее 2 символов' };
        }
        
        // Проверяем, не является ли ввод числом
        if (!isNaN(cityName)) {
            return { valid: false, message: 'Название населённого пункта не может быть числом' };
        }
        
        // Проверяем наличие только букв, дефисов и пробелов
        const validCharsRegex = /^[а-яА-ЯёЁ\s\-]+$/;
        if (!validCharsRegex.test(cityName)) {
            return { valid: false, message: 'Название может содержать только буквы, пробелы и дефисы' };
        }
        
        return { valid: true, message: '' };
    }

    // Добавление нового города
    function addNewCity(e) {
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
        
        try {
            const currentCities = getSavedCities();
            
            // Проверяем, есть ли город уже в списке
            if (currentCities.some(city => city.toLowerCase() === newCity.toLowerCase())) {
                showNotification(`Населённый пункт "${newCity}" уже есть в списке!`, 'warning');
                return;
            }
            
            // ПРОВЕРЯЕМ, ЕСТЬ ЛИ ГОРОД В БАЗЕ ДАННЫХ
            let cityData = null;
            if (typeof RussianCitiesDatabase !== 'undefined') {
                cityData = RussianCitiesDatabase.findSettlementByName(newCity);
            }
            
            // Если город не найден в базе данных, СПРАШИВАЕМ У ПОЛЬЗОВАТЕЛЯ
            if (!cityData) {
                // Показываем подтверждение о добавлении пользовательского города
                const confirmAdd = confirm(`Населённый пункт "${newCity}" не найден в нашей базе данных. Хотите добавить его вручную?`);
                
                if (!confirmAdd) {
                    return; // Пользователь отказался добавлять
                }
                
                // Добавляем город как пользовательский (без данных о регионе и населении)
                preserveFocus(() => {
                    // Добавляем новый город в массив
                    currentCities.push(newCity);
                    
                    // Обновляем список
                    renderCitiesList(currentCities);
                    
                    // Очищаем поле ввода
                    elements.newCityInput.value = '';
                    
                    // Выбираем город
                    selectCity(newCity);
                });
                
                showNotification(`Населённый пункт "${newCity}" добавлен как пользовательский`, 'info');
                
            } else {
                // Город найден в базе данных, добавляем с полной информацией
                preserveFocus(() => {
                    // Добавляем новый город в массив
                    currentCities.push(newCity);
                    
                    // Обновляем список
                    renderCitiesList(currentCities);
                    
                    // Очищаем поле ввода
                    elements.newCityInput.value = '';
                    
                    // Выбираем город
                    selectCity(newCity);
                });
                
                showNotification(`Населённый пункт "${newCity}" успешно добавлен`, 'success');
            }
            
        } catch (error) {
            console.error('Ошибка при добавлении населённого пункта:', error);
            showNotification('Произошла ошибка при добавлении населённого пункта', 'error');
        }
    }

    // Функция для показа модального окна выбора города
    function showCitySelectionModal(cities, userInput) {
        // Создаем модальное окно
        const modal = document.createElement('div');
        modal.className = 'city-selection-modal';
        modal.innerHTML = `
            <div class="modal-content">
                <h3>Выберите населённый пункт</h3>
                <p>По запросу "<strong>${userInput}</strong>" найдено несколько вариантов:</p>
                <div class="city-options">
                    ${cities.map(city => `
                        <div class="city-option" data-city="${city.name}">
                            <strong>${city.name}</strong>
                            <span class="city-region">${city.region}</span>
                        </div>
                    `).join('')}
                </div>
                <div class="modal-buttons">
                    <button class="cancel-btn">Отмена</button>
                </div>
            </div>
        `;
        
        // Добавляем стили (убираем стили для населения)
        const style = document.createElement('style');
        style.textContent = `
            .city-selection-modal {
                position: fixed;
                top: 0;
                left: 0;
                right: 0;
                bottom: 0;
                background: rgba(0, 0, 0, 0.7);
                display: flex;
                justify-content: center;
                align-items: center;
                z-index: 10000;
            }
            .modal-content {
                background: #001C33;
                border: 1px solid #A8E40A;
                border-radius: 10px;
                padding: 20px;
                max-width: 500px;
                width: 90%;
                max-height: 80vh;
                overflow-y: auto;
            }
            .city-options {
                margin: 15px 0;
            }
            .city-option {
                padding: 10px;
                border: 1px solid #444;
                border-radius: 5px;
                margin: 5px 0;
                cursor: pointer;
                display: flex;
                justify-content: space-between;
                align-items: center;
            }
            .city-option:hover {
                background: rgba(168, 228, 10, 0.1);
                border-color: #A8E40A;
            }
            .city-region {
                color: #ccc;
                font-size: 0.9em;
            }
            .modal-buttons {
                text-align: right;
                margin-top: 20px;
            }
            .cancel-btn {
                background: #666;
                color: white;
                border: none;
                padding: 8px 16px;
                border-radius: 4px;
                cursor: pointer;
            }
        `;
        document.head.appendChild(style);
        document.body.appendChild(modal);
        
        // Обработчики событий
        modal.querySelectorAll('.city-option').forEach(option => {
            option.addEventListener('click', () => {
                const cityName = option.dataset.city;
                addCityToList(cityName);
                document.body.removeChild(modal);
                document.head.removeChild(style);
            });
        });
        
        modal.querySelector('.cancel-btn').addEventListener('click', () => {
            document.body.removeChild(modal);
            document.head.removeChild(style);
        });
    }

    // Функция для добавления города в список
    function addCityToList(cityName) {
        const currentCities = getSavedCities();
        
        if (currentCities.includes(cityName)) {
            showNotification(`Населённый пункт "${cityName}" уже есть в списке!`, 'warning');
            return;
        }
        
        preserveFocus(() => {
            // Добавляем новый город в массив
            currentCities.push(cityName);
            
            // Обновляем список
            renderCitiesList(currentCities);
            
            // Очищаем поле ввода
            if (elements.newCityInput) {
                elements.newCityInput.value = '';
            }
            
            // Выбираем город
            selectCity(cityName);
        });
        
        showNotification(`Населённый пункт "${cityName}" успешно добавлен`, 'success');
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

    // Публичные методы
    return {
        init: init,
        showNotification: showNotification,
        showSidebarPanels: showSidebarPanels,
        updateActiveIndicator: updateActiveIndicator,
        // Экспортируем функции для внешнего использования
        searchSettlements: RussianCitiesDatabase ? RussianCitiesDatabase.searchSettlements : function() { return []; },
        getAllSettlements: RussianCitiesDatabase ? RussianCitiesDatabase.getAllSettlements : function() { return []; }
    };
})();

// Инициализация приложения после загрузки DOM
document.addEventListener('DOMContentLoaded', AppUpdated.init);

// Обработка ошибок загрузки изображений
window.addEventListener('error', function(e) {
    if (e.target.tagName === 'IMG') {
        console.error('Ошибка загрузки изображения:', e.target.src);
        e.target.style.display = 'none';
    }
}, true);