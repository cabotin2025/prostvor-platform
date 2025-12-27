// Основной модуль для управления иконками коммуникаций
const CommunicationsManager = (function() {
    // Конфигурация
    const config = {
        icons: {
            favorite: {
                icon: '../images/FavoriteIcon.svg',
                activeIcon: '../images/FavoriteIconActive.svg'
            },
            note: {
                icon: '../images/NoteIcon.svg',
                activeIcon: '../images/NoteIconActive.svg'
            },
            bookmark: {
                icon: '../images/BookmarkIcon.svg',
                activeIcon: '../images/BookmarkIconActive.svg'
            },
            message: {
                icon: '../images/MessIcon.svg',
                activeIcon: '../images/MessIconActive.svg'
            },
            smile: {
                icon: '../images/SmileIcon.svg',
                activeIcon: '../images/SmileIconActive.svg'
            }
        },
        pageTypes: ['projects', 'ideas', 'resources', 'topics', 'actors', 'services', 'events']
    };

    // Состояние
    let state = {
        currentPage: null,
        currentItemId: null,
        currentItemType: null,
        userCounters: {
            favorites: 0,
            notes: 0,
            bookmarks: 0
        }
    };

    // Инициализация
    function init() {
        try {
            // Определяем текущую страницу
            detectCurrentPage();
            
            // Загружаем состояние пользователя
            loadUserState();
            
            // Инициализируем блок коммуникаций
            initCommunicationsBlock();
            
            // Инициализируем иконки на странице
            if (state.currentPage) {
                initPageIcons();
            }
            
            console.log('CommunicationsManager инициализирован для страницы:', state.currentPage);
        } catch (error) {
            console.error('Ошибка инициализации CommunicationsManager:', error);
        }
    }

    // Определение текущей страницы
    function detectCurrentPage() {
        const path = window.location.pathname.toLowerCase();
        const pageName = path.split('/').pop().replace('.html', '').replace('.php', '');
        
        config.pageTypes.forEach(pageType => {
            if (pageName.includes(pageType) || path.includes(pageType)) {
                state.currentPage = pageType;
                state.currentItemType = pageType.slice(0, -1); // Убираем 's' в конце
            }
        });
        
        // Если страница не определена, пробуем по заголовку
        if (!state.currentPage) {
            const title = document.title.toLowerCase();
            config.pageTypes.forEach(pageType => {
                if (title.includes(pageType)) {
                    state.currentPage = pageType;
                    state.currentItemType = pageType.slice(0, -1);
                }
            });
        }
    }

    // Загрузка состояния пользователя
    function loadUserState() {
        try {
            const savedState = JSON.parse(localStorage.getItem('communications_state') || '{}');
            state.userCounters = savedState.userCounters || {
                favorites: 0,
                notes: 0,
                bookmarks: 0
            };
        } catch (error) {
            console.error('Ошибка загрузки состояния:', error);
        }
    }

    // Сохранение состояния пользователя
    function saveUserState() {
        try {
            localStorage.setItem('communications_state', JSON.stringify({
                userCounters: state.userCounters
            }));
        } catch (error) {
            console.error('Ошибка сохранения состояния:', error);
        }
    }

    // Инициализация блока коммуникаций
    function initCommunicationsBlock() {
        // Создаем ЛЕВУЮ часть - Иконки для текущей страницы
        const leftIcons = document.createElement('div');
        leftIcons.className = 'page-communication-icons';
        leftIcons.id = 'pageCommunicationIcons';
        
        // Определяем, какие иконки показывать для текущей страницы
        const pageIcons = getPageIconsForCurrentPage();
        
        pageIcons.forEach(icon => {
            const button = createPageIconButton(icon.type, icon.label);
            leftIcons.appendChild(button);
        });
        
        // Создаем ПРАВУЮ часть - Избранное, Заметки, Закладки
        const rightIcons = document.createElement('div');
        rightIcons.className = 'communications-right';
        rightIcons.id = 'communicationsRight';
        
        const rightIconTypes = [
            { type: 'favorite', label: 'Избранное' },
            { type: 'note', label: 'Заметки' },
            { type: 'bookmark', label: 'Закладки' }
        ];
        
        rightIconTypes.forEach(icon => {
            const iconGroup = createIconGroup(icon.type, icon.label);
            rightIcons.appendChild(iconGroup);
        });
        
        // Вставляем оба блока ВНЕ шапки, но рядом с ней
        const header = document.querySelector('.header');
        if (header) {
            document.body.insertBefore(leftIcons, document.body.firstChild);
            document.body.insertBefore(rightIcons, document.body.firstChild);
        }
        
        updateHeaderCounters();
    }

    // Вспомогательная функция для получения иконок текущей страницы
    function getPageIconsForCurrentPage() {
        if (!state.currentPage) return [];
        
        // Базовые иконки для всех страниц
        const baseIcons = [
            { type: 'favorite', label: 'В избранное' },
            { type: 'note', label: 'Заметка' }
        ];
        
        // Дополнительные иконки для конкретных страниц
        switch(state.currentPage) {
            case 'projects':
                return [...baseIcons, 
                       { type: 'message', label: 'Сообщение' },
                       { type: 'smile', label: 'Оценка' }];
            case 'ideas':
                return [...baseIcons,
                       { type: 'message', label: 'Обсудить' }];
            case 'actors':
                return [...baseIcons,
                       { type: 'message', label: 'Написать' }];
            default:
                return baseIcons;
        }
    }

    // Создание группы иконок для правой части
    function createIconGroup(type, label) {
        const group = document.createElement('div');
        group.className = 'communication-icon-group';
        group.dataset.type = type;
        group.title = label;
        
        const img = document.createElement('img');
        img.className = 'communication-icon';
        img.src = config.icons[type].icon;
        img.alt = label;
        
        const count = document.createElement('div');
        count.className = 'communication-count';
        count.textContent = state.userCounters[type] || '0';
        
        group.appendChild(img);
        group.appendChild(count);
        
        // Обработчик клика
        group.addEventListener('click', function() {
            handleHeaderIconClick(type);
        });
        
        return group;
    }

    // Создание кнопки для левой части
    function createPageIconButton(type, label) {
        const button = document.createElement('button');
        button.className = 'page-icon-button';
        button.dataset.type = type;
        button.title = label;
        
        const img = document.createElement('img');
        img.className = 'page-icon';
        img.src = config.icons[type].icon;
        img.alt = label;
        
        const labelSpan = document.createElement('span');
        labelSpan.className = 'page-icon-label';
        labelSpan.textContent = label;
        
        button.appendChild(img);
        button.appendChild(labelSpan);
        
        // Обработчик клика
        button.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            
            if (!state.currentItemId) {
                showNotification('Пожалуйста, выберите элемент из списка', 'warning');
                return;
            }
            
            handlePageIconClick(type);
        });
        
        return button;
    }

    // Инициализация иконок на странице
    function initPageIcons() {
        setupContentItemListeners();
        updateActiveIcons();
    }

    // Настройка обработчиков для элементов контента
    function setupContentItemListeners() {
        // Для страницы проектов
        if (state.currentPage === 'projects') {
            const projectItems = document.querySelectorAll('.project-item, [data-project-id]');
            projectItems.forEach(item => {
                item.addEventListener('click', function() {
                    const projectId = this.dataset.projectId || this.id;
                    if (projectId) {
                        state.currentItemId = projectId;
                        updateActiveIcons();
                    }
                });
            });
        }
        
        // Добавьте аналогичные обработчики для других типов страниц
    }

    // Обновление активных иконок
    function updateActiveIcons() {
        if (!state.currentItemId) return;
        
        // Проверяем состояние для текущего элемента
        const isFavorite = FavoritesManager.isFavorite(state.currentItemId, state.currentItemType);
        const hasNote = NotesManager.hasNote(state.currentItemId, state.currentItemType);
        const hasRating = RatingsManager.hasRating(state.currentItemId, state.currentItemType);
        
        // Обновляем иконки
        updateIconState('favorite', isFavorite);
        updateIconState('note', hasNote);
        updateIconState('smile', hasRating);
    }

    // Обновление состояния иконки
    function updateIconState(type, isActive) {
        const button = document.querySelector(`.page-icon-button[data-type="${type}"]`);
        if (!button) return;
        
        const img = button.querySelector('img');
        if (img) {
            img.src = isActive ? config.icons[type].activeIcon : config.icons[type].icon;
        }
        
        if (isActive) {
            button.classList.add('active');
        } else {
            button.classList.remove('active');
        }
    }

    // Обработка клика по иконке в шапке
    function handleHeaderIconClick(type) {
        switch(type) {
            case 'favorite':
                showFavoritesList();
                break;
            case 'note':
                showNotesList();
                break;
            case 'bookmark':
                showBookmarksList();
                break;
        }
    }

    // Обновление счетчиков в шапке
    function updateHeaderCounters() {
        const groups = document.querySelectorAll('.communication-icon-group');
        groups.forEach(group => {
            const type = group.dataset.type;
            const countElement = group.querySelector('.communication-count');
            if (countElement) {
                countElement.textContent = state.userCounters[type] || '0';
            }
        });
    }

    // Обработка клика по иконке на странице
    function handlePageIconClick(type) {
        switch(type) {
            case 'favorite':
                toggleFavorite();
                break;
            case 'note':
                toggleNote();
                break;
            case 'message':
                toggleMessage();
                break;
            case 'smile':
                toggleRating();
                break;
        }
    }

    // Переключение избранного
    function toggleFavorite() {
        if (!state.currentItemId || !state.currentItemType) return;
        
        const itemName = getCurrentItemName();
        const wasAdded = FavoritesManager.toggleFavorite(
            state.currentItemId,
            state.currentItemType,
            itemName
        );
        
        // Обновляем состояние
        state.userCounters.favorites = FavoritesManager.getFavoritesCount();
        updateHeaderCounters();
        updateIconState('favorite', wasAdded);
        saveUserState();
        
        // Показываем уведомление
        const message = wasAdded 
            ? `Добавлено в избранное: ${itemName}`
            : `Удалено из избранного: ${itemName}`;
        showNotification(message, wasAdded ? 'success' : 'info');
    }

    // Переключение заметки
    function toggleNote() {
        if (!state.currentItemId || !state.currentItemType) return;
        
        const itemName = getCurrentItemName();
        const hasNote = NotesManager.hasNote(state.currentItemId, state.currentItemType);
        
        if (hasNote) {
            // Показать существующую заметку
            showNote();
        } else {
            // Создать новую заметку
            createNote();
        }
    }

    // Создание заметки
    function createNote() {
        const form = createCommunicationForm('note', 'Добавить заметку');
        document.body.appendChild(form);
    }

    // Показать заметку
    function showNote() {
        const note = NotesManager.getNote(state.currentItemId, state.currentItemType);
        if (note) {
            showCommunicationContent('note', 'Заметка', note.text, note.date);
        }
    }

    // Переключение сообщения
    function toggleMessage() {
        if (!state.currentItemId || !state.currentItemType) return;
        
        const itemName = getCurrentItemName();
        const hasMessage = MessagesManager.hasMessage(state.currentItemId, state.currentItemType);
        
        if (hasMessage) {
            // Показать существующее сообщение
            showMessage();
        } else {
            // Создать новое сообщение
            createMessage();
        }
    }

    // Создание сообщения
    function createMessage() {
        const form = createCommunicationForm('message', 'Отправить сообщение');
        document.body.appendChild(form);
    }

    // Показать сообщение
    function showMessage() {
        const message = MessagesManager.getMessage(state.currentItemId, state.currentItemType);
        if (message) {
            showCommunicationContent('message', 'Сообщение', message.text, message.date);
        }
    }

    // Переключение оценки
    function toggleRating() {
        if (!state.currentItemId || !state.currentItemType) return;
        
        const itemName = getCurrentItemName();
        const wasRated = RatingsManager.toggleRating(
            state.currentItemId,
            state.currentItemType,
            itemName
        );
        
        updateIconState('smile', wasRated);
        
        const message = wasRated 
            ? `Поставлена оценка: ${itemName}`
            : `Оценка снята: ${itemName}`;
        showNotification(message, wasRated ? 'success' : 'info');
    }

    // Получение имени текущего элемента
    function getCurrentItemName() {
        // В зависимости от страницы, получаем имя элемента
        switch(state.currentPage) {
            case 'projects':
                return document.getElementById('projectTitle')?.textContent || 'Проект';
            case 'ideas':
                return document.querySelector('.idea-title')?.textContent || 'Идея';
            // Добавьте другие случаи
            default:
                return state.currentItemType;
        }
    }

    // Создание формы для коммуникации
    function createCommunicationForm(type, title) {
        const overlay = document.createElement('div');
        overlay.className = 'form-overlay';
        
        const form = document.createElement('div');
        form.className = 'communication-form';
        
        const itemName = getCurrentItemName();
        
        form.innerHTML = `
            <div class="communication-form-header">
                <h3>${title} для "${itemName}"</h3>
                <button class="close-form">&times;</button>
            </div>
            <textarea class="communication-textarea" 
                      placeholder="Введите текст..." 
                      maxlength="1000"></textarea>
            <div class="communication-form-actions">
                <button class="communication-cancel-btn">Отмена</button>
                <button class="communication-submit-btn">Сохранить</button>
            </div>
        `;
        
        // Обработчики
        const closeBtn = form.querySelector('.close-form');
        const cancelBtn = form.querySelector('.communication-cancel-btn');
        const submitBtn = form.querySelector('.communication-submit-btn');
        const textarea = form.querySelector('.communication-textarea');
        
        const closeForm = function() {
            document.body.removeChild(overlay);
            document.body.removeChild(form);
        };
        
        closeBtn.addEventListener('click', closeForm);
        cancelBtn.addEventListener('click', closeForm);
        overlay.addEventListener('click', closeForm);
        
        submitBtn.addEventListener('click', function() {
            const text = textarea.value.trim();
            if (text) {
                if (type === 'note') {
                    NotesManager.saveNote(state.currentItemId, state.currentItemType, text);
                    state.userCounters.notes = NotesManager.getNotesCount();
                } else if (type === 'message') {
                    MessagesManager.saveMessage(state.currentItemId, state.currentItemType, text);
                }
                
                updateHeaderCounters();
                updateIconState(type, true);
                saveUserState();
                
                showNotification(`${title} сохранено`, 'success');
                closeForm();
            } else {
                showNotification('Введите текст', 'warning');
            }
        });
        
        // Закрытие по Escape
        document.addEventListener('keydown', function escHandler(e) {
            if (e.key === 'Escape') {
                closeForm();
                document.removeEventListener('keydown', escHandler);
            }
        });
        
        document.body.appendChild(overlay);
        return form;
    }

    // Показать содержание коммуникации
    function showCommunicationContent(type, title, content, date) {
        const overlay = document.createElement('div');
        overlay.className = 'form-overlay';
        
        const display = document.createElement('div');
        display.className = 'communication-display';
        
        const itemName = getCurrentItemName();
        
        display.innerHTML = `
            <div class="communication-form-header">
                <h3>${title} для "${itemName}"</h3>
                <button class="close-form">&times;</button>
            </div>
            <div class="communication-content">${content}</div>
            <div class="communication-info">
                <span>Создано: ${new Date(date).toLocaleString()}</span>
                <button class="communication-cancel-btn">Закрыть</button>
            </div>
        `;
        
        // Обработчики
        const closeBtn = display.querySelector('.close-form');
        const cancelBtn = display.querySelector('.communication-cancel-btn');
        
        const closeDisplay = function() {
            document.body.removeChild(overlay);
            document.body.removeChild(display);
        };
        
        closeBtn.addEventListener('click', closeDisplay);
        cancelBtn.addEventListener('click', closeDisplay);
        overlay.addEventListener('click', closeDisplay);
        
        document.body.appendChild(overlay);
        document.body.appendChild(display);
    }

    // Показать список избранного
    function showFavoritesList() {
        const favorites = FavoritesManager.getFavorites();
        if (favorites.length === 0) {
            showNotification('В избранном пока ничего нет', 'info');
            return;
        }
        
        const overlay = document.createElement('div');
        overlay.className = 'form-overlay';
        
        const list = document.createElement('div');
        list.className = 'communication-form';
        list.style.width = '500px';
        
        list.innerHTML = `
            <div class="communication-form-header">
                <h3>Избранное (${favorites.length})</h3>
                <button class="close-form">&times;</button>
            </div>
            <div class="bookmarks-container">
                ${favorites.map(fav => `
                    <div class="bookmark-item">
                        <span class="bookmark-name">${fav.name}</span>
                        <span class="bookmark-type">${fav.type}</span>
                        <button class="remove-bookmark" data-id="${fav.id}" data-type="${fav.type}">
                            Удалить
                        </button>
                    </div>
                `).join('')}
            </div>
            <div class="communication-form-actions">
                <button class="communication-cancel-btn">Закрыть</button>
            </div>
        `;
        
        // Обработчики
        const closeBtn = list.querySelector('.close-form');
        const cancelBtn = list.querySelector('.communication-cancel-btn');
        
        const closeList = function() {
            document.body.removeChild(overlay);
            document.body.removeChild(list);
        };
        
        closeBtn.addEventListener('click', closeList);
        cancelBtn.addEventListener('click', closeList);
        overlay.addEventListener('click', closeList);
        
        // Обработчики удаления
        list.querySelectorAll('.remove-bookmark').forEach(btn => {
            btn.addEventListener('click', function() {
                const id = this.dataset.id;
                const type = this.dataset.type;
                FavoritesManager.removeFavorite(id, type);
                
                // Обновляем список
                const item = this.closest('.bookmark-item');
                item.remove();
                
                // Обновляем счетчики
                state.userCounters.favorites = FavoritesManager.getFavoritesCount();
                updateHeaderCounters();
                saveUserState();
                
                showNotification('Удалено из избранного', 'success');
                
                // Если список пуст, закрываем окно
                if (FavoritesManager.getFavoritesCount() === 0) {
                    closeList();
                }
            });
        });
        
        document.body.appendChild(overlay);
        document.body.appendChild(list);
    }

    // Показать список заметок
    function showNotesList() {
        const notes = NotesManager.getNotes();
        if (notes.length === 0) {
            showNotification('Заметок пока нет', 'info');
            return;
        }
        
        // Реализация аналогична showFavoritesList
        // ...
    }

    // Показать список закладок
    function showBookmarksList() {
        // Реализация для закладок
        // ...
    }

    // Вспомогательная функция для показа уведомлений
    function showNotification(message, type = 'info') {
        if (typeof AppUpdated !== 'undefined' && AppUpdated.showNotification) {
            AppUpdated.showNotification(message, type);
        } else if (typeof AppUpdatedPanels !== 'undefined' && AppUpdatedPanels.showNotification) {
            AppUpdatedPanels.showNotification(message, type);
        } else {
            // Простой fallback
            const notification = document.createElement('div');
            notification.className = `notification ${type} show`;
            notification.textContent = message;
            document.body.appendChild(notification);
            
            setTimeout(() => {
                notification.classList.remove('show');
                setTimeout(() => {
                    document.body.removeChild(notification);
                }, 300);
            }, 3000);
        }
    }

    // Публичные методы
    return {
        init: init,
        setCurrentItem: function(id, type, name) {
            state.currentItemId = id;
            state.currentItemType = type;
            updateActiveIcons();
        },
        getCurrentItem: function() {
            return {
                id: state.currentItemId,
                type: state.currentItemType,
                name: getCurrentItemName()
            };
        },
        updateCounters: function() {
            state.userCounters.favorites = FavoritesManager.getFavoritesCount();
            state.userCounters.notes = NotesManager.getNotesCount();
            state.userCounters.bookmarks = 0; // Реализовать при необходимости
            updateHeaderCounters();
            saveUserState();
        }
    };
})();

// Инициализация после загрузки DOM
document.addEventListener('DOMContentLoaded', CommunicationsManager.init);