// tasks-panel-updated.js - Полностью обновленный модуль задач
const TasksPanelUpdated = (function() {
    const config = {
        panelId: 'tasks',
        storageKey: 'prostvor_tasks_base',
        columns: [
            { id: 'Планируется', title: 'Планируется', color: '#4C6070' },
            { id: 'В работе', title: 'В работе', color: '#4C6070' },
            { id: 'Приостановлено', title: 'Приостановлено', color: '#4C6070' },
            { id: 'Завершено', title: 'Завершено', color: '#4C6070' }
        ]
    };

    let currentState = {
        tasks: [],
        draggedTask: null,
        dragStartColumn: null
    };

    // Инициализация
    function init() {
        try {
            loadTasks();
            render();
            setupEventListeners();
            setupDragAndDrop();
            updateCounter();
            console.log('Панель задач инициализирована');
        } catch (error) {
            console.error('Ошибка инициализации задач:', error);
        }
    }

    // Загрузка задач из базы данных
    function loadTasks() {
        try {
            const tasks = localStorage.getItem(config.storageKey);
            currentState.tasks = tasks ? JSON.parse(tasks) : [];
            
            // Если нет задач, создаем демо данные для текущего пользователя
            if (currentState.tasks.length === 0) {
                createDemoTasks();
            }
        } catch (error) {
            console.error('Ошибка загрузки задач:', error);
            currentState.tasks = [];
        }
    }

    // Создание демо задач для текущего пользователя
    function createDemoTasks() {
        const currentUser = sessionStorage.getItem('current_user');
        if (!currentUser) return;

        try {
            const user = JSON.parse(currentUser);
            const userId = user.id;
            const today = new Date();
            
            const demoTasks = [
                {
                    id: generateTaskId(userId, 1),
                    userId: userId,
                    title: 'Подготовить презентацию',
                    description: 'Подготовить презентацию для встречи с клиентом',
                    regDate: today.toISOString(),
                    beginningDate: null,
                    endingDate: new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
                    status: 'Планируется',
                    priority: 'Высокий',
                    createdBy: userId,
                    assignee: userId,
                    tags: ['работа', 'презентация']
                },
                {
                    id: generateTaskId(userId, 2),
                    userId: userId,
                    title: 'Закончить отчет',
                    description: 'Завершить квартальный отчет',
                    regDate: today.toISOString(),
                    beginningDate: today.toISOString().split('T')[0],
                    endingDate: new Date(today.getTime() + 3 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
                    status: 'В работе',
                    priority: 'Средний',
                    createdBy: userId,
                    assignee: userId,
                    tags: ['работа', 'отчет']
                },
                {
                    id: generateTaskId(userId, 3),
                    userId: userId,
                    title: 'Обновить документацию',
                    description: 'Обновить техническую документацию проекта',
                    regDate: today.toISOString(),
                    beginningDate: new Date(today.getTime() - 2 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
                    endingDate: new Date(today.getTime() + 5 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
                    status: 'Приостановлено',
                    priority: 'Низкий',
                    createdBy: userId,
                    assignee: userId,
                    tags: ['документация', 'проект']
                }
            ];
            
            currentState.tasks = demoTasks;
            saveTasks();
        } catch (error) {
            console.error('Ошибка создания демо задач:', error);
        }
    }

    // Генерация ID задачи (ID участника + порядковый номер)
    function generateTaskId(userId, sequence) {
        const userPart = userId.toString().padStart(9, '0');
        const sequencePart = sequence.toString().padStart(3, '0');
        return `${userPart}-${sequencePart}`;
    }

    // Сохранение задач
    function saveTasks() {
        try {
            localStorage.setItem(config.storageKey, JSON.stringify(currentState.tasks));
            return true;
        } catch (error) {
            console.error('Ошибка сохранения задач:', error);
            return false;
        }
    }

    // Рендер панели задач
    function render() {
        const panel = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-body`);
        if (!panel) return;

        const html = `
            <div class="tasks-container-updated">
                <div class="tasks-columns-updated">
                    ${config.columns.map(column => renderColumn(column)).join('')}
                </div>
            </div>
        `;

        panel.innerHTML = html;
        addScrollIndicators();
        addAddButton();
    }

    // Рендер отдельного столбца
    function renderColumn(column) {
        const currentUser = sessionStorage.getItem('current_user');
        const userId = currentUser ? JSON.parse(currentUser).id : null;
        
        const tasks = currentState.tasks.filter(task => 
            task.status === column.id && 
            (task.userId === userId || task.assignee === userId)
        );
        
        return `
            <div class="tasks-column-updated" data-column="${column.id}">
                <div class="column-header-updated">
                    <h4>${column.title}</h4>
                    <span class="task-count-updated">${tasks.length}</span>
                </div>
                <div class="tasks-list-updated" data-column="${column.id}">
                    ${tasks.map(task => renderTask(task)).join('')}
                </div>
                ${column.id === 'Планируется' ? '<div class="add-task-area" data-column="Планируется"></div>' : ''}
            </div>
        `;
    }

    // Рендер отдельной задачи
    function renderTask(task) {
        const endDate = task.endingDate ? new Date(task.endingDate) : null;
        const dateStr = endDate ? 
            `${String(endDate.getDate()).padStart(2, '0')}.${String(endDate.getMonth() + 1).padStart(2, '0')}.${endDate.getFullYear()}` : 
            'Без срока';
        
        // Обрезаем текст если слишком длинный
        const maxLength = 60;
        const taskText = task.description || task.title;
        const displayText = taskText.length > maxLength ? 
            taskText.substring(0, maxLength) + '...' : 
            taskText;
        
        return `
            <div class="task-item-updated" draggable="true" data-task-id="${task.id}">
                <div class="task-content-updated">
                    <div class="task-date-updated">${dateStr}</div>
                    <div class="task-text-updated">${displayText}</div>
                </div>
            </div>
        `;
    }

    // Добавление индикаторов прокрутки
    function addScrollIndicators() {
        const columnLists = document.querySelectorAll('.tasks-list-updated');
        
        columnLists.forEach(list => {
            const scrollTop = document.createElement('div');
            scrollTop.className = 'scroll-indicator-tasks top';
            scrollTop.innerHTML = '▲';
            
            const scrollBottom = document.createElement('div');
            scrollBottom.className = 'scroll-indicator-tasks bottom';
            scrollBottom.innerHTML = '▼';
            
            list.insertBefore(scrollTop, list.firstChild);
            list.appendChild(scrollBottom);
            
            // Обработчики прокрутки
            const updateScrollIndicators = () => {
                scrollTop.style.opacity = list.scrollTop > 10 ? '1' : '0';
                const isAtBottom = list.scrollHeight - list.clientHeight - list.scrollTop < 10;
                scrollBottom.style.opacity = isAtBottom ? '0' : '1';
            };
            
            list.addEventListener('scroll', updateScrollIndicators);
            updateScrollIndicators(); // Инициализация состояния
        });
    }

    // Добавление кнопки "+"
    function addAddButton() {
        const plannedColumn = document.querySelector('.tasks-column-updated[data-column="Планируется"]');
        if (!plannedColumn) return;
        
        const addArea = plannedColumn.querySelector('.add-task-area');
        if (!addArea) return;
        
        const addButton = document.createElement('button');
        addButton.className = 'add-task-button-updated';
        addButton.innerHTML = '+';
        addButton.title = 'Добавить задачу';
        addButton.setAttribute('aria-label', 'Добавить новую задачу');
        
        addButton.addEventListener('click', showAddTaskForm);
        addArea.appendChild(addButton);
    }

    // Обновление счетчика в заголовке панели
    function updateCounter() {
        const currentUser = sessionStorage.getItem('current_user');
        const userId = currentUser ? JSON.parse(currentUser).id : null;
        
        if (!userId) return;
        
        const userTasks = currentState.tasks.filter(task => 
            task.userId === userId || task.assignee === userId
        );
        const count = userTasks.length;
        
        const counterElement = document.getElementById(`${config.panelId}Count`);
        const labelElement = document.querySelector(`.panel-label[data-panel="${config.panelId}"]`);
        
        if (counterElement) counterElement.textContent = count;
        if (labelElement) labelElement.setAttribute('data-count', count);
    }

    // Настройка обработчиков событий
    function setupEventListeners() {
        // Клик по задаче для просмотра деталей
        document.addEventListener('click', function(e) {
            const taskElement = e.target.closest('.task-item-updated');
            if (taskElement) {
                const taskId = taskElement.dataset.taskId;
                const task = currentState.tasks.find(t => t.id === taskId);
                if (task) {
                    showTaskDetails(task);
                }
            }
        });
    }

    // Настройка drag & drop
    function setupDragAndDrop() {
        document.addEventListener('dragstart', function(e) {
            if (e.target.classList.contains('task-item-updated')) {
                currentState.draggedTask = e.target;
                e.target.classList.add('dragging');
                currentState.dragStartColumn = e.target.closest('.tasks-column-updated').dataset.column;
                
                // Устанавливаем данные для переноса
                e.dataTransfer.setData('text/plain', e.target.dataset.taskId);
                e.dataTransfer.effectAllowed = 'move';
            }
        });

        document.addEventListener('dragend', function(e) {
            if (e.target.classList.contains('task-item-updated')) {
                e.target.classList.remove('dragging');
                currentState.draggedTask = null;
                currentState.dragStartColumn = null;
                
                // Убираем классы drag-over со всех колонок
                document.querySelectorAll('.tasks-column-updated').forEach(col => {
                    col.classList.remove('drag-over');
                });
            }
        });

        document.addEventListener('dragover', function(e) {
            e.preventDefault();
            const column = e.target.closest('.tasks-column-updated');
            if (column && currentState.draggedTask) {
                column.classList.add('drag-over');
            }
        });

        document.addEventListener('dragleave', function(e) {
            const column = e.target.closest('.tasks-column-updated');
            if (column) {
                // Проверяем, покинули ли мы колонку полностью
                const relatedTarget = e.relatedTarget;
                if (!column.contains(relatedTarget)) {
                    column.classList.remove('drag-over');
                }
            }
        });

        document.addEventListener('drop', function(e) {
            e.preventDefault();
            const column = e.target.closest('.tasks-column-updated');
            
            if (column && currentState.draggedTask) {
                const taskId = currentState.draggedTask.dataset.taskId;
                const newStatus = column.dataset.column;
                
                // Обновляем статус задачи
                updateTaskStatus(taskId, newStatus);
                
                // Перемещаем элемент в новый столбец
                const tasksList = column.querySelector('.tasks-list-updated');
                if (tasksList) {
                    tasksList.appendChild(currentState.draggedTask);
                }
                
                column.classList.remove('drag-over');
                
                // Обновляем счетчики
                updateColumnCounters();
                updateCounter();
                
                // Показываем уведомление
                showNotification(`Задача перемещена в "${newStatus}"`, 'success');
            }
        });
    }

    // Обновление статуса задачи
    function updateTaskStatus(taskId, newStatus) {
        const taskIndex = currentState.tasks.findIndex(t => t.id === taskId);
        if (taskIndex !== -1) {
            const task = currentState.tasks[taskIndex];
            
            // Обновляем даты в зависимости от статуса
            const now = new Date();
            const nowStr = now.toISOString().split('T')[0];
            
            switch (newStatus) {
                case 'В работе':
                    if (!task.beginningDate) {
                        task.beginningDate = nowStr;
                    }
                    break;
                case 'Завершено':
                    task.endingDate = nowStr;
                    break;
                case 'Приостановлено':
                    // Не меняем даты при приостановке
                    break;
                case 'Планируется':
                    task.beginningDate = null;
                    break;
            }
            
            task.status = newStatus;
            saveTasks();
            
            return task;
        }
        return null;
    }

    // Обновление счетчиков в столбцах
    function updateColumnCounters() {
        config.columns.forEach(column => {
            const currentUser = sessionStorage.getItem('current_user');
            const userId = currentUser ? JSON.parse(currentUser).id : null;
            
            if (!userId) return;
            
            const tasks = currentState.tasks.filter(task => 
                task.status === column.id && 
                (task.userId === userId || task.assignee === userId)
            );
            
            const counterElement = document.querySelector(`
                .tasks-column-updated[data-column="${column.id}"] .task-count-updated
            `);
            
            if (counterElement) {
                counterElement.textContent = tasks.length;
            }
        });
    }

    // Добавление новой задачи
    function addTask(taskData) {
        try {
            const currentUser = sessionStorage.getItem('current_user');
            if (!currentUser) {
                throw new Error('Пользователь не авторизован');
            }
            
            const user = JSON.parse(currentUser);
            const userId = user.id;
            
            // Находим максимальный порядковый номер для этого пользователя
            const userTasks = currentState.tasks.filter(t => t.userId === userId);
            const maxSequence = userTasks.reduce((max, task) => {
                const parts = task.id.split('-');
                const sequence = parseInt(parts[1]) || 0;
                return Math.max(max, sequence);
            }, 0);
            
            // Генерируем новый ID
            const newSequence = maxSequence + 1;
            const taskId = generateTaskId(userId, newSequence);
            
            // Парсим дату завершения
            let endingDate = null;
            if (taskData.dueDate) {
                const parts = taskData.dueDate.split('.');
                if (parts.length === 3) {
                    endingDate = `${parts[2]}-${parts[1]}-${parts[0]}`;
                }
            }
            
            const newTask = {
                id: taskId,
                userId: userId,
                title: taskData.title || taskData.description.substring(0, 50) + '...',
                description: taskData.description,
                regDate: new Date().toISOString(),
                beginningDate: null,
                endingDate: endingDate,
                status: 'Планируется',
                priority: 'Средний',
                createdBy: userId,
                assignee: userId,
                tags: []
            };
            
            currentState.tasks.push(newTask);
            saveTasks();
            render();
            updateCounter();
            
            return newTask;
        } catch (error) {
            console.error('Ошибка добавления задачи:', error);
            throw error;
        }
    }

    // Показать форму добавления задачи
    function showAddTaskForm() {
        const today = new Date();
        const dateStr = `${String(today.getDate()).padStart(2, '0')}.${String(today.getMonth() + 1).padStart(2, '0')}.${today.getFullYear()}`;
        
        const formHtml = `
            <div class="task-form-overlay">
                <div class="task-form">
                    <h3>Добавить задачу</h3>
                    <div class="form-group">
                        <label for="taskDueDate">Дата предполагаемого завершения (ДД.ММ.ГГГГ):</label>
                        <input type="text" id="taskDueDate" value="${dateStr}" placeholder="ДД.ММ.ГГГГ" maxlength="10">
                        <div class="date-hint" style="font-size: 12px; color: #ccc; margin-top: 5px;">
                            Формат: день.месяц.год
                        </div>
                    </div>
                    <div class="form-group">
                        <label for="taskText">Текст задачи:</label>
                        <textarea id="taskText" rows="5" placeholder="Опишите задачу"></textarea>
                    </div>
                    <div class="form-buttons">
                        <button type="button" class="cancel-btn">Отмена</button>
                        <button type="button" class="save-btn">Сохранить</button>
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
        
        const saveBtn = formContainer.querySelector('.save-btn');
        const dueDateInput = formContainer.querySelector('#taskDueDate');
        const taskTextInput = formContainer.querySelector('#taskText');
        
        // Маска для ввода даты
        dueDateInput.addEventListener('input', function(e) {
            let value = e.target.value.replace(/\D/g, '');
            
            if (value.length > 2) {
                value = value.substring(0, 2) + '.' + value.substring(2);
            }
            if (value.length > 5) {
                value = value.substring(0, 5) + '.' + value.substring(5, 9);
            }
            
            e.target.value = value;
        });
        
        saveBtn.addEventListener('click', () => {
            const dueDate = dueDateInput.value.trim();
            const text = taskTextInput.value.trim();
            
            if (!text) {
                showNotification('Введите текст задачи', 'warning');
                taskTextInput.focus();
                return;
            }
            
            // Валидация даты
            if (dueDate) {
                const dateRegex = /^\d{2}\.\d{2}\.\d{4}$/;
                if (!dateRegex.test(dueDate)) {
                    showNotification('Введите дату в формате ДД.ММ.ГГГГ', 'warning');
                    dueDateInput.focus();
                    return;
                }
                
                const parts = dueDate.split('.');
                const day = parseInt(parts[0]);
                const month = parseInt(parts[1]);
                const year = parseInt(parts[2]);
                
                const date = new Date(year, month - 1, day);
                if (date.getDate() !== day || date.getMonth() !== month - 1 || date.getFullYear() !== year) {
                    showNotification('Введите корректную дату', 'warning');
                    dueDateInput.focus();
                    return;
                }
            }
            
            try {
                addTask({ 
                    description: text, 
                    dueDate: dueDate || null,
                    title: text.length > 50 ? text.substring(0, 50) + '...' : text
                });
                
                formContainer.remove();
                showNotification('Задача добавлена', 'success');
            } catch (error) {
                showNotification('Ошибка при добавлении задачи', 'error');
            }
        });
        
        // Закрытие по клику вне формы
        formContainer.querySelector('.task-form-overlay').addEventListener('click', (e) => {
            if (e.target.classList.contains('task-form-overlay')) {
                formContainer.remove();
            }
        });
        
        // Закрытие по клавише Escape
        document.addEventListener('keydown', function closeOnEscape(e) {
            if (e.key === 'Escape') {
                formContainer.remove();
                document.removeEventListener('keydown', closeOnEscape);
            }
        });
        
        // Автофокус на поле ввода текста
        taskTextInput.focus();
    }

    // Показать детали задачи
    function showTaskDetails(task) {
        const formatDate = (dateStr) => {
            if (!dateStr) return 'Не указана';
            const date = new Date(dateStr);
            return `${String(date.getDate()).padStart(2, '0')}.${String(date.getMonth() + 1).padStart(2, '0')}.${date.getFullYear()}`;
        };
        
        const detailsHtml = `
            <div class="task-form-overlay">
                <div class="task-form" style="max-width: 500px;">
                    <h3>Детали задачи</h3>
                    <div class="form-group">
                        <label>ID задачи:</label>
                        <input type="text" value="${task.id}" readonly>
                    </div>
                    <div class="form-group">
                        <label>Дата регистрации:</label>
                        <input type="text" value="${formatDate(task.regDate)}" readonly>
                    </div>
                    <div class="form-group">
                        <label>Дата начала:</label>
                        <input type="text" value="${formatDate(task.beginningDate)}" readonly>
                    </div>
                    <div class="form-group">
                        <label>Дата завершения:</label>
                        <input type="text" value="${formatDate(task.endingDate)}" readonly>
                    </div>
                    <div class="form-group">
                        <label>Статус:</label>
                        <input type="text" value="${task.status}" readonly>
                    </div>
                    <div class="form-group">
                        <label>Приоритет:</label>
                        <input type="text" value="${task.priority}" readonly>
                    </div>
                    <div class="form-group">
                        <label>Описание задачи:</label>
                        <textarea rows="6" readonly style="background-color: rgba(0, 28, 51, 0.3);">${task.description || ''}</textarea>
                    </div>
                    <div class="form-buttons">
                        <button type="button" class="cancel-btn">Закрыть</button>
                    </div>
                </div>
            </div>
        `;
        
        const detailsContainer = document.createElement('div');
        detailsContainer.innerHTML = detailsHtml;
        document.body.appendChild(detailsContainer);
        
        detailsContainer.querySelector('.cancel-btn').addEventListener('click', () => {
            detailsContainer.remove();
        });
        
        // Закрытие по клику вне формы
        detailsContainer.querySelector('.task-form-overlay').addEventListener('click', (e) => {
            if (e.target.classList.contains('task-form-overlay')) {
                detailsContainer.remove();
            }
        });
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
        addTask: addTask,
        getTasks: function() { 
            const currentUser = sessionStorage.getItem('current_user');
            const userId = currentUser ? JSON.parse(currentUser).id : null;
            return currentState.tasks.filter(task => task.userId === userId || task.assignee === userId);
        },
        updateCounter: updateCounter,
        // Метод для обновления при изменении пользователя
        refresh: function() {
            loadTasks();
            render();
            updateCounter();
        }
    };
})();

    // Инициализация панели задач при наличии авторизованного пользователя
    document.addEventListener('DOMContentLoaded', function() {
        const currentUser = sessionStorage.getItem('current_user');
        if (currentUser && typeof TasksPanelUpdated !== 'undefined') {
            console.log('Инициализация панели задач для пользователя:', currentUser);
            setTimeout(() => {
                TasksPanelUpdated.init();
            }, 1000);
        } else {
            console.log('Пользователь не авторизован или TasksPanelUpdated не загружен');
        }
    });