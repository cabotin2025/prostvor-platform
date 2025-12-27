// tasks-base.js - База данных задач с 9-значным ID
const TasksBase = (function() {
    const STORAGE_KEY = 'prostvor_tasks_base';
    const ID_COUNTER_KEY = 'prostvor_tasks_id_counter';
    
    // Инициализация базы данных
    function init() {
        try {
            const tasks = localStorage.getItem(STORAGE_KEY);
            if (!tasks) {
                saveTasks([]);
            }
            
            // Инициализируем счетчик ID
            if (!localStorage.getItem(ID_COUNTER_KEY)) {
                localStorage.setItem(ID_COUNTER_KEY, '100000001');
            }
            
            return true;
        } catch (error) {
            console.error('Ошибка инициализации базы данных задач:', error);
            return false;
        }
    }
    
    // Генерация 9-значного ID
    function generateId(actorId = null) {
        try {
            if (actorId) {
                // Если передан ID участника, используем его как основу
                const baseId = actorId.toString().padStart(9, '0');
                let lastSubId = parseInt(localStorage.getItem(ID_COUNTER_KEY + '_' + baseId)) || 1;
                const taskId = baseId + '-' + lastSubId.toString().padStart(3, '0');
                lastSubId++;
                localStorage.setItem(ID_COUNTER_KEY + '_' + baseId, lastSubId.toString());
                return taskId;
            } else {
                // Генерация обычного ID
                let lastId = parseInt(localStorage.getItem(ID_COUNTER_KEY)) || 100000001;
                const newId = lastId.toString().padStart(9, '0');
                lastId++;
                localStorage.setItem(ID_COUNTER_KEY, lastId.toString());
                return newId;
            }
        } catch (error) {
            console.error('Ошибка генерации ID задачи:', error);
            return Date.now().toString().slice(-9);
        }
    }
    
    // Сохранение задач
    function saveTasks(tasks) {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(tasks));
            return true;
        } catch (error) {
            console.error('Ошибка сохранения задач:', error);
            return false;
        }
    }
    
    // Получить все задачи пользователя
    function getUserTasks(userId) {
        try {
            const tasks = localStorage.getItem(STORAGE_KEY);
            const allTasks = tasks ? JSON.parse(tasks) : [];
            return allTasks.filter(task => task.userId === userId);
        } catch (error) {
            console.error('Ошибка получения задач:', error);
            return [];
        }
    }
    
    // Создать новую задачу
    function createTask(userId, taskData) {
        try {
            const currentUser = sessionStorage.getItem('current_user');
            let actorId = null;
            
            if (currentUser) {
                const user = JSON.parse(currentUser);
                actorId = user.id;
            }
            
            const task = {
                id: generateId(actorId),
                userId: userId,
                title: taskData.title || '',
                description: taskData.description || '',
                regDate: new Date().toISOString(),
                beginningDate: taskData.beginningDate || null,
                endingDate: taskData.endingDate || null,
                status: taskData.status || 'Планируется',
                priority: taskData.priority || 'Средний',
                createdBy: taskData.createdBy || userId,
                assignee: taskData.assignee || userId,
                tags: taskData.tags || []
            };

            const tasks = localStorage.getItem(STORAGE_KEY);
            const allTasks = tasks ? JSON.parse(tasks) : [];
            allTasks.push(task);
            saveTasks(allTasks);

            return task;
        } catch (error) {
            console.error('Ошибка создания задачи:', error);
            throw error;
        }
    }
    
    // Обновить задачу
    function updateTask(taskId, updates) {
        try {
            const tasks = localStorage.getItem(STORAGE_KEY);
            const allTasks = tasks ? JSON.parse(tasks) : [];
            const taskIndex = allTasks.findIndex(task => task.id === taskId);

            if (taskIndex === -1) {
                throw new Error('Задача не найдена');
            }

            allTasks[taskIndex] = { ...allTasks[taskIndex], ...updates };
            saveTasks(allTasks);

            return allTasks[taskIndex];
        } catch (error) {
            console.error('Ошибка обновления задачи:', error);
            throw error;
        }
    }
    
    // Удалить задачу
    function deleteTask(taskId) {
        try {
            const tasks = localStorage.getItem(STORAGE_KEY);
            const allTasks = tasks ? JSON.parse(tasks) : [];
            const filteredTasks = allTasks.filter(task => task.id !== taskId);
            saveTasks(filteredTasks);

            return true;
        } catch (error) {
            console.error('Ошибка удаления задачи:', error);
            throw error;
        }
    }
    
    // Изменить статус задачи
    function changeTaskStatus(taskId, newStatus) {
        try {
            const validStatuses = ['Планируется', 'В работе', 'Приостановлено', 'Завершено'];
            if (!validStatuses.includes(newStatus)) {
                throw new Error('Некорректный статус задачи');
            }

            return updateTask(taskId, { status: newStatus });
        } catch (error) {
            console.error('Ошибка изменения статуса задачи:', error);
            throw error;
        }
    }
    
    // Получить задачи по статусу
    function getTasksByStatus(userId, status) {
        const userTasks = getUserTasks(userId);
        return userTasks.filter(task => task.status === status);
    }
    
    // Получить статистику по задачам
    function getTasksStatistics(userId) {
        const userTasks = getUserTasks(userId);
        const total = userTasks.length;
        const planned = userTasks.filter(task => task.status === 'Планируется').length;
        const inProgress = userTasks.filter(task => task.status === 'В работе').length;
        const paused = userTasks.filter(task => task.status === 'Приостановлено').length;
        const completed = userTasks.filter(task => task.status === 'Завершено').length;

        return {
            total,
            planned,
            inProgress,
            paused,
            completed,
            completionRate: total > 0 ? (completed / total * 100).toFixed(1) : 0
        };
    }
    
    // Инициализация при загрузке
    init();

    // Публичные методы
    return {
        getUserTasks,
        createTask,
        updateTask,
        deleteTask,
        changeTaskStatus,
        getTasksByStatus,
        getTasksStatistics
    };
})();