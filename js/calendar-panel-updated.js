// Модуль календаря
const CalendarPanelUpdated = (function() {
    // Конфигурация
    const config = {
        panelId: 'calendar',
        storageKey: 'prostvor_calendar_events_updated',
        months: [
            'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
            'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
        ],
        daysOfWeekShort: ['Пн.', 'Вт.', 'Ср', 'Чт', 'Пт.', 'Сб', 'Вс.'],
        colors: {
            weekday: '#D3F971',
            weekend: '#D58882',
            date: '#6AD7FF'
        }
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
            const panel = document.querySelector(`.panel-content[data-panel="${config.panelId}"]`);
            if (panel) {
                render();
                setupEventListeners();
            } else {
                console.warn('Панель календаря не найдена');
                setTimeout(checkPanel, 500);
            }
        } catch (error) {
            console.error('Ошибка инициализации календаря:', error);
        }
    }

    function checkPanel() {
        const panel = document.querySelector(`.panel-content[data-panel="${config.panelId}"]`);
        if (panel) {
            render();
            setupEventListeners();
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
            updateCounter();
        } catch (error) {
            console.error('Ошибка сохранения событий:', error);
        }
    }

    // Рендер календаря
    function render() {
        const panel = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-body`);
        if (!panel) {
            console.error('Тело панели календаря не найдено!');
            return;
        }

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
        addScrollIndicators();
        addAddButton();
        updateScrollIndicators();
    }

    // Обновление заголовка
    function updateHeader() {
        const header = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-header h3`);
        if (!header) return;
        
        const date = currentState.currentDate;
        const year = date.getFullYear();
        const month = config.months[date.getMonth()];
        
        header.innerHTML = `
            <div class="calendar-header-row">
                <span class="current-year"><${year}></span>
                <span class="current-month">${month}</span>
                <div class="calendar-view-switcher">
                    <span class="view-option ${currentState.view === 'year' ? 'active' : ''}" data-view="year">год</span>
                    <span class="view-option ${currentState.view === 'month' ? 'active' : ''}" data-view="month">месяц</span>
                    <span class="view-option ${currentState.view === 'week' ? 'active' : ''}" data-view="week">неделя</span>
                    <span class="view-option ${currentState.view === 'day' ? 'active' : ''}" data-view="day">день</span>
                    <div class="active-indicator" id="calendarActiveIndicator"></div>
                </div>
            </div>
        `;
        
        // Обновляем позицию активного индикатора
        setTimeout(() => {
            updateCalendarActiveIndicator();
        }, 100);
    }

    // Обновление позиции активного индикатора
    function updateCalendarActiveIndicator() {
        const indicator = document.getElementById('calendarActiveIndicator');
        const activeOption = document.querySelector('.calendar-view-switcher .view-option.active');
        
        if (indicator && activeOption) {
            const optionRect = activeOption.getBoundingClientRect();
            const switcherRect = activeOption.parentElement.getBoundingClientRect();
            
            indicator.style.left = (optionRect.left - switcherRect.left) + 'px';
            indicator.style.width = optionRect.width + 'px';
        }
    }

    // Рендер годового вида
    function renderYearView() {
        const year = currentState.currentDate.getFullYear();
        let html = '<div class="year-view-container">';
        
        for (let month = 0; month < 12; month++) {
            const monthName = config.months[month];
            const daysInMonth = new Date(year, month + 1, 0).getDate();
            const firstDay = new Date(year, month, 1).getDay();
            const startOffset = firstDay === 0 ? 6 : firstDay - 1;
            
            html += `
                <div class="month-block">
                    <div class="month-header">${monthName}</div>
                    <div class="month-grid">
                        ${config.daysOfWeekShort.map(day => `<div class="day-header">${day}</div>`).join('')}
            `;
            
            // Пустые ячейки до первого дня
            for (let i = 0; i < startOffset; i++) {
                html += '<div class="day-empty"></div>';
            }
            
            // Дни месяца
            for (let day = 1; day <= daysInMonth; day++) {
                const hasEvent = hasEventOnDate(year, month + 1, day);
                const dayClass = hasEvent ? 'day-with-event' : 'day';
                html += `<div class="${dayClass}">${day}</div>`;
            }
            
            // Пустые ячейки до конца сетки
            const totalCells = startOffset + daysInMonth;
            const remainingCells = Math.ceil(totalCells / 7) * 7 - totalCells;
            for (let i = 0; i < remainingCells; i++) {
                html += '<div class="day-empty"></div>';
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
        const startOffset = firstDay === 0 ? 6 : firstDay - 1;
        
        let html = `
            <div class="month-view-container">
                <div class="month-grid-large">
                    ${config.daysOfWeekShort.map(day => `<div class="day-header-large">${day}</div>`).join('')}
        `;
        
        // Пустые ячейки до первого дня
        for (let i = 0; i < startOffset; i++) {
            html += '<div class="day-empty-large"></div>';
        }
        
        // Дни месяца
        for (let day = 1; day <= daysInMonth; day++) {
            const hasEvent = hasEventOnDate(year, month + 1, day);
            const dayClass = hasEvent ? 'day-with-event-large' : 'day-large';
            const events = getEventsOnDate(year, month + 1, day);
            
            html += `
                <div class="${dayClass}">
                    <div class="day-number">${day}</div>
                    ${events.length > 0 ? 
                        `<div class="events-count">${events.length}</div>` : 
                        ''}
                </div>
            `;
        }
        
        // Пустые ячейки до конца сетки
        const totalCells = startOffset + daysInMonth;
        const remainingCells = Math.ceil(totalCells / 7) * 7 - totalCells;
        for (let i = 0; i < remainingCells; i++) {
            html += '<div class="day-empty-large"></div>';
        }
        
        html += '</div></div>';
        return html;
    }

    // Рендер недельного вида
    function renderWeekView() {
        const weekDates = getWeekDates(currentState.currentDate);
        const eventsByDate = {};
        const maxEventsPerDay = {};
        
        // Собираем события по датам
        weekDates.forEach(date => {
            const dateStr = date.toISOString().split('T')[0];
            const events = getEventsOnDate(date.getFullYear(), date.getMonth() + 1, date.getDate());
            eventsByDate[dateStr] = events;
            maxEventsPerDay[dateStr] = Math.max(events.length, 2); // Минимум 2 строки
        });
        
        // Находим общее максимальное количество строк
        let totalMaxRows = 0;
        Object.values(maxEventsPerDay).forEach(count => {
            totalMaxRows = Math.max(totalMaxRows, count);
        });
        
        let html = `
            <div class="week-view-container">
                <div class="week-grid" style="grid-template-rows: repeat(${totalMaxRows}, 1fr);">
                    <!-- Столбец с датами -->
                    <div class="dates-column">
        `;
        
        // Добавляем даты
        weekDates.forEach(date => {
            const dayNum = date.getDate();
            html += `<div class="date-cell">${dayNum}</div>`;
        });
        
        html += `
                    </div>
                    
                    <!-- Столбец с днями недели -->
                    <div class="days-column">
        `;
        
        // Добавляем дни недели
        weekDates.forEach(date => {
            const dayIndex = date.getDay() === 0 ? 6 : date.getDay() - 1;
            const dayName = config.daysOfWeekShort[dayIndex];
            const dayColor = date.getDay() === 0 || date.getDay() === 6 ? 
                config.colors.weekend : config.colors.weekday;
            html += `<div class="day-cell" style="color: ${dayColor};">${dayName}</div>`;
        });
        
        html += `
                    </div>
                    
                    <!-- События -->
                    <div class="events-grid">
        `;
        
        // Добавляем события для каждого дня
        for (let row = 0; row < totalMaxRows; row++) {
            weekDates.forEach(date => {
                const dateStr = date.toISOString().split('T')[0];
                const events = eventsByDate[dateStr] || [];
                
                if (events[row]) {
                    const event = events[row];
                    html += `
                        <div class="event-cell">
                            <span class="event-time">${event.time}</span>
                            <span class="event-text">${event.text}</span>
                        </div>
                    `;
                } else {
                    html += '<div class="event-cell empty"></div>';
                }
            });
        }
        
        html += '</div></div></div>';
        return html;
    }

    // Рендер дневного вида
    function renderDayView() {
        const date = currentState.currentDate;
        const dateStr = date.toISOString().split('T')[0];
        const events = getEventsOnDate(date.getFullYear(), date.getMonth() + 1, date.getDate());
        
        let html = `
            <div class="day-view-container">
                <div class="day-header-large">
                    ${date.getDate()} ${config.months[date.getMonth()]} ${date.getFullYear()}
                </div>
                <div class="events-list-day">
        `;
        
        if (events.length === 0) {
            html += '<div class="no-events-day">Событий на этот день нет</div>';
        } else {
            events.forEach(event => {
                html += `
                    <div class="event-item-day">
                        <span class="event-time-day">${event.time}</span>
                        <span class="event-text-day">${event.text}</span>
                    </div>
                `;
            });
        }
        
        html += '</div></div>';
        return html;
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
                text: event.text,
                id: event.id
            }));
    }

    // Добавление события
    function addEvent(eventData) {
        try {
            const newEvent = {
                id: Date.now().toString() + Math.random().toString(36).substr(2, 9),
                date: eventData.date,
                time: eventData.time || '00:00-00:00',
                text: eventData.text,
                created: new Date().toISOString(),
                userId: getCurrentUserId()
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

    // Получение ID текущего пользователя
    function getCurrentUserId() {
        try {
            const userData = sessionStorage.getItem('current_user');
            if (userData) {
                const user = JSON.parse(userData);
                return user.id;
            }
            return null;
        } catch {
            return null;
        }
    }

    // Добавление индикаторов прокрутки
    function addScrollIndicators() {
        const panelBody = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-body`);
        if (!panelBody) return;
        
        // Удаляем старые индикаторы
        const oldIndicators = panelBody.querySelectorAll('.scroll-indicator');
        oldIndicators.forEach(indicator => indicator.remove());
        
        const scrollTop = document.createElement('div');
        scrollTop.className = 'scroll-indicator top';
        scrollTop.innerHTML = '&#x25B2;'; // Стрелка вверх
        
        const scrollBottom = document.createElement('div');
        scrollBottom.className = 'scroll-indicator bottom';
        scrollBottom.innerHTML = '&#x25BC;'; // Стрелка вниз
        
        panelBody.insertBefore(scrollTop, panelBody.firstChild);
        panelBody.appendChild(scrollBottom);
    }

    // Добавление кнопки добавления
    function addAddButton() {
        const panelContent = document.querySelector(`.panel-content[data-panel="${config.panelId}"]`);
        if (!panelContent) return;
        
        // Удаляем старую кнопку если есть
        const oldButton = panelContent.querySelector('.add-event-button');
        if (oldButton) oldButton.remove();
        
        const addButton = document.createElement('button');
        addButton.className = 'add-event-button';
        addButton.innerHTML = '+';
        addButton.title = 'Добавить событие';
        addButton.style.backgroundColor = '#92D050';
        
        addButton.addEventListener('click', showAddEventForm);
        panelContent.appendChild(addButton);
    }

    // Показать форму добавления события
    function showAddEventForm() {
        const date = currentState.currentDate;
        const year = date.getFullYear();
        const month = config.months[date.getMonth()];
        const dateStr = `${year}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
        
        const formHtml = `
            <div class="event-form-overlay">
                <div class="event-form">
                    <h3>Добавить событие</h3>
                    <div class="form-group">
                        <label>Год:</label>
                        <input type="text" id="eventYear" value="${year}" readonly>
                    </div>
                    <div class="form-group">
                        <label>Месяц:</label>
                        <input type="text" id="eventMonth" value="${month}" readonly>
                    </div>
                    <div class="form-group">
                        <label>Дата:</label>
                        <input type="date" id="eventDate" value="${dateStr}">
                    </div>
                    <div class="form-group">
                        <label>Время события:</label>
                        <input type="text" id="eventTime" value="00:00-00:00" placeholder="00:00-00:00">
                    </div>
                    <div class="form-group">
                        <label>Текст события:</label>
                        <textarea id="eventText" rows="4" placeholder="Введите описание события"></textarea>
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
            
            addEvent({ 
                date: date, 
                time: time || '00:00-00:00', 
                text: text 
            });
            
            formContainer.remove();
            showNotification('Событие добавлено', 'success');
        });
        
        // Закрытие формы при клике вне её
        formContainer.querySelector('.event-form-overlay').addEventListener('click', (e) => {
            if (e.target === formContainer.querySelector('.event-form-overlay')) {
                formContainer.remove();
            }
        });
    }

    // Настройка обработчиков событий
    function setupEventListeners() {
        // Переключение вида
        document.addEventListener('click', function(e) {
            if (e.target.classList.contains('view-option')) {
                const view = e.target.dataset.view;
                currentState.view = view;
                render();
                updateCalendarActiveIndicator();
            }
        });
        
        // Обработка прокрутки
        const panelBody = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-body`);
        if (panelBody) {
            panelBody.addEventListener('scroll', updateScrollIndicators);
        }
    }

    // Обновление индикаторов прокрутки
    function updateScrollIndicators() {
        const panelBody = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-body`);
        if (!panelBody) return;
        
        const topIndicator = panelBody.querySelector('.scroll-indicator.top');
        const bottomIndicator = panelBody.querySelector('.scroll-indicator.bottom');
        
        if (topIndicator) {
            topIndicator.style.opacity = panelBody.scrollTop > 10 ? '1' : '0';
        }
        
        if (bottomIndicator) {
            const isAtBottom = panelBody.scrollHeight - panelBody.clientHeight - panelBody.scrollTop < 10;
            bottomIndicator.style.opacity = isAtBottom ? '0' : '1';
        }
    }

    // Обновление счетчика
    function updateCounter() {
        const count = currentState.events.length;
        const counterElement = document.getElementById(`${config.panelId}Count`);
        const labelElement = document.querySelector(`.panel-label[data-panel="${config.panelId}"]`);
        
        if (counterElement) counterElement.textContent = count;
        if (labelElement) labelElement.setAttribute('data-count', count);
        
        // Сохраняем в localStorage
        localStorage.setItem(`panel_${config.panelId}_count`, count);
    }

    // Показать уведомление
    function showNotification(message, type = 'info') {
        const notification = document.getElementById('notification');
        if (notification) {
            notification.textContent = message;
            notification.className = `notification ${type} show`;
            
            setTimeout(() => {
                notification.classList.remove('show');
            }, 3000);
        }
    }

    // Публичные методы
    return {
        init: init,
        addEvent: addEvent,
        getEvents: function() { return currentState.events; },
        setDate: function(date) {
            currentState.currentDate = new Date(date);
            render();
        },
        updateCounter: updateCounter
    };
})();