// communications-icons.js - упрощенная версия для нового расположения
const CommunicationsManager = (function() {
    // Тексты для разных страниц
    const pageTexts = {
        projects: {
            favorite: 'добавить Проект в избранное',
            note: 'добавить заметку о Проекте',
            message: 'отправить сообщение руководителю Проекта',
            smile: 'положительная оценка Проекта'
        },
        ideas: {
            favorite: 'добавить Идею в избранное',
            note: 'добавить заметку об Идее',
            message: 'отправить сообщение автору Идеи',
            smile: 'положительная оценка Идеи'
        },
        actors: {
            favorite: 'добавить Участника в избранное',
            note: 'добавить заметку об Участнике',
            message: 'отправить сообщение Участнику',
            smile: 'положительная оценка Участника'
        },
        resources: {
            favorite: 'добавить Ресурс в избранное',
            note: 'добавить заметку о Ресурсе',
            message: 'отправить сообщение обладателю Ресурса',
            smile: 'положительная оценка Ресурса'
        },
        topics: {
            favorite: 'добавить Тему в избранное',
            note: 'добавить заметку о Теме',
            message: 'отправить сообщение инициатору Темы',
            smile: 'положительная оценка Темы'
        },
        services: {
            favorite: 'добавить Услугу в избранное',
            note: 'добавить заметку об Услуге',
            message: 'отправить сообщение владельцу Услуги',
            smile: 'положительная оценка Услуги'
        },
        events: {
            favorite: 'добавить Событие в избранное',
            note: 'добавить заметку о Событии',
            message: 'отправить сообщение руководителю События',
            smile: 'положительная оценка События'
        }
    };

    // Страницы, на которых блок активен
    const activePages = ['projects', 'ideas', 'actors', 'resources', 'topics', 'services', 'events'];

    let currentPage = 'index';
    let currentUser = null;
    let selectedItem = null;

    // Инициализация
    function init() {
        console.log('🚀 CommunicationsManager: инициализация нового расположения');
        
        detectCurrentPage();
        loadCurrentUser();
        
        if (currentUser) {
            createCommunicationBlocks();
            updatePageTexts();
            updateCounters();
            setupEventListeners();
            
            // Добавляем класс активности если страница активная
            if (activePages.includes(currentPage)) {
                document.body.classList.add('has-content');
            }
        } else {
            // Пользователь не авторизован - скрываем блоки
            hideCommunicationBlocks();
        }
    }

    // Определение текущей страницы
    function detectCurrentPage() {
        const path = window.location.pathname.toLowerCase();
        
        if (path.includes('projects')) {
            currentPage = 'projects';
        } else if (path.includes('ideas')) {
            currentPage = 'ideas';
        } else if (path.includes('actors')) {
            currentPage = 'actors';
        } else if (path.includes('resources')) {
            currentPage = 'resources';
        } else if (path.includes('topics')) {
            currentPage = 'topics';
        } else if (path.includes('services')) {
            currentPage = 'services';
        } else if (path.includes('events')) {
            currentPage = 'events';
        } else {
            currentPage = 'index';
        }
        
        console.log('📄 Текущая страница:', currentPage);
    }

    // Загрузка пользователя
    function loadCurrentUser() {
        try {
            const userData = localStorage.getItem('user_data');
            if (userData) {
                currentUser = JSON.parse(userData);
                console.log('👤 Пользователь загружен:', currentUser.nickname);
            }
        } catch (error) {
            console.error('Ошибка загрузки пользователя:', error);
        }
    }

    // Создание блоков коммуникаций
    function createCommunicationBlocks() {
    // Блоки уже существуют в HTML, нам нужно только:
    // 1. Показать их если пользователь авторизован
    // 2. Скрыть если нет
    
    const headerComms = document.querySelector('.header-communications');
    if (headerComms) {
        if (currentUser) {
            headerComms.style.display = 'flex';
        } else {
            headerComms.style.display = 'none';
        }
    }
    }

    function hideCommunicationBlocks() {
    const headerComms = document.querySelector('.header-communications');
    if (headerComms) {
        headerComms.style.display = 'none';
    }
    }

    // Обновление текстов для текущей страницы
    function updatePageTexts() {
        const texts = pageTexts[currentPage] || pageTexts.projects; // fallback
        
        document.querySelectorAll('.comm-icon-button').forEach(button => {
            const type = button.dataset.type;
            const textElement = button.querySelector('.comm-icon-text');
            
            if (textElement && texts[type]) {
                textElement.textContent = texts[type];
            }
        });
    }

    // Обновление счетчиков
    async function updateCounters() {
        if (!currentUser) return;
        
        try {
            // Здесь будут запросы к API для получения счетчиков
            // Временно используем localStorage
            const userCounters = JSON.parse(localStorage.getItem(`user_counters_${currentUser.actor_id}`) || '{}');
            
            // Обновляем правую часть
            document.querySelectorAll('.comm-right-icon').forEach(icon => {
                const type = icon.dataset.type;
                const counter = icon.querySelector('.comm-counter');
                if (counter) {
                    const count = userCounters[type] || 0;
                    counter.textContent = count > 0 ? count : '0';
                }
            });
            
        } catch (error) {
            console.error('Ошибка обновления счетчиков:', error);
        }
    }

    // Настройка обработчиков событий
    function setupEventListeners() {
        // Левая часть - только на активных страницах
        if (activePages.includes(currentPage)) {
            document.querySelectorAll('.comm-icon-button').forEach(button => {
                button.addEventListener('click', handleLeftIconClick);
            });
        }
        
        // Правая часть
        document.querySelectorAll('.comm-right-icon').forEach(icon => {
            icon.addEventListener('click', handleRightIconClick);
        });
        
        // Отслеживаем выбор элементов на странице
        document.addEventListener('click', handleItemSelection);
    }

    // Обработка клика по иконке левой части
    async function handleLeftIconClick(event) {
        const button = event.currentTarget;
        const type = button.dataset.type;
        
        if (!selectedItem) {
            showNotification('Выберите элемент из списка', 'warning');
            return;
        }
        
        console.log('🎯 Клик по иконке:', type, 'для элемента:', selectedItem);
        
        switch(type) {
            case 'favorite':
                await toggleFavorite();
                break;
            case 'note':
                await toggleNote();
                break;
            case 'message':
                await toggleMessage();
                break;
            case 'smile':
                await toggleRating();
                break;
        }
    }

    // Обработка клика по иконке правой части
    async function handleRightIconClick(event) {
        const icon = event.currentTarget;
        const type = icon.dataset.type;
        
        console.log('📊 Клик по правой иконке:', type);
        
        switch(type) {
            case 'favorite':
                await showFavorites();
                break;
            case 'note':
                await showNotes();
                break;
            case 'bookmark':
                await showBookmarks();
                break;
        }
    }

    // Обработка выбора элемента на странице
    function handleItemSelection(event) {
        // Эта логика зависит от структуры конкретной страницы
        // Нужно будет адаптировать для каждой страницы отдельно
        console.log('🔍 Обработка выбора элемента');
    }

    // Скрытие блоков для неавторизованных
    function hideCommunicationBlocks() {
        const leftBlock = document.getElementById('communicationLeftBlock');
        const rightBlock = document.getElementById('communicationRightBlock');
        
        if (leftBlock) leftBlock.style.display = 'none';
        if (rightBlock) rightBlock.style.display = 'none';
    }

    // Вспомогательные функции
    function showNotification(message, type = 'info') {
        if (typeof AppUpdated !== 'undefined' && AppUpdated.showNotification) {
            AppUpdated.showNotification(message, type);
        } else {
            alert(`${type}: ${message}`);
        }
    }

    // API функции (заглушки - нужно реализовать)
    async function toggleFavorite() {
        console.log('⭐ Добавление в избранное');
        // Реализация через API
    }
    
    async function toggleNote() {
        console.log('📝 Работа с заметками');
        // Реализация через API
    }
    
    async function toggleMessage() {
        console.log('💬 Отправка сообщения');
        // Реализация через API
    }
    
    async function toggleRating() {
        console.log('😊 Постановка оценки');
        // Реализация через API
    }
    
    async function showFavorites() {
        console.log('📋 Показ избранного');
        // Реализация через API
    }
    
    async function showNotes() {
        console.log('📒 Показ заметок');
        // Реализация через API
    }
    
    async function showBookmarks() {
        console.log('🔖 Показ закладок');
        // Реализация через API
    }

    // Публичные методы
    return {
        init: init,
        setSelectedItem: function(itemId, itemName) {
            selectedItem = { id: itemId, name: itemName };
            console.log('🎯 Выбран элемент:', selectedItem);
        },
        refreshCounters: updateCounters
    };
})();

// Инициализация
document.addEventListener('DOMContentLoaded', function() {
    setTimeout(() => {
        CommunicationsManager.init();
    }, 1000);
});