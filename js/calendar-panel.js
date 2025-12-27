// calendar-panel.js - Модуль календаря
const CalendarPanel = (function() {
    // Конфигурация
    const config = {
        panelId: 'calendar',
        storageKey: 'prostvor_calendar_events',
        months: [
            'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
            'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
        ],
        daysOfWeek: ['Пн.', 'Вт.', 'Ср.', 'Чт.', 'Пт.', 'Сб.', 'Вс.']
    };

    // Текущее состояние
    let currentState = {
        view: 'week', // 'year', 'month', 'week', 'day'
        currentDate: new Date(),
        events: []
    };

    // Инициализация
    function init() {
        try {
            loadEvents();
            render();
            setupEventListeners();
        } catch (error) {
            console.error('Ошибка инициализации календаря:', error);
        }
    }

    // Загрузка событий
    function loadEvents() {
        try {
            const events = localStorage.getItem(config.storageKey);
            currentState.events = events ? JSON.parse(events) : [];
        } catch (error) {
            console.error('Ошибка загрузки событий:', error);
            currentState.events = [];
        }
    }

    // Сохранение событий
    function saveEvents() {
        try {
            localStorage.setItem(config.storageKey, JSON.stringify(currentState.events));
        } catch (error) {
            console.error('Ошибка сохранения событий:', error);
        }
    }

    // Рендер календаря
    function render() {
        const panel = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-body`);
        if (!panel) return;

        let content = '';
        
        switch (currentState.view) {
            case 'year':
                content = renderYearView();
                break;
            case 'month':
                content = renderMonthView();
                break;
            case 'week':
                content = renderWeekView();
                break;
            case 'day':
                content = renderDayView();
                break;
        }

        panel.innerHTML = content;
        updateHeader();
    }

    // Рендер годового вида
    function renderYearView() {
        const year = currentState.currentDate.getFullYear();
        let html = '<div class="year-view">';
        
        for (let month = 0; month < 12; month++) {
            const monthName = config.months[month];
            const daysInMonth = new Date(year, month + 1, 0).getDate();
            const firstDay = new Date(year, month, 1).getDay();
            
            html += `
                <div class="month-container">
                    <div class="month-header">${monthName}</div>
                    <div class="month-days">
                        ${config.daysOfWeek.map(day => `<div class="day-header">${day}</div>`).join('')}
            `;
            
            // Пустые ячейки до первого дня
            for (let i = 0; i < (firstDay === 0 ? 6 : firstDay - 1); i++) {
                html += '<div class="day-empty"></div>';
            }
            
            // Дни месяца
            for (let day = 1; day <= daysInMonth; day++) {
                const hasEvent = hasEventOnDate(year, month + 1, day);
                const dayClass = hasEvent ? 'day-with-event' : 'day';
                html += `<div class="${dayClass}">${day}</div>`;
            }
            
            html += '</div></div>';
        }
        
        html += '</div>';
        return html;
    }

    // Рендер месячного вида
    function renderMonthView() {
        const year = currentState.currentDate.getFullYear();
        const month = currentState.currentDate.getMonth();
        const monthName = config.months[month];
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const firstDay = new Date(year, month, 1).getDay();
        
        let html = `
            <div class="month-view">
                <div class="calendar-grid">
                    ${config.daysOfWeek.map(day => `<div class="day-header">${day}</div>`).join('')}
        `;
        
        // Пустые ячейки до первого дня
        for (let i = 0; i < (firstDay === 0 ? 6 : firstDay - 1); i++) {
            html += '<div class="day-empty"></div>';
        }
        
        // Дни месяца
        for (let day = 1; day <= daysInMonth; day++) {
            const hasEvent = hasEventOnDate(year, month + 1, day);
            const dayClass = hasEvent ? 'day-with-event' : 'day';
            const events = getEventsOnDate(year, month + 1, day);
            
            html += `
                <div class="${dayClass}">
                    <div class="day-number">${day}</div>
                    ${events.length > 0 ? `<div class="event-indicator">${events.length}</div>` : ''}
                </div>
            `;
        }
        
        html += '</div></div>';
        return html;
    }

    // Рендер недельного вида
    function renderWeekView() {
        const weekDates = getWeekDates(currentState.currentDate);
        const eventsByDate = {};
        
        // Собираем события по датам
        weekDates.forEach(date => {
            const dateStr = date.toISOString().split('T')[0];
            eventsByDate[dateStr] = getEventsOnDate(date.getFullYear(), date.getMonth() + 1, date.getDate());
        });
        
        // Находим максимальное количество событий в один день
        let maxEvents = 2; // Минимум 2 строки
        Object.values(eventsByDate).forEach(events => {
            if (events.length > maxEvents) {
                maxEvents = events.length;
            }
        });
        
        let html = `
            <div class="week-view">
                <div class="week-grid" style="grid-template-rows: repeat(${maxEvents + 1}, 1fr);">
                    <!-- Заголовки дней -->
                    <div class="date-cell">Дата</div>
                    <div class="day-name-cell">День</div>
        `;
        
        // Добавляем ячейки для событий
        for (let i = 0; i < maxEvents; i++) {
            html += `<div class="event-cell-header">Событие ${i + 1}</div>`;
        }
        
        // Добавляем данные для каждого дня недели
        weekDates.forEach(date => {
            const dateStr = date.toISOString().split('T')[0];
            const dayNum = date.getDate();
            const dayName = config.daysOfWeek[date.getDay() === 0 ? 6 : date.getDay() - 1];
            const events = eventsByDate[dateStr] || [];
            
            // Дата
            html += `<div class="date-cell" style="color: #6AD7FF;">${dayNum}</div>`;
            
            // День недели
            const dayColor = date.getDay() === 6 || date.getDay() === 0 ? '#D58882' : '#D3F971';
            html += `<div class="day-name-cell" style="color: ${dayColor};">${dayName}</div>`;
            
            // События
            for (let i = 0; i < maxEvents; i++) {
                if (events[i]) {
                    html += `
                        <div class="event-cell">
                            <span class="event-time">${events[i].time}</span>
                            <span class="event-text">${events[i].text}</span>
                        </div>
                    `;
                } else {
                    html += '<div class="event-cell empty"></div>';
                }
            }
        });
        
        html += '</div></div>';
        return html;
    }

    // Рендер дневного вида
    function renderDayView() {
        const date = currentState.currentDate;
        const dateStr = date.toISOString().split('T')[0];
        const events = getEventsOnDate(date.getFullYear(), date.getMonth() + 1, date.getDate());
        
        let html = `
            <div class="day-view">
                <div class="day-header">
                    <h3>${date.getDate()} ${config.months[date.getMonth()]} ${date.getFullYear()}</h3>
                </div>
                <div class="events-list">
        `;
        
        if (events.length === 0) {
            html += '<div class="no-events">Событий на этот день нет</div>';
        } else {
            events.forEach(event => {
                html += `
                    <div class="event-item">
                        <span class="event-time">${event.time}</span>
                        <span class="event-text">${event.text}</span>
                    </div>
                `;
            });
        }
        
        html += '</div></div>';
        return html;
    }

    // Обновление заголовка
    function updateHeader() {
        const header = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-header h3`);
        if (!header) return;
        
        const date = currentState.currentDate;
        const year = date.getFullYear();
        const month = config.months[date.getMonth()];
        
        header.innerHTML = `
            <span class="year-display">${year}</span>
            <span class="month-display">${month}</span>
            <div class="view-switcher">
                <span class="view-option ${currentState.view === 'year' ? 'active' : ''}" data-view="year">год</span>
                <span class="view-option ${currentState.view === 'month' ? 'active' : ''}" data-view="month">месяц</span>
                <span class="view-option ${currentState.view === 'week' ? 'active' : ''}" data-view="week">неделя</span>
                <span class="view-option ${currentState.view === 'day' ? 'active' : ''}" data-view="day">день</span>
            </div>
        `;
    }

    // Получение дат недели
    function getWeekDates(date) {
        const currentDate = new Date(date);
        const currentDay = currentDate.getDay();
        const startDate = new Date(currentDate);
        
        // Начинаем с понедельника
        startDate.setDate(currentDate.getDate() - (currentDay === 0 ? 6 : currentDay - 1));
        
        const weekDates = [];
        for (let i = 0; i < 7; i++) {
            const day = new Date(startDate);
            day.setDate(startDate.getDate() + i);
            weekDates.push(day);
        }
        
        return weekDates;
    }

    // Проверка наличия события на дату
    function hasEventOnDate(year, month, day) {
        return currentState.events.some(event => {
            const eventDate = new Date(event.date);
            return eventDate.getFullYear() === year && 
                   eventDate.getMonth() + 1 === month && 
                   eventDate.getDate() === day;
        });
    }

    // Получение событий на дату
    function getEventsOnDate(year, month, day) {
        return currentState.events
            .filter(event => {
                const eventDate = new Date(event.date);
                return eventDate.getFullYear() === year && 
                       eventDate.getMonth() + 1 === month && 
                       eventDate.getDate() === day;
            })
            .map(event => ({
                time: event.time,
                text: event.text
            }));
    }

    // Добавление события
    function addEvent(eventData) {
        try {
            const newEvent = {
                id: Date.now(),
                date: eventData.date,
                time: eventData.time || '00:00-00:00',
                text: eventData.text,
                created: new Date().toISOString()
            };
            
            currentState.events.push(newEvent);
            saveEvents();
            render();
            
            return newEvent;
        } catch (error) {
            console.error('Ошибка добавления события:', error);
            throw error;
        }
    }

    // Настройка обработчиков событий
    function setupEventListeners() {
        // Переключение вида
        document.addEventListener('click', function(e) {
            if (e.target.classList.contains('view-option')) {
                const view = e.target.dataset.view;
                currentState.view = view;
                render();
                e.preventDefault();
            }
        });
        
        // Кнопка добавления события
        const panel = document.querySelector(`.panel-content[data-panel="${config.panelId}"]`);
        if (panel) {
            const addButton = document.createElement('button');
            addButton.className = 'add-event-button';
            addButton.innerHTML = '+';
            addButton.style.position = 'absolute';
            addButton.style.bottom = '10px';
            addButton.style.right = '10px';
            addButton.style.backgroundColor = '#92D050';
            addButton.style.color = 'white';
            addButton.style.border = 'none';
            addButton.style.borderRadius = '50%';
            addButton.style.width = '40px';
            addButton.style.height = '40px';
            addButton.style.fontSize = '24px';
            addButton.style.cursor = 'pointer';
            
            addButton.addEventListener('click', showAddEventForm);
            panel.appendChild(addButton);
        }
    }

    // Показать форму добавления события
    function showAddEventForm() {
        const date = currentState.currentDate;
        const dateStr = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
        
        const formHtml = `
            <div class="event-form-overlay">
                <div class="event-form">
                    <h3>Добавить событие</h3>
                    <div class="form-group">
                        <label>Дата:</label>
                        <input type="date" id="eventDate" value="${dateStr}">
                    </div>
                    <div class="form-group">
                        <label>Время:</label>
                        <input type="text" id="eventTime" value="00:00-00:00" placeholder="00:00-00:00">
                    </div>
                    <div class="form-group">
                        <label>Текст события:</label>
                        <textarea id="eventText" rows="3"></textarea>
                    </div>
                    <div class="form-buttons">
                        <button class="cancel-btn">Отмена</button>
                        <button class="save-btn">Сохранить</button>
                    </div>
                </div>
            </div>
        `;
        
        const formContainer = document.createElement('div');
        formContainer.innerHTML = formHtml;
        document.body.appendChild(formContainer);
        
        // Обработчики для формы
        formContainer.querySelector('.cancel-btn').addEventListener('click', () => {
            formContainer.remove();
        });
        
        formContainer.querySelector('.save-btn').addEventListener('click', () => {
            const date = document.getElementById('eventDate').value;
            const time = document.getElementById('eventTime').value;
            const text = document.getElementById('eventText').value;
            
            if (!text.trim()) {
                alert('Введите текст события');
                return;
            }
            
            addEvent({ date, time, text });
            formContainer.remove();
        });
    }

    // Публичные методы
    return {
        init: init,
        addEvent: addEvent,
        getEvents: function() { return currentState.events; },
        setDate: function(date) {
            currentState.currentDate = new Date(date);
            render();
        }
    };
})();