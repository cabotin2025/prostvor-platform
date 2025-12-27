// База данных календарных событий
const CalendarBase = (function() {
    const STORAGE_KEY = 'prostvor_calendar_database';
    
    // Инициализация базы данных
    function init() {
        try {
            const events = localStorage.getItem(STORAGE_KEY);
            if (!events) {
                saveEvents([]);
            }
            return true;
        } catch (error) {
            console.error('Ошибка инициализации базы данных календаря:', error);
            return false;
        }
    }

    // Сохранение событий
    function saveEvents(events) {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(events));
            return true;
        } catch (error) {
            console.error('Ошибка сохранения событий:', error);
            return false;
        }
    }

    // Получить все события пользователя
    function getUserEvents(userId) {
        try {
            const events = localStorage.getItem(STORAGE_KEY);
            const allEvents = events ? JSON.parse(events) : [];
            return allEvents.filter(event => event.userId === userId);
        } catch (error) {
            console.error('Ошибка получения событий:', error);
            return [];
        }
    }

    // Создать новое событие
    function createEvent(userId, eventData) {
        try {
            const event = {
                id: Date.now().toString() + '_' + Math.random().toString(36).substr(2, 9),
                userId: userId,
                title: eventData.title || '',
                description: eventData.description || '',
                startDate: eventData.startDate || new Date().toISOString().split('T')[0],
                endDate: eventData.endDate || eventData.startDate || new Date().toISOString().split('T')[0],
                startTime: eventData.startTime || '00:00',
                endTime: eventData.endTime || '23:59',
                allDay: eventData.allDay || false,
                type: eventData.type || 'Личное',
                location: eventData.location || '',
                participants: eventData.participants || [],
                reminder: eventData.reminder || null,
                color: eventData.color || '#4CAF50',
                createdDate: new Date().toISOString()
            };

            const events = localStorage.getItem(STORAGE_KEY);
            const allEvents = events ? JSON.parse(events) : [];
            allEvents.push(event);
            saveEvents(allEvents);

            return event;
        } catch (error) {
            console.error('Ошибка создания события:', error);
            throw error;
        }
    }

    // Получить события за определенный период
    function getEventsByPeriod(userId, startDate, endDate) {
        try {
            const userEvents = getUserEvents(userId);
            const start = new Date(startDate);
            const end = new Date(endDate);
            
            return userEvents.filter(event => {
                const eventDate = new Date(event.startDate);
                return eventDate >= start && eventDate <= end;
            });
        } catch (error) {
            console.error('Ошибка получения событий за период:', error);
            return [];
        }
    }

    // Получить события на определенную дату
    function getEventsByDate(userId, date) {
        try {
            const userEvents = getUserEvents(userId);
            const targetDate = new Date(date);
            const targetDateString = targetDate.toISOString().split('T')[0];
            
            return userEvents.filter(event => {
                const eventDateString = event.startDate.split('T')[0];
                return eventDateString === targetDateString;
            });
        } catch (error) {
            console.error('Ошибка получения событий на дату:', error);
            return [];
        }
    }

    // Удалить событие
    function deleteEvent(eventId) {
        try {
            const events = localStorage.getItem(STORAGE_KEY);
            const allEvents = events ? JSON.parse(events) : [];
            const filteredEvents = allEvents.filter(event => event.id !== eventId);
            saveEvents(filteredEvents);

            return true;
        } catch (error) {
            console.error('Ошибка удаления события:', error);
            throw error;
        }
    }

    // Обновить событие
    function updateEvent(eventId, updates) {
        try {
            const events = localStorage.getItem(STORAGE_KEY);
            const allEvents = events ? JSON.parse(events) : [];
            const eventIndex = allEvents.findIndex(event => event.id === eventId);

            if (eventIndex === -1) {
                throw new Error('Событие не найдено');
            }

            allEvents[eventIndex] = { ...allEvents[eventIndex], ...updates };
            saveEvents(allEvents);

            return allEvents[eventIndex];
        } catch (error) {
            console.error('Ошибка обновления события:', error);
            throw error;
        }
    }

    // Получить события на сегодня
    function getTodayEvents(userId) {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const todayString = today.toISOString().split('T')[0];
        
        return getEventsByDate(userId, todayString);
    }

    // Получить события на неделю
    function getWeekEvents(userId) {
        const today = new Date();
        const startOfWeek = new Date(today);
        startOfWeek.setDate(today.getDate() - today.getDay() + 1); // Понедельник
        startOfWeek.setHours(0, 0, 0, 0);
        
        const endOfWeek = new Date(startOfWeek);
        endOfWeek.setDate(startOfWeek.getDate() + 6); // Воскресенье
        endOfWeek.setHours(23, 59, 59, 999);

        return getEventsByPeriod(userId, startOfWeek, endOfWeek);
    }

    // Получить события на месяц
    function getMonthEvents(userId, year, month) {
        const startDate = new Date(year, month - 1, 1);
        const endDate = new Date(year, month, 0);
        
        return getEventsByPeriod(userId, startDate, endDate);
    }

    // Получить события на год
    function getYearEvents(userId, year) {
        const startDate = new Date(year, 0, 1);
        const endDate = new Date(year, 11, 31);
        
        return getEventsByPeriod(userId, startDate, endDate);
    }

    // Инициализация при загрузке
    init();

    // Публичные методы
    return {
        getUserEvents,
        createEvent,
        getEventsByPeriod,
        getEventsByDate,
        deleteEvent,
        updateEvent,
        getTodayEvents,
        getWeekEvents,
        getMonthEvents,
        getYearEvents
    };
})();