// tasks-panel.js - Модуль задач
const TasksPanel = (function() {
    // Конфигурация
    const config = {
        panelId: 'tasks',
        storageKey: 'prostvor_tasks',
        columns: [
            { id: 'planned', title: 'Планируется', color: '#4CAF50' },
            { id: 'inProgress', title: 'В работе', color: '#2196F3' },
            { id: 'paused', title: 'Приостановлено', color: '#FF9800' },
            { id: 'completed', title: 'Завершено', color: '#9E9E9E' }
        ]
    };

    // Текущее состояние
    let currentState = {
        tasks: [],
        draggedTask: null
    };

    // Инициализация
    function init() {
        try {
            loadTasks();
            render();
            setupEventListeners();
            setupDragAndDrop();
        } catch (error) {
            console.error('Ошибка инициализации задач:', error);
        }
    }

    // Загрузка задач
    function loadTasks() {
        try {
            const tasks = localStorage.getItem(config.storageKey);
            currentState.tasks = tasks ? JSON.parse(tasks) : [];
        } catch (error) {
            console.error('Ошибка загрузки задач:', error);
            currentState.tasks = [];
        }
    }

    // Сохранение задач
    function saveTasks() {
        try {
            localStorage.setItem(config.storageKey, JSON.stringify(currentState.tasks));
        } catch (error) {
            console.error('Ошибка сохранения задач:', error);
        }
    }

    // Рендер задач
    function render() {
        const panel = document.querySelector(`.panel-content[data-panel="${config.panelId}"] .panel-body`);
        if (!panel) return;

        let html = `
            <div class="tasks-container">
                <div class="tasks-columns">
                    ${config.columns.map(column => renderColumn(column)).join('')}
                </div>
            </div>
        `;

        panel.innerHTML = html;
        updateCounter();
    }

    // Рендер колонки
    function renderColumn(column) {
        const tasks = currentState.tasks.filter(task => task.status === column.id);
        
        return `
            <div class="tasks-column" data-column="${column.id}">
                <div class="column-header" style="border-bottom-color: ${column.color};">
                    <h4>${column.title}</h4>
                    <span class="task-count">${tasks.length}</span>
                </div>
                <div class="tasks-list" data-column="${column.id}">
                    ${tasks.map(task => renderTask(task)).join('')}
                </div>
                ${column.id === 'planned' ? '<button class="add-task-btn">+</button>' : ''}
            </div>
        `;
    }

    // Рендер задачи
    function renderTask(task) {
        return `
            <div class="task-item" draggable="true" data-task-id="${task.id}">
                <div class="task-content">
                    <div class="task-date">${task.dueDate || 'Без срока'}</div>
                    <div class="task-text">${task.text}</div>
                </div>
            </div>
        `;
    }

    // Обновление счетчика
    function updateCounter() {
        const count = currentState.tasks.length;
        const counterElement = document.getElementById(`${config.panelId}Count`);
        const labelElement = document.querySelector(`.panel-label[data-panel="${config.panelId}"]`);
        
        if (counterElement) counterElement.textContent = count;
        if (labelElement) labelElement.setAttribute('data-count', count);
    }

    // Настройка обработчиков событий
    function setupEventListeners() {
        // Кнопка добавления задачи
        document.addEventListener('click', function(e) {
            if (e.target.classList.contains('add-task-btn')) {
                showAddTaskForm();
            }
        });
    }

    // Настройка drag & drop
    function setupDragAndDrop() {
        document.addEventListener('dragstart', function(e) {
            if (e.target.classList.contains('task-item')) {
                currentState.draggedTask = e.target;
                e.target.classList.add('dragging');
            }
        });

        document.addEventListener('dragend', function(e) {
            if (e.target.classList.contains('task-item')) {
                e.target.classList.remove('dragging');
                currentState.draggedTask = null;
            }
        });

        document.addEventListener('dragover', function(e) {
            e.preventDefault();
            const column = e.target.closest('.tasks-list');
            if (column) {
                column.classList.add('drag-over');
            }
        });

        document.addEventListener('dragleave', function(e) {
            const column = e.target.closest('.tasks-list');
            if (column) {
                column.classList.remove('drag-over');
            }
        });

        document.addEventListener('drop', function(e) {
            e.preventDefault();
            const column = e.target.closest('.tasks-list');
            
            if (column && currentState.draggedTask) {
                const taskId = currentState.draggedTask.dataset.taskId;
                const newStatus = column.dataset.column;
                
                updateTaskStatus(taskId, newStatus);
                column.appendChild(currentState.draggedTask);
                column.classList.remove('drag-over');
            }
        });
    }

    // Обновление статуса задачи
    function updateTaskStatus(taskId, newStatus) {
        const taskIndex = currentState.tasks.findIndex(t => t.id == taskId);
        if (taskIndex !== -1) {
            currentState.tasks[taskIndex].status = newStatus;
            saveTasks();
            updateCounter();
        }
    }

    // Добавление задачи
    function addTask(taskData) {
        try {
            const newTask = {
                id: Date.now(),
                text: taskData.text,
                dueDate: taskData.dueDate || null,
                status: 'planned',
                created: new Date().toISOString()
            };
            
            currentState.tasks.push(newTask);
            saveTasks();
            render();
            
            return newTask;
        } catch (error) {
            console.error('Ошибка добавления задачи:', error);
            throw error;
        }
    }

    // Показать форму добавления задачи
    function showAddTaskForm() {
        const today = new Date();
        const dateStr = today.toISOString().split('T')[0];
        
        const formHtml = `
            <div class="task-form-overlay">
                <div class="task-form">
                    <h3>Добавить задачу</h3>
                    <div class="form-group">
                        <label>Дата завершения:</label>
                        <input type="date" id="taskDueDate" value="${dateStr}">
                    </div>
                    <div class="form-group">
                        <label>Текст задачи:</label>
                        <textarea id="taskText" rows="4"></textarea>
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
            const dueDate = document.getElementById('taskDueDate').value;
            const text = document.getElementById('taskText').value;
            
            if (!text.trim()) {
                alert('Введите текст задачи');
                return;
            }
            
            addTask({ text, dueDate });
            formContainer.remove();
        });
    }

    // Публичные методы
    return {
        init: init,
        addTask: addTask,
        getTasks: function() { return currentState.tasks; }
    };
})();