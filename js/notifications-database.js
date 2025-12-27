// База данных уведомлений
const NotificationsBase = (function() {
    const STORAGE_KEY = 'prostvor_notifications_database';
    
    // Типы уведомлений
    const NOTIFICATION_TYPES = {
        MESSAGE: 'Сообщение',
        TASK: 'Задача',
        EVENT: 'Событие',
        PROJECT: 'Проект',
        SYSTEM: 'Системное'
    };

    // Инициализация базы данных
    function init() {
        try {
            const notifications = localStorage.getItem(STORAGE_KEY);
            if (!notifications) {
                saveNotifications([]);
            }
            return true;
        } catch (error) {
            console.error('Ошибка инициализации базы данных уведомлений:', error);
            return false;
        }
    }

    // Сохранение уведомлений
    function saveNotifications(notifications) {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(notifications));
            return true;
        } catch (error) {
            console.error('Ошибка сохранения уведомлений:', error);
            return false;
        }
    }

    // Получить все уведомления пользователя
    function getUserNotifications(userId) {
        try {
            const notifications = localStorage.getItem(STORAGE_KEY);
            const allNotifications = notifications ? JSON.parse(notifications) : [];
            return allNotifications.filter(notification => notification.userId === userId);
        } catch (error) {
            console.error('Ошибка получения уведомлений:', error);
            return [];
        }
    }

    // Получить непрочитанные уведомления
    function getUnreadNotifications(userId) {
        const userNotifications = getUserNotifications(userId);
        return userNotifications.filter(notification => !notification.read);
    }

    // Создать новое уведомление
    function createNotification(userId, notificationData) {
        try {
            const notification = {
                id: Date.now().toString() + '_' + Math.random().toString(36).substr(2, 9),
                userId: userId,
                type: notificationData.type || NOTIFICATION_TYPES.SYSTEM,
                title: notificationData.title || '',
                message: notificationData.message || '',
                date: new Date().toISOString(),
                read: false,
                priority: notificationData.priority || 'Нормальный',
                action: notificationData.action || null,
                senderId: notificationData.senderId || null,
                relatedId: notificationData.relatedId || null
            };

            const notifications = localStorage.getItem(STORAGE_KEY);
            const allNotifications = notifications ? JSON.parse(notifications) : [];
            allNotifications.push(notification);
            saveNotifications(allNotifications);

            // Обновляем счетчик на панели
            updateNotificationCount(userId);

            return notification;
        } catch (error) {
            console.error('Ошибка создания уведомления:', error);
            throw error;
        }
    }

    // Пометить уведомление как прочитанное
    function markAsRead(notificationId) {
        try {
            const notifications = localStorage.getItem(STORAGE_KEY);
            const allNotifications = notifications ? JSON.parse(notifications) : [];
            const notificationIndex = allNotifications.findIndex(n => n.id === notificationId);

            if (notificationIndex === -1) {
                throw new Error('Уведомление не найдено');
            }

            allNotifications[notificationIndex].read = true;
            saveNotifications(allNotifications);

            // Обновляем счетчик
            const userId = allNotifications[notificationIndex].userId;
            updateNotificationCount(userId);

            return allNotifications[notificationIndex];
        } catch (error) {
            console.error('Ошибка отметки уведомления как прочитанного:', error);
            throw error;
        }
    }

    // Пометить все уведомления как прочитанные
    function markAllAsRead(userId) {
        try {
            const notifications = localStorage.getItem(STORAGE_KEY);
            const allNotifications = notifications ? JSON.parse(notifications) : [];
            
            allNotifications.forEach(notification => {
                if (notification.userId === userId && !notification.read) {
                    notification.read = true;
                }
            });
            
            saveNotifications(allNotifications);
            updateNotificationCount(userId);

            return true;
        } catch (error) {
            console.error('Ошибка отметки всех уведомлений как прочитанных:', error);
            throw error;
        }
    }

    // Удалить уведомление
    function deleteNotification(notificationId) {
        try {
            const notifications = localStorage.getItem(STORAGE_KEY);
            const allNotifications = notifications ? JSON.parse(notifications) : [];
            const notificationIndex = allNotifications.findIndex(n => n.id === notificationId);

            if (notificationIndex === -1) {
                throw new Error('Уведомление не найдено');
            }

            const userId = allNotifications[notificationIndex].userId;
            allNotifications.splice(notificationIndex, 1);
            saveNotifications(allNotifications);
            updateNotificationCount(userId);

            return true;
        } catch (error) {
            console.error('Ошибка удаления уведомления:', error);
            throw error;
        }
    }

    // Удалить все прочитанные уведомления
    function deleteAllRead(userId) {
        try {
            const notifications = localStorage.getItem(STORAGE_KEY);
            const allNotifications = notifications ? JSON.parse(notifications) : [];
            const filteredNotifications = allNotifications.filter(n => 
                !(n.userId === userId && n.read)
            );
            
            saveNotifications(filteredNotifications);
            updateNotificationCount(userId);

            return true;
        } catch (error) {
            console.error('Ошибка удаления прочитанных уведомлений:', error);
            throw error;
        }
    }

    // Обновить счетчик уведомлений
    function updateNotificationCount(userId) {
        const unreadCount = getUnreadNotifications(userId).length;
        
        // Обновляем счетчик в DOM
        const counterElement = document.getElementById('notificationsCount');
        if (counterElement) {
            counterElement.textContent = unreadCount;
        }
        
        // Обновляем счетчик на метке панели
        const labelElement = document.querySelector('.panel-label[data-panel="notifications"]');
        if (labelElement) {
            labelElement.setAttribute('data-count', unreadCount);
        }
        
        // Сохраняем в localStorage
        localStorage.setItem(`panel_notifications_count_${userId}`, unreadCount);
        
        return unreadCount;
    }

    // Получить количество непрочитанных уведомлений
    function getUnreadCount(userId) {
        return getUnreadNotifications(userId).length;
    }

    // Создать тестовые уведомления
    function createTestNotifications(userId) {
        const testNotifications = [
            {
                type: NOTIFICATION_TYPES.MESSAGE,
                title: 'Новое сообщение',
                message: 'Вы получили новое личное сообщение от пользователя Иван',
                priority: 'Высокий'
            },
            {
                type: NOTIFICATION_TYPES.TASK,
                title: 'Задача обновлена',
                message: 'Статус задачи "Разработка интерфейса" изменен на "В работе"',
                priority: 'Нормальный'
            },
            {
                type: NOTIFICATION_TYPES.EVENT,
                title: 'Напоминание о событии',
                message: 'Через 1 час начинается собрание проекта "PROSTVOR"',
                priority: 'Высокий'
            },
            {
                type: NOTIFICATION_TYPES.PROJECT,
                title: 'Новый участник проекта',
                message: 'К проекту "Творческая мастерская" присоединился новый участник',
                priority: 'Нормальный'
            },
            {
                type: NOTIFICATION_TYPES.SYSTEM,
                title: 'Обновление системы',
                message: 'Система была обновлена. Добавлены новые функции календаря',
                priority: 'Низкий'
            }
        ];

        testNotifications.forEach(notificationData => {
            createNotification(userId, notificationData);
        });
    }

    // Инициализация при загрузке
    init();

    // Публичные методы
    return {
        getUserNotifications,
        getUnreadNotifications,
        createNotification,
        markAsRead,
        markAllAsRead,
        deleteNotification,
        deleteAllRead,
        updateNotificationCount,
        getUnreadCount,
        createTestNotifications,
        NOTIFICATION_TYPES
    };
})();