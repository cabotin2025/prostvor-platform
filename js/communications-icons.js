// communications-icons.js - полная версия с интеграцией API

console.log('🔐 Проверка авторизации...');
console.log('Токен в localStorage:', localStorage.getItem('user_token'));
console.log('Данные пользователя:', localStorage.getItem('user_data'));

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

    // Соответствие страниц и entity_type для API
    const pageToEntityType = {
        'projects': 'projects',
        'ideas': 'ideas',
        'actors': 'actors',
        'resources': 'finresources', // Уточните при необходимости: finresources или matresources
        'topics': 'themes',
        'services': 'services',
        'events': 'events'
    };

    // Страницы, на которых блок активен
    const activePages = ['projects', 'ideas', 'actors', 'resources', 'topics', 'services', 'events'];

    let currentPage = 'index';
    let currentUser = null;
    let selectedItem = null;
    let currentStatus = {
        isFavorite: false,
        hasRating: false,
        hasNote: false,
        hasMessage: false
    };

    // Инициализация
    function init() {
        console.log('🚀 CommunicationsManager: инициализация');
        
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
                console.log('✅ Блок коммуникаций активирован для страницы:', currentPage);
            }
        } else {
            // Пользователь не авторизован - скрываем блоки
            hideCommunicationBlocks();
            console.log('⚠️ Пользователь не авторизован, блок скрыт');
        }
    }

    // Определение текущей страницы
    function detectCurrentPage() {
        const path = window.location.pathname.toLowerCase();
        const page = path.split('/').pop() || 'index.html';
        
        if (page.includes('projects') || page === 'projects.html') {
            currentPage = 'projects';
        } else if (page.includes('ideas') || page === 'ideas.html') {
            currentPage = 'ideas';
        } else if (page.includes('actors') || page === 'actors.html') {
            currentPage = 'actors';
        } else if (page.includes('resources') || page === 'resources.html') {
            currentPage = 'resources';
        } else if (page.includes('topics') || page === 'topics.html') {
            currentPage = 'topics';
        } else if (page.includes('services') || page === 'services.html') {
            currentPage = 'services';
        } else if (page.includes('events') || page === 'events.html') {
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
                console.log('👤 Пользователь загружен:', currentUser.nickname || currentUser.actor_id);
            }
        } catch (error) {
            console.error('Ошибка загрузки пользователя:', error);
        }
    }

    // Создание/отображение блоков коммуникаций
    function createCommunicationBlocks() {
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
        const texts = pageTexts[currentPage] || pageTexts.projects;
        
        document.querySelectorAll('.comm-icon-button').forEach(button => {
            const type = button.dataset.type;
            const textElement = button.querySelector('.comm-icon-text');
            
            if (textElement && texts[type]) {
                textElement.textContent = texts[type];
            }
        });
    }

    // Получение entity_type для API
    function getApiEntityType() {
        return pageToEntityType[currentPage] || currentPage;
    }

    // Проверка текущего статуса выбранного элемента
    async function checkCurrentStatus() {
    if (!currentUser || !selectedItem) return;
    
    try {
        // Проверяем избранное
        const favResponse = await fetch(
            `/api/favorites/check.php?entity_type=${getApiEntityType()}&entity_id=${selectedItem.id}`,
            {
                headers: { 'Authorization': `Bearer ${currentUser.token}` }
            }
        );
        
        if (favResponse.ok) {
            const favData = await favResponse.json();
            currentStatus.isFavorite = favData.success && favData.is_favorite;
            updateIconState('favorite', currentStatus.isFavorite);
        }
        
        // TODO: Добавить проверку оценки когда будет endpoint
        
    } catch (error) {
        console.error('Ошибка проверки статуса:', error);
    }
    }

    // Обновление счетчиков в правой части
    async function updateCounters() {
        if (!currentUser) return;
    
        try {
        // Счетчик избранного
        const favResponse = await fetch('/api/favorites/count.php', {
            headers: { 'Authorization': `Bearer ${currentUser.token}` }
        });
        
        if (favResponse.ok) {
            const favData = await favResponse.json();
            if (favData.success) {
                const favCounter = document.querySelector('.comm-right-icon[data-type="favorite"] .comm-counter');
                if (favCounter) {
                    favCounter.textContent = favData.count;
                    favCounter.style.display = 'block';
                }
            }
        }
        
        // Счетчик оценок (пока ставим 0)
        const ratingCounter = document.querySelector('.comm-right-icon[data-type="note"] .comm-counter');
        if (ratingCounter) {
            ratingCounter.textContent = '0';
        }
        
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
        
        // Отслеживаем изменение авторизации
        window.addEventListener('storage', function(e) {
            if (e.key === 'user_data') {
                loadCurrentUser();
                if (currentUser) {
                    createCommunicationBlocks();
                    updateCounters();
                } else {
                    hideCommunicationBlocks();
                }
            }
        });
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

    // ==================== API ФУНКЦИИ ====================

    // Избранное
    async function toggleFavorite() {
    if (!selectedItem || !currentUser) {
        showNotification('Выберите элемент из списка', 'warning');
        return;
    }
    
    try {
        const response = await fetch('/api/favorites/toggle.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${currentUser.token}`
            },
            body: JSON.stringify({
                entity_type: getApiEntityType(),
                entity_id: selectedItem.id
            })
        });
        
        const result = await response.json();
        
        if (result.success) {
            showNotification(result.message, 'success');
            currentStatus.isFavorite = result.is_favorite;
            
            // Обновляем иконку
            updateIconState('favorite', result.is_favorite);
            
            // Обновляем счетчик
            await updateCounters();
        } else {
            showNotification(result.message || 'Ошибка операции', 'error');
        }
    } catch (error) {
        console.error('Ошибка:', error);
        showNotification('Ошибка соединения с сервером', 'error');
    }
    }

    // Оценка (рейтинг)
    async function toggleRating() {
    if (!selectedItem || !currentUser) {
        showNotification('Выберите элемент из списка', 'warning');
        return;
    }
    
    try {
        const response = await fetch('/api/ratings/toggle.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${currentUser.token}`
            },
            body: JSON.stringify({
                entity_type: getApiEntityType(),
                entity_id: selectedItem.id,
                rating_type: 'положительно'
            })
        });
        
        const result = await response.json();
        
        if (result.success) {
            showNotification(result.message, 'success');
            currentStatus.hasRating = result.has_rating;
            
            // Обновляем иконку
            updateIconState('smile', result.has_rating);
        } else {
            showNotification(result.message || 'Ошибка операции', 'error');
        }
    } catch (error) {
        console.error('Ошибка:', error);
        showNotification('Ошибка соединения с сервером', 'error');
    }
    }

    
    // Вспомогательная функция для обновления состояния иконок
    function updateIconState(type, isActive) {
        const icon = document.querySelector(`.comm-icon-button[data-type="${type}"]`);
        if (icon) {
            if (isActive) {
                icon.classList.add('active');
                icon.querySelector('img').style.filter = 'brightness(1) sepia(1) saturate(5) hue-rotate(70deg)';
            } else {
                icon.classList.remove('active');
                icon.querySelector('img').style.filter = 'brightness(1)';
            }
        }
    }

    // Заметка
    async function toggleNote() {
        if (!selectedItem || !currentUser) {
            showNotification('Выберите элемент из списка', 'warning');
            return;
        }
        
        try {
            // Сначала проверяем, есть ли существующая заметка
            const checkResponse = await fetch(`/api/notes/check.php?entity_type=${getApiEntityType()}&entity_id=${selectedItem.id}`, {
                headers: {
                    'Authorization': `Bearer ${currentUser.token}`
                }
            });
            
            if (checkResponse.ok) {
                const checkData = await checkResponse.json();
                
                if (checkData.success && checkData.has_note) {
                    // Показываем существующую заметку
                    showNoteModal(checkData.note, true);
                } else {
                    // Создаем новую заметку
                    showNoteModal('', false);
                }
            } else {
                showNoteModal('', false);
            }
        } catch (error) {
            console.error('Ошибка:', error);
            showNoteModal('', false);
        }
    }

    // Сообщение
    async function toggleMessage() {
        if (!selectedItem || !currentUser) {
            showNotification('Выберите элемент из списка', 'warning');
            return;
        }
        
        try {
            // Получаем ID получателя в зависимости от страницы
            const recipientId = await getRecipientId();
            
            if (!recipipientId) {
                showNotification('Не удалось определить получателя', 'warning');
                return;
            }
            
            // Проверяем существующее сообщение
            const checkResponse = await fetch(`/api/messages/check.php?recipient_id=${recipientId}&entity_type=${getApiEntityType()}&entity_id=${selectedItem.id}`, {
                headers: {
                    'Authorization': `Bearer ${currentUser.token}`
                }
            });
            
            if (checkResponse.ok) {
                const checkData = await checkResponse.json();
                
                if (checkData.success && checkData.has_message) {
                    // Показываем существующее сообщение
                    showMessageModal(checkData.message, recipientId, true);
                } else {
                    // Создаем новое сообщение
                    showMessageModal('', recipientId, false);
                }
            } else {
                showMessageModal('', recipientId, false);
            }
        } catch (error) {
            console.error('Ошибка:', error);
            showNotification('Ошибка определения получателя', 'error');
        }
    }

    // ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

    // Определение получателя сообщения
    async function getRecipientId() {
        if (!selectedItem) return null;
        
        // Для проектов: сначала director_id, потом author_id
        if (currentPage === 'projects') {
            try {
                const response = await fetch(`/api/projects/${selectedItem.id}.php`);
                if (response.ok) {
                    const project = await response.json();
                    return project.director_id || project.author_id;
                }
            } catch (error) {
                console.error('Ошибка получения данных проекта:', error);
            }
        }
        
        // Для других типов сущностей - получаем author_id/created_by из данных элемента
        // Временное решение - используем данные из selectedItem
        return selectedItem.author_id || selectedItem.created_by || selectedItem.owner_id;
    }

    // Показ модального окна для заметки
    function showNoteModal(existingNote = '', isEdit = false) {
        const modalId = 'note-modal';
        let modal = document.getElementById(modalId);
        
        if (!modal) {
            modal = document.createElement('div');
            modal.id = modalId;
            modal.className = 'communications-modal';
            modal.innerHTML = `
                <div class="modal-content">
                    <div class="modal-header">
                        <h3>${isEdit ? 'Редактировать заметку' : 'Добавить заметку'}</h3>
                        <button class="modal-close">&times;</button>
                    </div>
                    <div class="modal-body">
                        <textarea id="note-text" rows="6" placeholder="Введите текст заметки...">${existingNote}</textarea>
                    </div>
                    <div class="modal-footer">
                        <button id="note-cancel" class="btn-secondary">Отмена</button>
                        <button id="note-save" class="btn-primary">Сохранить</button>
                    </div>
                </div>
            `;
            document.body.appendChild(modal);
            
            // Обработчики событий
            modal.querySelector('.modal-close').addEventListener('click', () => hideNoteModal());
            modal.querySelector('#note-cancel').addEventListener('click', () => hideNoteModal());
            modal.querySelector('#note-save').addEventListener('click', saveNote);
        }
        
        modal.style.display = 'block';
        
        // Функция сохранения заметки
        async function saveNote() {
            const noteText = document.getElementById('note-text').value.trim();
            
            if (!noteText) {
                showNotification('Введите текст заметки', 'warning');
                return;
            }
            
            try {
                const response = await fetch('/api/notes/save.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${currentUser.token}`
                    },
                    body: JSON.stringify({
                        entity_type: getApiEntityType(),
                        entity_id: selectedItem.id,
                        note: noteText
                    })
                });
                
                const result = await response.json();
                
                if (result.success) {
                    showNotification(result.message, 'success');
                    currentStatus.hasNote = true;
                    hideNoteModal();
                    await updateCounters();
                } else {
                    showNotification(result.message || 'Ошибка сохранения', 'error');
                }
            } catch (error) {
                console.error('Ошибка:', error);
                showNotification('Ошибка сохранения заметки', 'error');
            }
        }
        
        function hideNoteModal() {
            modal.style.display = 'none';
        }
    }

    // Показ модального окна для сообщения
    function showMessageModal(existingMessage = '', recipientId, isEdit = false) {
        const modalId = 'message-modal';
        let modal = document.getElementById(modalId);
        
        if (!modal) {
            modal = document.createElement('div');
            modal.id = modalId;
            modal.className = 'communications-modal';
            modal.innerHTML = `
                <div class="modal-content">
                    <div class="modal-header">
                        <h3>${isEdit ? 'Редактировать сообщение' : 'Отправить сообщение'}</h3>
                        <button class="modal-close">&times;</button>
                    </div>
                    <div class="modal-body">
                        <textarea id="message-text" rows="6" placeholder="Введите текст сообщения...">${existingMessage}</textarea>
                    </div>
                    <div class="modal-footer">
                        <button id="message-cancel" class="btn-secondary">Отмена</button>
                        <button id="message-send" class="btn-primary">Отправить</button>
                    </div>
                </div>
            `;
            document.body.appendChild(modal);
            
            // Обработчики событий
            modal.querySelector('.modal-close').addEventListener('click', () => hideMessageModal());
            modal.querySelector('#message-cancel').addEventListener('click', () => hideMessageModal());
            modal.querySelector('#message-send').addEventListener('click', sendMessage);
        }
        
        modal.style.display = 'block';
        
        // Функция отправки сообщения
        async function sendMessage() {
            const messageText = document.getElementById('message-text').value.trim();
            
            if (!messageText) {
                showNotification('Введите текст сообщения', 'warning');
                return;
            }
            
            try {
                const response = await fetch('/api/messages/send.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${currentUser.token}`
                    },
                    body: JSON.stringify({
                        recipient_id: recipientId,
                        entity_type: getApiEntityType(),
                        entity_id: selectedItem.id,
                        message: messageText
                    })
                });
                
                const result = await response.json();
                
                if (result.success) {
                    showNotification(result.message, 'success');
                    currentStatus.hasMessage = true;
                    hideMessageModal();
                } else {
                    showNotification(result.message || 'Ошибка отправки', 'error');
                }
            } catch (error) {
                console.error('Ошибка:', error);
                showNotification('Ошибка отправки сообщения', 'error');
            }
        }
        
        function hideMessageModal() {
            modal.style.display = 'none';
        }
    }

    // Показ избранного
    async function showFavorites() {
        try {
            const response = await fetch('/api/favorites/list.php', {
                headers: {
                    'Authorization': `Bearer ${currentUser.token}`
                }
            });
            
            if (response.ok) {
                const data = await response.json();
                if (data.success) {
                    showListModal('Избранное', data.items);
                }
            }
        } catch (error) {
            console.error('Ошибка:', error);
            showNotification('Ошибка загрузки избранного', 'error');
        }
    }

    // Показ заметок
    async function showNotes() {
        try {
            const response = await fetch('/api/notes/list.php', {
                headers: {
                    'Authorization': `Bearer ${currentUser.token}`
                }
            });
            
            if (response.ok) {
                const data = await response.json();
                if (data.success) {
                    showListModal('Мои заметки', data.items);
                }
            }
        } catch (error) {
            console.error('Ошибка:', error);
            showNotification('Ошибка загрузки заметок', 'error');
        }
    }

    // Показ закладок
    async function showBookmarks() {
        try {
            const response = await fetch('/api/bookmarks/list.php', {
                headers: {
                    'Authorization': `Bearer ${currentUser.token}`
                }
            });
            
            if (response.ok) {
                const data = await response.json();
                if (data.success) {
                    showListModal('Закладки (Темы)', data.items);
                }
            }
        } catch (error) {
            console.error('Ошибка:', error);
            showNotification('Ошибка загрузки закладок', 'error');
        }
    }

    // Общая функция показа списка
    function showListModal(title, items) {
        const modalId = 'list-modal';
        let modal = document.getElementById(modalId);
        
        if (!modal) {
            modal = document.createElement('div');
            modal.id = modalId;
            modal.className = 'communications-modal';
            document.body.appendChild(modal);
        }
        
        let itemsHtml = '';
        if (items && items.length > 0) {
            itemsHtml = items.map(item => `
                <div class="list-item" data-id="${item.id}" data-type="${item.entity_type || 'item'}">
                    <div class="item-title">${item.title || item.name || 'Без названия'}</div>
                    <div class="item-meta">${item.entity_type || ''} • ${item.created_at ? new Date(item.created_at).toLocaleDateString() : ''}</div>
                </div>
            `).join('');
        } else {
            itemsHtml = '<div class="empty-list">Список пуст</div>';
        }
        
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>${title}</h3>
                    <button class="modal-close">&times;</button>
                </div>
                <div class="modal-body">
                    <div class="items-list">
                        ${itemsHtml}
                    </div>
                </div>
                <div class="modal-footer">
                    <button class="modal-close-btn btn-secondary">Закрыть</button>
                </div>
            </div>
        `;
        
        modal.style.display = 'block';
        
        // Обработчики событий
        modal.querySelector('.modal-close').addEventListener('click', () => modal.style.display = 'none');
        modal.querySelector('.modal-close-btn').addEventListener('click', () => modal.style.display = 'none');
        
        // Обработка клика по элементам списка
        modal.querySelectorAll('.list-item').forEach(item => {
            item.addEventListener('click', function() {
                const itemId = this.dataset.id;
                const itemType = this.dataset.type;
                console.log('Выбран элемент из списка:', itemId, itemType);
                // TODO: Реализовать переход к выбранному элементу
                modal.style.display = 'none';
            });
        });
    }

    // Вспомогательная функция для уведомлений
    function showNotification(message, type = 'info') {
        // Используем существующую систему уведомлений или создаем простую
        if (typeof AppUpdated !== 'undefined' && AppUpdated.showNotification) {
            AppUpdated.showNotification(message, type);
        } else {
            // Простая реализация
            const notification = document.createElement('div');
            notification.className = `simple-notification ${type}`;
            notification.textContent = message;
            notification.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                padding: 12px 20px;
                background: ${type === 'error' ? '#f44336' : type === 'warning' ? '#ff9800' : type === 'success' ? '#4caf50' : '#2196f3'};
                color: white;
                border-radius: 4px;
                z-index: 10000;
                animation: slideIn 0.3s ease-out;
            `;
            
            document.body.appendChild(notification);
            
            setTimeout(() => {
                notification.style.animation = 'slideOut 0.3s ease-out';
                setTimeout(() => notification.remove(), 300);
            }, 3000);
        }
    }

    // Публичные методы
    return {
        init: init,
        setSelectedItem: function(itemId, itemName, itemData = {}) {
            selectedItem = {
                id: itemId,
                name: itemName,
                ...itemData
            };
            console.log('🎯 Выбран элемент:', selectedItem);
            
            // Проверяем текущее состояние (избранное, оценка)
            checkCurrentStatus();
        },
        refreshCounters: updateCounters,
        getCurrentPage: function() { return currentPage; },
        getCurrentUser: function() { return currentUser; }
    };
})();

// Глобальная доступность
window.CommunicationsManager = CommunicationsManager;

// Инициализация
document.addEventListener('DOMContentLoaded', function() {
    // Даем время на загрузку других скриптов и авторизацию
    setTimeout(() => {
        CommunicationsManager.init();
    }, 1000);
});

// Стили для модальных окон (можно вынести в CSS)
const style = document.createElement('style');
style.textContent = `
    .communications-modal {
        display: none;
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.5);
        z-index: 9999;
        animation: fadeIn 0.3s ease-out;
    }
    
    .communications-modal .modal-content {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background: white;
        border-radius: 8px;
        min-width: 400px;
        max-width: 600px;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
    }
    
    .communications-modal .modal-header {
        padding: 16px 20px;
        border-bottom: 1px solid #eee;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    
    .communications-modal .modal-header h3 {
        margin: 0;
        color: #001C33;
        font-size: 18px;
    }
    
    .communications-modal .modal-close {
        background: none;
        border: none;
        font-size: 24px;
        cursor: pointer;
        color: #666;
    }
    
    .communications-modal .modal-body {
        padding: 20px;
    }
    
    .communications-modal textarea {
        width: 100%;
        padding: 10px;
        border: 1px solid #ddd;
        border-radius: 4px;
        font-family: inherit;
        resize: vertical;
    }
    
    .communications-modal .modal-footer {
        padding: 16px 20px;
        border-top: 1px solid #eee;
        text-align: right;
    }
    
    .communications-modal .btn-primary,
    .communications-modal .btn-secondary {
        padding: 8px 16px;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        font-size: 14px;
    }
    
    .communications-modal .btn-primary {
        background: #001C33;
        color: white;
        margin-left: 8px;
    }
    
    .communications-modal .btn-secondary {
        background: #f0f0f0;
        color: #333;
    }
    
    .communications-modal .items-list {
        max-height: 400px;
        overflow-y: auto;
    }
    
    .communications-modal .list-item {
        padding: 12px;
        border-bottom: 1px solid #eee;
        cursor: pointer;
    }
    
    .communications-modal .list-item:hover {
        background: #f9f9f9;
    }
    
    .communications-modal .item-title {
        font-weight: bold;
        color: #001C33;
    }
    
    .communications-modal .item-meta {
        font-size: 12px;
        color: #666;
        margin-top: 4px;
    }
    
    .communications-modal .empty-list {
        text-align: center;
        padding: 40px 20px;
        color: #666;
    }
    
    @keyframes fadeIn {
        from { opacity: 0; }
        to { opacity: 1; }
    }
    
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    
    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }
    
    .simple-notification {
        font-family: inherit;
    }
`;
document.head.appendChild(style);