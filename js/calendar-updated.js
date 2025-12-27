// calendar-updated.js - Полностью переработанный модуль календаря
const CalendarUpdated = (function() {
    // Конфигурация
    const config = {
        panelId: 'calendar',
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
        currentYear: new Date().getFullYear(),
        currentMonth: new Date().getMonth() + 1,
        currentDate: new Date(),
        editingYear: false,
        editingMonth: false
    };

    // Инициализация
    function init() {
        try {
            // Инициализируем базу данных
            if (typeof CalendarBase !== 'undefined') {
                CalendarBase.init();
            }
            
            const panel = document.querySelector(`.panel-content[data-panel="${config.panelId}"]`);
            if (panel) {
                render();
                setupEventListeners();
                updateCounter();
                console.log('Календарь инициализирован');
            } else {
                console.warn('Панель календаря не найдена');
                setTimeout(() => {
                    const panel = document.querySelector(`.panel-content[data-panel="${config.panelId}"]`);
                    if (panel) {
                        render();
                        setupEventListeners();
                        updateCounter();
                    }
                }, 500);
            }
        } catch (error) {
            console.error('Ошибка инициализации календаря:', error);
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
        
        // Заголовок (без индикатора)
        content += `
            <div class="calendar-header-row">
                <span class="current-year" id="currentYear">&lt;${currentState.currentYear}&gt;</span>
                <span class="current-month" id="currentMonth">${config.months[currentState.currentMonth - 1]}</span>
                <div class="calendar-view-switcher">
                    <span class="view-option ${currentState.view === 'year' ? 'active' : ''}" data-view="year">год</span>
                    <span class="view-option ${currentState.view === 'month' ? 'active' : ''}" data-view="month">месяц</span>
                    <span class="view-option ${currentState.view === 'week' ? 'active' : ''}" data-view="week">неделя</span>
                    <span class="view-option ${currentState.view === 'day' ? 'active' : ''}" data-view="day">день</span>
                </div>
            </div>
        `;
        
        // Контент в зависимости от вида
        switch (currentState.view) {
            case 'year':
                content += renderYearView();
                break;
            case 'month':
                content += renderMonthView();
                break;
            case 'week':
                content += renderWeekView();
                break;
            case 'day':
                content += renderDayView();
                break;
        }

        panel.innerHTML = content;
        
        // Добавляем индикаторы прокрутки
        addScrollIndicators();
        
        // Добавляем кнопку "+"
        addAddButton();
        
        // Обновляем индикаторы прокрутки
        updateScrollIndicators();
    }

    // Рендер годового вида
    function renderYearView() {
        let html = '<div class="year-view-container">';
        
        for (let month = 1; month <= 12; month++) {
            const monthName = config.months[month - 1];
            const daysInMonth = new Date(currentState.currentYear, month, 0).getDate();
            const firstDay = new Date(currentState.currentYear, month - 1, 1).getDay();
            const startOffset = firstDay === 0 ? 6 : firstDay - 1;
            
            // Получаем события для этого месяца
            const monthEvents = getMonthEvents(currentState.currentYear, month);
            const daysWithEvents = new Set();
            monthEvents.forEach(event => {
                const eventDate = new Date(event.startDate);
                if (eventDate.getMonth() + 1 === month) {
                    daysWithEvents.add(eventDate.getDate());
                }
            });
            
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
                const hasEvent = daysWithEvents.has(day);
                const dayClass = hasEvent ? 'day-with-event' : 'day-cell';
                html += `<div class="${dayClass}" data-date="${currentState.currentYear}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}">${day}</div>`;
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
        const year = currentState.currentYear;
        const month = currentState.currentMonth;
        const monthName = config.months[month - 1];
        const daysInMonth = new Date(year, month, 0).getDate();
        const firstDay = new Date(year, month - 1, 1).getDay();
        const startOffset = firstDay === 0 ? 6 : firstDay - 1;
        
        // Получаем события для этого месяца
        const monthEvents = getMonthEvents(year, month);
        const eventsByDay = {};
        monthEvents.forEach(event => {
            const eventDate = new Date(event.startDate);
            const day = eventDate.getDate();
            if (!eventsByDay[day]) eventsByDay[day] = [];
            eventsByDay[day].push(event);
        });
        
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
            const hasEvent = eventsByDay[day] && eventsByDay[day].length > 0;
            const dayClass = hasEvent ? 'day-with-event-large' : 'day-large';
            const eventsCount = hasEvent ? eventsByDay[day].length : 0;
            
            html += `
                <div class="${dayClass}" data-date="${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}">
                    <div class="day-number">${day}</div>
                    ${eventsCount > 0 ? 
                        `<div class="events-count">${eventsCount}</div>` : 
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
        
        // Получаем события для всей недели
        const eventsByDate = {};
        const maxRowsPerDay = {};
        
        weekDates.forEach(date => {
            const dateStr = date.toISOString().split('T')[0];
            const events = getDayEvents(dateStr);
            eventsByDate[dateStr] = events;
            maxRowsPerDay[dateStr] = Math.max(events.length, 2); // Минимум 2 строки
        });
        
        // Находим максимальное количество строк в неделе
        let totalMaxRows = 0;
        Object.values(maxRowsPerDay).forEach(count => {
            totalMaxRows = Math.max(totalMaxRows, count);
        });
        
        let html = '<div class="week-view-container">';
        
        // Создаем строки
        for (let row = 0; row < totalMaxRows; row++) {
            html += '<div class="week-day-row">';
            
            weekDates.forEach((date, dayIndex) => {
                const dateStr = date.toISOString().split('T')[0];
                const events = eventsByDate[dateStr] || [];
                
                // Для первой строки показываем дату и день недели
                if (row === 0) {
                    // Дата
                    html += `<div class="date-cell-week">${date.getDate()}</div>`;
                    
                    // День недели
                    const dayIdx = date.getDay() === 0 ? 6 : date.getDay() - 1;
                    const dayName = config.daysOfWeekShort[dayIdx];
                    const dayClass = date.getDay() === 0 || date.getDay() === 6 ? 
                        'weekend' : 'weekday';
                    html += `<div class="day-name-cell-week ${dayClass}">${dayName}</div>`;
                } else {
                    // Для остальных строк оставляем пустые ячейки
                    html += '<div class="date-cell-week"></div>';
                    html += '<div class="day-name-cell-week"></div>';
                }
                
                // Событие для этой строки
                if (events[row]) {
                    const event = events[row];
                    html += `
                        <div class="events-cell-week">
                            <div class="event-row-week">
                                <span class="event-time-week">${event.startTime}-${event.endTime}</span>
                                <span class="event-text-week">${event.title}</span>
                            </div>
                        </div>
                    `;
                } else {
                    html += '<div class="events-cell-week"><div class="empty-row-week"></div></div>';
                }
            });
            
            html += '</div>';
        }
        
        html += '</div>';
        return html;
    }

    // Рендер дневного вида
    function renderDayView() {
        const date = currentState.currentDate;
        const dayNum = date.getDate();
        const dayIndex = date.getDay() === 0 ? 6 : date.getDay() - 1;
        const dayName = config.daysOfWeekShort[dayIndex];
        const dateStr = date.toISOString().split('T')[0];
        
        // Получаем события на этот день
        const dayEvents = getDayEvents(dateStr);
        
        let html = `
            <div class="day-view-container">
                <div class="day-header-combined">
                    <div class="day-number-day">${dayNum}</div>
                    <div class="day-name-day">${dayName}</div>
                </div>
                <div class="events-list-day">
        `;
        
        if (dayEvents.length === 0) {
            // Добавляем пустые строки для заполнения
            for (let i = 0; i < 5; i++) {
                html += '<div class="event-item-day empty"></div>';
            }
        } else {
            // Группируем события по часам
            const timeSlots = ['00:00-06:00', '06:00-12:00', '12:00-18:00', '18:00-24:00'];
            
            timeSlots.forEach(slot => {
                const [startTime] = slot.split('-');
                const slotEvents = dayEvents.filter(event => {
                    const eventStart = event.startTime.substring(0, 2);
                    return parseInt(eventStart) >= parseInt(startTime) && 
                           parseInt(eventStart) < parseInt(startTime) + 6;
                });
                
                if (slotEvents.length > 0) {
                    slotEvents.forEach(event => {
                        html += `
                            <div class="event-item-day">
                                <span class="event-time-day">${event.startTime}-${event.endTime}</span>
                                <span class="event-text-day">${event.title}</span>
                            </div>
                        `;
                    });
                } else if (dayEvents.length < 3) {
                    // Добавляем пустую строку только если мало событий
                    html += '<div class="event-item-day empty"></div>';
                }
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

    // Получение событий на день
    function getDayEvents(dateStr) {
        try {
            if (typeof CalendarBase !== 'undefined') {
                const userId = getCurrentUserId();
                if (userId) {
                    return CalendarBase.getEventsByDate(userId, dateStr);
                }
            }
        } catch (error) {
            console.error('Ошибка получения событий на день:', error);
        }
        return [];
    }

    // Получение событий на месяц
    function getMonthEvents(year, month) {
        try {
            if (typeof CalendarBase !== 'undefined') {
                const userId = getCurrentUserId();
                if (userId) {
                    return CalendarBase.getMonthEvents(userId, year, month);
                }
            }
        } catch (error) {
            console.error('Ошибка получения событий на месяц:', error);
        }
        return [];
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

    // Настройка обработчиков событий
    function setupEventListeners() {
        // Используем делегирование событий на всем документе
        document.addEventListener('click', handleCalendarClick);
        
        // Обработка прокрутки
        const panelBody = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-body`);
        if (panelBody) {
            panelBody.addEventListener('scroll', updateScrollIndicators);
        }
    }

    // Вынесите обработчик в отдельную функцию
    function handleCalendarClick(e) {
        // Проверяем, кликнули ли мы по переключателю вида
        const viewOption = e.target.closest('.view-option');
        if (viewOption && viewOption.dataset.view) {
            e.preventDefault();
            e.stopPropagation();
            
            const view = viewOption.dataset.view;
            console.log('Переключение вида на:', view);
            
            if (['year', 'month', 'week', 'day'].includes(view)) {
                currentState.view = view;
                render();
            }
            return;
        }
        
        // Остальные обработчики...
        if (e.target.id === 'currentYear') {
            showYearSelector();
        } else if (e.target.id === 'currentMonth') {
            showMonthSelector();
        } else if (e.target.classList.contains('day-cell') || 
                   e.target.classList.contains('day-with-event') ||
                   e.target.classList.contains('day-large') ||
                   e.target.classList.contains('day-with-event-large')) {
            const dateStr = e.target.getAttribute('data-date');
            if (dateStr) {
                showAddEventForm(dateStr);
            }
        }
    }
    
    function refreshCalendar() {
        const panel = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-body`);
        if (panel) {
            render();
            setupEventListeners();
        }
    }

    // Показать селектор года
    function showYearSelector() {
        const currentYear = currentState.currentYear;
        const years = [];
        
        // Годы от -10 до +10 от текущего
        for (let i = currentYear - 10; i <= currentYear + 10; i++) {
            years.push(i);
        }
        
        const selectorHtml = `
            <div class="year-month-selector">
                <div class="year-month-selector-content">
                    <h3>Выберите год</h3>
                    <div class="selector-grid">
                        ${years.map(year => `
                            <div class="selector-item ${year === currentYear ? 'selected' : ''}" data-value="${year}">
                                &lt;${year}&gt;
                            </div>
                        `).join('')}
                    </div>
                    <div class="selector-buttons">
                        <button class="selector-cancel">Отмена</button>
                        <button class="selector-apply">Применить</button>
                    </div>
                </div>
            </div>
        `;
        
        const selectorContainer = document.createElement('div');
        selectorContainer.innerHTML = selectorHtml;
        document.body.appendChild(selectorContainer);
        
        // Обработчики для селектора
        selectorContainer.querySelectorAll('.selector-item').forEach(item => {
            item.addEventListener('click', function() {
                selectorContainer.querySelectorAll('.selector-item').forEach(i => i.classList.remove('selected'));
                this.classList.add('selected');
            });
        });
        
        selectorContainer.querySelector('.selector-cancel').addEventListener('click', () => {
            selectorContainer.remove();
        });
        
        selectorContainer.querySelector('.selector-apply').addEventListener('click', () => {
            const selectedItem = selectorContainer.querySelector('.selector-item.selected');
            if (selectedItem) {
                const newYear = parseInt(selectedItem.getAttribute('data-value'));
                currentState.currentYear = newYear;
                render();
            }
            selectorContainer.remove();
        });
        
        // Закрытие при клике вне
        selectorContainer.querySelector('.year-month-selector').addEventListener('click', (e) => {
            if (e.target === selectorContainer.querySelector('.year-month-selector')) {
                selectorContainer.remove();
            }
        });
    }

    // Показать селектор месяца
    function showMonthSelector() {
        const currentMonth = currentState.currentMonth;
        
        const selectorHtml = `
            <div class="year-month-selector">
                <div class="year-month-selector-content">
                    <h3>Выберите месяц</h3>
                    <div class="selector-grid">
                        ${config.months.map((month, index) => `
                            <div class="selector-item ${index + 1 === currentMonth ? 'selected' : ''}" data-value="${index + 1}">
                                ${month}
                            </div>
                        `).join('')}
                    </div>
                    <div class="selector-buttons">
                        <button class="selector-cancel">Отмена</button>
                        <button class="selector-apply">Применить</button>
                    </div>
                </div>
            </div>
        `;
        
        const selectorContainer = document.createElement('div');
        selectorContainer.innerHTML = selectorHtml;
        document.body.appendChild(selectorContainer);
        
        // Обработчики для селектора
        selectorContainer.querySelectorAll('.selector-item').forEach(item => {
            item.addEventListener('click', function() {
                selectorContainer.querySelectorAll('.selector-item').forEach(i => i.classList.remove('selected'));
                this.classList.add('selected');
            });
        });
        
        selectorContainer.querySelector('.selector-cancel').addEventListener('click', () => {
            selectorContainer.remove();
        });
        
        selectorContainer.querySelector('.selector-apply').addEventListener('click', () => {
            const selectedItem = selectorContainer.querySelector('.selector-item.selected');
            if (selectedItem) {
                const newMonth = parseInt(selectedItem.getAttribute('data-value'));
                currentState.currentMonth = newMonth;
                render();
            }
            selectorContainer.remove();
        });
        
        // Закрытие при клике вне
        selectorContainer.querySelector('.year-month-selector').addEventListener('click', (e) => {
            if (e.target === selectorContainer.querySelector('.year-month-selector')) {
                selectorContainer.remove();
            }
        });
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
        scrollTop.innerHTML = '▲';
        
        const scrollBottom = document.createElement('div');
        scrollBottom.className = 'scroll-indicator bottom';
        scrollBottom.innerHTML = '▼';
        
        panelBody.insertBefore(scrollTop, panelBody.firstChild);
        panelBody.appendChild(scrollBottom);
        
        // Обновляем индикаторы
        updateScrollIndicators();
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

    // Добавление кнопки "+"
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
        
        addButton.addEventListener('click', () => {
            const today = new Date();
            const dateStr = today.toISOString().split('T')[0];
            showAddEventForm(dateStr);
        });
        
        panelContent.appendChild(addButton);
    }

    // Показать форму добавления события
    function showAddEventForm(dateStr) {
        const date = new Date(dateStr);
        const year = date.getFullYear();
        const month = config.months[date.getMonth()];
        const day = date.getDate();
        
        const formHtml = `
            <div class="event-form-overlay">
                <div class="event-form">
                    <h3>Добавить событие</h3>
                    <div class="form-group">
                        <label>Год:</label>
                        <input type="text" id="eventYear" value="&lt;${year}&gt;" readonly>
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
                        <label>Время начала:</label>
                        <input type="time" id="eventStartTime" value="09:00">
                    </div>
                    <div class="form-group">
                        <label>Время окончания:</label>
                        <input type="time" id="eventEndTime" value="10:00">
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
            const startTime = document.getElementById('eventStartTime').value;
            const endTime = document.getElementById('eventEndTime').value;
            const text = document.getElementById('eventText').value;
            
            if (!text.trim()) {
                alert('Введите текст события');
                return;
            }
            
            if (startTime >= endTime) {
                alert('Время окончания должно быть позже времени начала');
                return;
            }
            
            addEvent({ 
                date: date,
                startTime: startTime,
                endTime: endTime,
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

    // Добавление события
    function addEvent(eventData) {
        try {
            if (typeof CalendarBase !== 'undefined') {
                const userId = getCurrentUserId();
                if (userId) {
                    const newEvent = CalendarBase.createEvent(userId, {
                        title: eventData.text,
                        startDate: eventData.date,
                        endDate: eventData.date,
                        startTime: eventData.startTime,
                        endTime: eventData.endTime,
                        allDay: false
                    });
                    
                    render();
                    updateCounter();
                    return newEvent;
                }
            }
        } catch (error) {
            console.error('Ошибка добавления события:', error);
            showNotification('Ошибка при добавлении события', 'error');
        }
        return null;
    }

    // Обновление счетчика
    function updateCounter() {
        try {
            if (typeof CalendarBase !== 'undefined') {
                const userId = getCurrentUserId();
                if (userId) {
                    const events = CalendarBase.getUserEvents(userId);
                    const count = events.length;
                    
                    const counterElement = document.getElementById(`${config.panelId}Count`);
                    const labelElement = document.querySelector(`.panel-label[data-panel="${config.panelId}"]`);
                    
                    if (counterElement) counterElement.textContent = count;
                    if (labelElement) labelElement.setAttribute('data-count', count);
                    
                    // Сохраняем в localStorage
                    localStorage.setItem(`panel_${config.panelId}_count`, count);
                }
            }
        } catch (error) {
            console.error('Ошибка обновления счетчика:', error);
        }
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
        setDate: function(date) {
            currentState.currentDate = new Date(date);
            render();
        },
        updateCounter: updateCounter,
        refresh: refreshCalendar  // Добавьте этот метод
    };
})();