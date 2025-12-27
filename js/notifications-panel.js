// notifications-panel.js - Модуль уведомлений
const NotificationsPanel = (function() {
    // Конфигурация
    const config = {
        panelId: 'notifications',
        storageKey: 'prostvor_notifications',
        demoNotifications: [
            {
                id: '1',
                date: new Date().toISOString(),
                text: 'Новый участник присоединился к вашему проекту'
            },
            {
                id: '2',
                date: new Date(Date.now() - 3600000).toISOString(),
                text: 'Завтра встреча по проекту в 14:00'
            },
            {
                id: '3',
                date: new Date(Date.now() - 86400000).toISOString(),
                text: 'Напоминание: срок сдачи задачи истекает через 2 дня'
            },
            {
                id: '4',
                date: new Date(Date.now() - 172800000).toISOString(),
                text: 'Получено новое сообщение от администратора'
            },
            {
                id: '5',
                date: new Date(Date.now() - 259200000).toISOString(),
                text: 'Ваш проект был одобрен модератором'
            }
        ]
    };

    // Текущее состояние
    let currentState = {
        notifications: []
    };

    // Инициализация
    function init() {
        try {
            loadNotifications();
            render();
            updateCounter();
        } catch (error) {
            console.error('Ошибка инициализации уведомлений:', error);
        }
    }

    // Загрузка уведомлений
    function loadNotifications() {
        try {
            const notifications = localStorage.getItem(config.storageKey);
            currentState.notifications = notifications ? JSON.parse(notifications) : [];
            
            // Если нет уведомлений, создаем демо данные
            if (currentState.notifications.length === 0) {
                currentState.notifications = config.demoNotifications;
                saveNotifications();
            }
        } catch (error) {
            console.error('Ошибка загрузки уведомлений:', error);
            currentState.notifications = config.demoNotifications;
        }
    }

    // Сохранение уведомлений
    function saveNotifications() {
        try {
            localStorage.setItem(config.storageKey, JSON.stringify(currentState.notifications));
        } catch (error) {
            console.error('Ошибка сохранения уведомлений:', error);
        }
    }

    // Рендер уведомлений
    function render() {
        const panel = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-body`);
        if (!panel) return;

        let html = `
            <div class="notifications-container">
                <div class="notifications-list">
                    ${currentState.notifications.map(notification => renderNotification(notification)).join('')}
                </div>
            </div>
        `;

        panel.innerHTML = html;
        addScrollIndicators();
    }

    // Рендер уведомления
    function renderNotification(notification) {
        const date = new Date(notification.date);
        const dateStr = `${String(date.getDate()).padStart(2, '0')}.${String(date.getMonth() + 1).padStart(2, '0')}.${date.getFullYear()}`;
        const timeStr = `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
        
        return `
            <div class="notification-item" data-notification-id="${notification.id}">
                <div class="notification-date">${dateStr} - ${timeStr}</div>
                <div class="notification-text">${notification.text}</div>
            </div>
        `;
    }

    // Добавление индикаторов прокрутки
    function addScrollIndicators() {
        const notificationsList = document.querySelector('.notifications-list');
        if (!notificationsList) return;
        
        const scrollTop = document.createElement('div');
        scrollTop.className = 'scroll-indicator-notifications top';
        scrollTop.innerHTML = '&#x25B2;';
        
        const scrollBottom = document.createElement('div');
        scrollBottom.className = 'scroll-indicator-notifications bottom';
        scrollBottom.innerHTML = '&#x25BC;';
        
        notificationsList.insertBefore(scrollTop, notificationsList.firstChild);
        notificationsList.appendChild(scrollBottom);
        
        // Обработчики прокрутки
        notificationsList.addEventListener('scroll', () => {
            scrollTop.style.opacity = notificationsList.scrollTop > 10 ? '1' : '0';
            const isAtBottom = notificationsList.scrollHeight - notificationsList.clientHeight - notificationsList.scrollTop < 10;
            scrollBottom.style.opacity = isAtBottom ? '0' : '1';
        });
    }

    // Добавление уведомления
    function addNotification(text) {
        try {
            const newNotification = {
                id: Date.now().toString() + Math.random().toString(36).substr(2, 5),
                date: new Date().toISOString(),
                text: text
            };
            
            currentState.notifications.unshift(newNotification); // Добавляем в начало
            saveNotifications();
            render();
            updateCounter();
            
            return newNotification;
        } catch (error) {
            console.error('Ошибка добавления уведомления:', error);
            throw error;
        }
    }

    // Обновление счетчика
    function updateCounter() {
        const count = currentState.notifications.length;
        const counterElement = document.getElementById(`${config.panelId}Count`);
        const labelElement = document.querySelector(`.panel-label[data-panel="${config.panelId}"]`);
        
        if (counterElement) counterElement.textContent = count;
        if (labelElement) labelElement.setAttribute('data-count', count);
        
        // Сохраняем в localStorage
        localStorage.setItem(`panel_${config.panelId}_count`, count);
    }

    // Публичные методы
    return {
        init: init,
        addNotification: addNotification,
        getNotifications: function() { return currentState.notifications; },
        updateCounter: updateCounter
    };
})();