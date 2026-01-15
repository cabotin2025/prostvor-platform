// projects-main.js
document.addEventListener('DOMContentLoaded', function() {
    // Инициализация страницы проектов
    initProjectsPage();
});

function initProjectsPage() {
    // Загружаем все проекты при загрузке страницы
    displayProjects(projectsDatabase);
    
    // Инициализируем поиск по названию
    initNameSearch();
    
    // Инициализируем поиск по направлению
    initDirectionSearch();
    
    // Инициализируем поиск по дате
    initDateSearch();
    
    // Инициализируем форму поддержки
    initSupportForm();
    
    // Добавляем ссылку создания проекта
    addCreateProjectLink();
    
    // Выбираем первый проект по умолчанию
    if (projectsDatabase.length > 0) {
        selectProject(projectsDatabase[0]);
    }
}

// Интеграция с системой коммуникаций
function setupProjectsCommunications() {
    // При загрузке проектов добавляем обработчики
    projectsDatabase.forEach(project => {
        // Добавляем data-атрибуты для идентификации
        const projectElement = document.querySelector(`[data-project-id="${project.id}"]`);
        if (projectElement) {
            projectElement.addEventListener('click', function() {
                CommunicationsManager.setCurrentItem(
                    project.id,
                    'project',
                    project.name
                );
            });
        }
    });
    
    // Обновляем счетчики при загрузке
    CommunicationsManager.updateCounters();
}

// Вызов после загрузки проектов
document.addEventListener('DOMContentLoaded', function() {
    // ... существующий код ...
    setupProjectsCommunications();
});

// Отображение списка проектов
function displayProjects(projects) {
    const projectsList = document.getElementById('projectsList');
    if (!projectsList) return;
    
    projectsList.innerHTML = '';
    
    projects.forEach(project => {
        const projectElement = document.createElement('div');
        projectElement.className = 'project-item';
        projectElement.dataset.projectId = project.ProjectID;
        projectElement.innerHTML = `
            <span class="project-name">${project.ProgectName}</span>
        `;
        
        projectElement.addEventListener('click', () => {
            // Убираем выделение у всех проектов
            document.querySelectorAll('.project-item').forEach(item => {
                item.classList.remove('selected');
                item.querySelector('.project-name').style.color = '#FFFFFF';
            });
            
            // Выделяем выбранный проект
            projectElement.classList.add('selected');
            projectElement.querySelector('.project-name').style.color = '#A8E40A';
            
            // Отображаем информацию о проекте
            selectProject(project);
        });
        
        projectsList.appendChild(projectElement);
    });
}

// Добавление ссылки создания проекта
function addCreateProjectLink() {
    const projectsList = document.getElementById('projectsList');
    if (!projectsList) return;
    
    // Создаем контейнер для ссылки
    const createProjectContainer = document.createElement('div');
    createProjectContainer.className = 'create-project-container';
    
    // Создаем ссылку
    const createProjectLink = document.createElement('a');
    createProjectLink.href = '#';
    createProjectLink.className = 'create-project-link';
    createProjectLink.id = 'createProjectLink';
    
    // Добавляем иконку
    const hexIcon = document.createElement('img');
    hexIcon.src = '../images/HexP.svg';
    hexIcon.alt = 'Создать проект';
    hexIcon.className = 'hex-icon';
    
    // Добавляем текст
    const linkText = document.createElement('span');
    linkText.textContent = 'Создать Проект';
    
    // Собираем ссылку
    createProjectLink.appendChild(hexIcon);
    createProjectLink.appendChild(linkText);
    
    // Добавляем обработчик клика
    createProjectLink.addEventListener('click', function(e) {
        e.preventDefault();
        handleCreateProject();
    });
    
    // Добавляем в контейнер
    createProjectContainer.appendChild(createProjectLink);
    
    // Добавляем после списка проектов
    projectsList.parentNode.insertBefore(createProjectContainer, projectsList.nextSibling);
}

// Обработка создания проекта
function handleCreateProject() {
    // Проверяем авторизацию - используем правильный ключ
    const currentUser = sessionStorage.getItem('prostvor_current_user');
    
    if (!currentUser) {
        // Пользователь не авторизован
        showNotification('Создавать Проекты могут только авторизованные Участники', 'warning');
        return;
    }
    
    try {
        // Пытаемся распарсить JSON
        const user = JSON.parse(currentUser);
        console.log('Пользователь авторизован:', user.nickname);
        
        // Пользователь авторизован - переходим на страницу создания проекта
        window.location.href = "ProjectMain.html";
    } catch (error) {
        console.error('Ошибка парсинга пользователя:', error);
        showNotification('Ошибка проверки авторизации', 'error');
    }
}

// Отображение информации о выбранном проекте
function selectProject(project) {
    // Находим менеджера проекта
    const manager = getProjectManager(project.ProjectManagerID);
    
    // Находим направление проекта
    const direction = directionsDatabase.find(d => d.DirectionID === project.DirectionID);
    
    // Находим требуемые функции
    const requiredFunctions = project.RequiredFunctions.map(funcId => {
        const func = functionsDatabase.find(f => f.FunctionID === funcId);
        return func ? func.FunctionName : '';
    }).filter(name => name !== '');
    
    // Находим требуемые ресурсы
    const requiredResources = project.RequiredResources.map(resId => {
        const res = resourcesDatabase.find(r => r.ResourceID === resId);
        return res ? res.ResourceName : '';
    }).filter(name => name !== '');
    
    // Обновляем правую часть
    updateProjectDetails({
        ...project,
        manager,
        directionName: direction ? direction.DirectionName : 'Не указано',
        requiredFunctions,
        requiredResources
    });
}

// Получение менеджера проекта
function getProjectManager(managerId) {
    // В реальном приложении здесь был бы запрос к actors-database.js
    // Для примера создаем заглушку
    const managers = [
        { id: 101, nick: "Иван_Театралов", status: "Руководитель проекта", borderColor: "#00B0F0" },
        { id: 102, nick: "Анна_Кино", status: "Руководитель проекта", borderColor: "#A8E40A" },
        { id: 103, nick: "Максим_СтритАрт", status: "Руководитель проекта", borderColor: "#FFD965" },
        { id: 104, nick: "София_Музыка", status: "Руководитель проекта", borderColor: "#00B0F0" },
        { id: 105, nick: "Дмитрий_Танцы", status: "Руководитель проекта", borderColor: "#A8E40A" },
        { id: 106, nick: "Екатерина_Кулинария", status: "Руководитель проекта", borderColor: "#FFD965" },
        { id: 107, nick: "Алексей_Литература", status: "Руководитель проекта", borderColor: "#00B0F0" },
        { id: 108, nick: "Мария_Фото", status: "Руководитель проекта", borderColor: "#A8E40A" }
    ];
    
    return managers.find(m => m.id === managerId) || { nick: "Не указан", status: "Руководитель проекта", borderColor: "#00B0F0" };
}

// Обновление деталей проекта
function updateProjectDetails(project) {
    console.log('Обновление деталей проекта:', project.ProgectName);
    
    // Обновляем информацию о менеджере
    const managerElement = document.getElementById('projectManager');
    if (managerElement) {
        managerElement.innerHTML = `
            <div class="user-display" style="border-color: ${project.manager.borderColor};">
                <div class="user-nickname">${project.manager.nick}</div>
                <div class="user-status">${project.manager.status}</div>
            </div>
        `;
    }
    
    // Обновляем название проекта
    const titleElement = document.getElementById('projectTitle');
    if (titleElement) {
        titleElement.textContent = project.ProgectName;
    }
    
    // Обновляем направление, статус и тип
    document.getElementById('projectDirection').textContent = project.directionName;
    document.getElementById('projectStatus').textContent = project.ProjectStatus;
    document.getElementById('projectType').textContent = project.ProjectType;
    
    // Обновляем полное название и описание
    document.getElementById('projectFullName').textContent = project.ProgectNameFull;
    document.getElementById('projectDescription').textContent = project.ProjectDescription;
    
    // Обновляем требуемые функции
    const functionsList = document.getElementById('requiredFunctionsList');
    if (functionsList) {
        functionsList.innerHTML = '';
        project.requiredFunctions.forEach(func => {
            const li = document.createElement('li');
            li.textContent = func;
            functionsList.appendChild(li);
        });
    }
    
    // Обновляем требуемые ресурсы
    const resourcesList = document.getElementById('requiredResourcesList');
    if (resourcesList) {
        resourcesList.innerHTML = '';
        project.requiredResources.forEach(res => {
            const li = document.createElement('li');
            li.textContent = res;
            li.style.color = '#FFC000';
            resourcesList.appendChild(li);
        });
    }
    
    // Обновляем финансовую информацию
    document.getElementById('requiredFunds').textContent = formatCurrency(project.RequiredFunds);
    document.getElementById('collectedFunds').textContent = formatCurrency(project.CollectedFunds);
    
    // Обновляем форму поддержки
    const donationProjectName = document.getElementById('donationProjectName');
    const donationPurpose = document.getElementById('donationPurpose');
    
    if (donationProjectName) {
        donationProjectName.value = project.ProgectName;
    }
    
    if (donationPurpose) {
        donationPurpose.value = `Добровольные пожертвования для проекта ${project.ProgectName}`;
    }
}

// Форматирование валюты
function formatCurrency(amount) {
    return amount.toLocaleString('ru-RU', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    }) + ' рублей';
}

// Поиск по названию проекта
function initNameSearch() {
    const nameSearchInput = document.getElementById('projectNameSearch');
    const searchButton = document.getElementById('searchButton');
    
    if (!nameSearchInput || !searchButton) return;
    
    const performSearch = () => {
        const searchTerm = nameSearchInput.value.trim().toLowerCase();
        
        if (searchTerm === '') {
            displayProjects(projectsDatabase);
            return;
        }
        
        const filteredProjects = projectsDatabase.filter(project =>
            project.ProgectName.toLowerCase().includes(searchTerm) ||
            project.ProgectNameFull.toLowerCase().includes(searchTerm)
        );
        
        displayProjects(filteredProjects);
    };
    
    searchButton.addEventListener('click', performSearch);
    nameSearchInput.addEventListener('keyup', (e) => {
        if (e.key === 'Enter') {
            performSearch();
        }
    });
}

// Поиск по направлению
function initDirectionSearch() {
    const directionInput = document.getElementById('directionSearch');
    
    if (!directionInput) return;
    
    // Автодополнение направлений
    directionInput.addEventListener('input', function() {
        const searchTerm = this.value.toLowerCase();
        const matchingDirections = directionsDatabase.filter(direction =>
            direction.DirectionName.toLowerCase().includes(searchTerm)
        );
        
        // Здесь можно добавить отображение подсказок
    });
    
    directionInput.addEventListener('keyup', (e) => {
        if (e.key === 'Enter') {
            const searchTerm = directionInput.value.trim().toLowerCase();
            
            if (searchTerm === '') {
                displayProjects(projectsDatabase);
                return;
            }
            
            const matchingDirection = directionsDatabase.find(direction =>
                direction.DirectionName.toLowerCase().includes(searchTerm)
            );
            
            if (matchingDirection) {
                const filteredProjects = projectsDatabase.filter(project =>
                    project.DirectionID === matchingDirection.DirectionID
                );
                displayProjects(filteredProjects);
            }
        }
    });
}

// Поиск по дате
function initDateSearch() {
    const yearInput = document.getElementById('yearSearch');
    const monthInput = document.getElementById('monthSearch');
    const dayInput = document.getElementById('daySearch');
    
    if (!yearInput || !monthInput || !dayInput) return;
    
    const performDateSearch = () => {
        const year = yearInput.value.trim();
        const month = monthInput.value.trim();
        const day = dayInput.value.trim();
        
        let filteredProjects = projectsDatabase;
        
        if (year) {
            filteredProjects = filteredProjects.filter(project => {
                const projectYear = project.ProjectStartDate.split('-')[0];
                return projectYear === year;
            });
        }
        
        if (month) {
            filteredProjects = filteredProjects.filter(project => {
                const projectMonth = project.ProjectStartDate.split('-')[1];
                const monthIndex = months.findIndex(m => 
                    m.toLowerCase() === month.toLowerCase()
                ) + 1;
                const monthString = monthIndex.toString().padStart(2, '0');
                return projectMonth === monthString;
            });
        }
        
        if (day) {
            filteredProjects = filteredProjects.filter(project => {
                const projectDay = project.ProjectStartDate.split('-')[2];
                const dayString = parseInt(day).toString().padStart(2, '0');
                return projectDay === dayString;
            });
        }
        
        displayProjects(filteredProjects);
    };
    
    [yearInput, monthInput, dayInput].forEach(input => {
        input.addEventListener('keyup', (e) => {
            if (e.key === 'Enter') {
                performDateSearch();
            }
        });
    });
}

// Поддержка проекта
function initSupportForm() {
    console.log('Инициализация формы поддержки');
    
    const supportForm = document.getElementById('supportForm');
    const supportButton = document.querySelector('.support-project-button');
    const invoiceLink = document.querySelector('.invoice-link');
    
    console.log('supportForm:', supportForm);
    console.log('supportButton:', supportButton);
    console.log('invoiceLink:', invoiceLink);
    
    if (!supportForm) {
        console.error('Форма поддержки не найдена!');
        return;
    }
    
    if (!supportButton) {
        console.error('Кнопка поддержки проекта не найдена!');
        return;
    }
    
    // Обработка клика на кнопку поддержки
    supportButton.addEventListener('click', (e) => {
        e.preventDefault();
        console.log('Кнопка поддержки проекта нажата');
        supportForm.style.display = 'flex';
    });
    
    // Закрытие формы
    const closeForm = supportForm.querySelector('.close-form');
    if (closeForm) {
        closeForm.addEventListener('click', () => {
            console.log('Закрытие формы поддержки');
            supportForm.style.display = 'none';
        });
    }
    
    // Закрытие при клике вне формы
    supportForm.addEventListener('click', (e) => {
        if (e.target === supportForm) {
            supportForm.style.display = 'none';
        }
    });
    
    // Обработка отправки формы
    const donationForm = document.getElementById('donationForm');
    if (donationForm) {
        donationForm.addEventListener('submit', (e) => {
            e.preventDefault();
            
            const amount = document.getElementById('donationAmount').value;
            const cardNumber = document.getElementById('cardNumber').value;
            const projectName = document.getElementById('donationProjectName').value;
            
            console.log('Отправка формы поддержки:', { amount, cardNumber, projectName });
            
            if (amount && cardNumber) {
                alert(`Спасибо за поддержку проекта "${projectName}"! Сумма ${amount} рублей будет списана с карты ${cardNumber}.`);
                supportForm.style.display = 'none';
                donationForm.reset();
            } else {
                alert('Пожалуйста, заполните все обязательные поля.');
            }
        });
    }
    
    // Генерация счёта
    if (invoiceLink) {
        invoiceLink.addEventListener('click', (e) => {
            e.preventDefault();
            const projectName = document.getElementById('donationProjectName').value;
            console.log('Генерация счёта для проекта:', projectName);
            alert(`Счёт на оплату для проекта "${projectName}" сгенерирован и отправлен на вашу электронную почту.`);
        });
    }
}

// Показать уведомление
function showNotification(message, type = 'info') {
    const notification = document.getElementById('notification');
    if (!notification) return;
    
    notification.textContent = message;
    notification.className = `notification ${type} show`;
    
    setTimeout(() => {
        notification.classList.remove('show');
    }, 3000);
}

document.querySelectorAll('.project-item').forEach(item => {
    item.addEventListener('click', function() {
        CommunicationsManager.setSelectedItem(
            this.dataset.projectId,
            this.dataset.projectName,
            { author_id: this.dataset.authorId }
        );
    });
});

// Интеграция с реальным списком проектов
function setupProjectSelection() {
    // Селектор зависит от вашей разметки - уточните его
    const projectSelectors = [
        '.project-item',
        '.project-row',
        '[data-project-id]',
        '.list-group-item',
        'tr[data-id]'
    ];
    
    let projectItems = [];
    
    // Пробуем разные селекторы
    for (const selector of projectSelectors) {
        const items = document.querySelectorAll(selector);
        if (items.length > 0) {
            projectItems = items;
            console.log(`✅ Найдены проекты по селектору: ${selector} (${items.length} шт.)`);
            break;
        }
    }
    
    if (projectItems.length === 0) {
        console.log('⚠️ Проекты не найдены. Проверьте разметку.');
        return;
    }
    
    // Добавляем обработчики
    projectItems.forEach(item => {
        item.style.cursor = 'pointer';
        
        item.addEventListener('click', function() {
            // Получаем ID проекта из data-атрибутов
            const projectId = this.dataset.projectId || 
                             this.dataset.id || 
                             this.getAttribute('data-id');
            
            // Получаем название
            const projectName = this.dataset.projectName || 
                               this.querySelector('.project-title, .title, .name')?.textContent || 
                               'Проект';
            
            if (projectId && window.CommunicationsManager) {
                CommunicationsManager.setSelectedItem(projectId, projectName, {
                    author_id: this.dataset.authorId || this.dataset.createdBy
                });
                
                // Визуальное выделение
                projectItems.forEach(i => i.classList.remove('selected'));
                this.classList.add('selected');
                
                console.log(`✅ Выбран проект: ${projectName} (ID: ${projectId})`);
            }
        });
    });
}

// Запускаем после загрузки страницы
document.addEventListener('DOMContentLoaded', function() {
    setTimeout(setupProjectSelection, 1500);
});