// /js/projects-integration.js
// Интеграция блока коммуникаций со страницей проектов

document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 Projects Integration: Загружен');
    
    // Ждем загрузки CommunicationsManager
    const waitForCommunications = setInterval(() => {
        if (window.CommunicationsManager) {
            clearInterval(waitForCommunications);
            initializeIntegration();
        }
    }, 100);
    
    function initializeIntegration() {
        console.log('✅ CommunicationsManager доступен');
        
        // 1. Активируем страницу для блока коммуникаций
        document.body.classList.add('has-content');
        
        // 2. Настраиваем выбор проектов
        setupProjectSelection();
        
        // 3. Проверяем авторизацию
        checkAuthStatus();
        
        console.log('✅ Интеграция инициализирована');
    }
    
    function setupProjectSelection() {
        // Попробуем найти проекты через разные селекторы
        const possibleSelectors = [
            '.project-item',
            '.project-row',
            '[data-project-id]',
            '[data-id]',
            '.list-group-item',
            'tr',
            '.card'
        ];
        
        let projectElements = [];
        let usedSelector = '';
        
        for (const selector of possibleSelectors) {
            const elements = document.querySelectorAll(selector);
            if (elements.length > 1) { // Больше 1, чтобы исключить контейнеры
                projectElements = Array.from(elements);
                usedSelector = selector;
                break;
            }
        }
        
        if (projectElements.length === 0) {
            console.log('⚠️ Элементы проектов не найдены');
            
            // Создаем тестовые проекты для демонстрации
            createTestProjects();
            return;
        }
        
        console.log(`✅ Найдено ${projectElements.length} проектов по селектору: ${usedSelector}`);
        
        // Добавляем обработчики клика
        projectElements.forEach((element, index) => {
            // Добавляем cursor pointer
            element.style.cursor = 'pointer';
            
            // Убедимся, что у элемента есть data-атрибуты
            if (!element.dataset.projectId) {
                element.dataset.projectId = index + 1;
            }
            if (!element.dataset.projectName) {
                const nameElement = element.querySelector('.project-name, .title, h3, h4') || 
                                   element.querySelector('td:first-child');
                if (nameElement) {
                    element.dataset.projectName = nameElement.textContent.trim();
                } else {
                    element.dataset.projectName = `Проект ${index + 1}`;
                }
            }
            
            element.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                
                const projectId = this.dataset.projectId;
                const projectName = this.dataset.projectName;
                const authorId = this.dataset.authorId || 1; // По умолчанию
                
                // Выделяем выбранный проект
                projectElements.forEach(el => el.classList.remove('selected'));
                this.classList.add('selected');
                
                // Сообщаем блоку коммуникаций
                CommunicationsManager.setSelectedItem(projectId, projectName, {
                    author_id: authorId
                });
                
                console.log(`🎯 Выбран проект: ${projectName} (ID: ${projectId})`);
            });
        });
        
        // Добавляем стили для выделения
        const style = document.createElement('style');
        style.textContent = `
            .selected {
                background-color: rgba(168, 228, 10, 0.1) !important;
                border-left: 3px solid #A8E40A !important;
            }
            [data-project-id] {
                transition: background-color 0.3s ease;
            }
        `;
        document.head.appendChild(style);
    }
    
    function createTestProjects() {
        console.log('🛠️ Создаю тестовые проекты...');
        
        const testProjects = [
            {id: 1, name: 'Театральная постановка "Гамлет"', author: 'Иван Иванов'},
            {id: 2, name: 'Фестиваль уличного искусства', author: 'Мария Петрова'},
            {id: 3, name: 'Киностудия "Новое кино"', author: 'Алексей Сидоров'}
        ];
        
        const container = document.querySelector('.projects-list, .content-frame, #projects-container, main') || 
                         document.querySelector('body');
        
        if (!container) return;
        
        const testDiv = document.createElement('div');
        testDiv.className = 'test-projects-container';
        testDiv.style.cssText = `
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
            margin: 20px 0;
        `;
        
        testDiv.innerHTML = `
            <h3>Тестовые проекты (для демонстрации)</h3>
            <p style="color: #666; margin-bottom: 15px;">Выберите проект для тестирования блока коммуникаций</p>
            <div id="test-projects-list">
                ${testProjects.map(project => `
                    <div class="test-project-item" 
                         data-project-id="${project.id}" 
                         data-project-name="${project.name}"
                         style="padding: 12px; margin: 8px 0; background: white; border: 1px solid #ddd; border-radius: 4px; cursor: pointer;">
                        <strong>${project.name}</strong>
                        <div style="color: #666; font-size: 0.9em;">Автор: ${project.author}</div>
                    </div>
                `).join('')}
            </div>
        `;
        
        container.prepend(testDiv);
        
        // Добавляем обработчики для тестовых проектов
        document.querySelectorAll('.test-project-item').forEach(item => {
            item.addEventListener('click', function() {
                document.querySelectorAll('.test-project-item').forEach(el => {
                    el.style.backgroundColor = 'white';
                });
                this.style.backgroundColor = '#e8f5e9';
                
                CommunicationsManager.setSelectedItem(
                    this.dataset.projectId,
                    this.dataset.projectName,
                    { author_id: 1 }
                );
            });
        });
    }
    
    function checkAuthStatus() {
        const userData = localStorage.getItem('user_data');
        if (!userData) {
            console.log('⚠️ Пользователь не авторизован');
            
            // Создаем уведомление
            const authNotice = document.createElement('div');
            authNotice.style.cssText = `
                position: fixed;
                bottom: 20px;
                right: 20px;
                background: #ff9800;
                color: white;
                padding: 10px 15px;
                border-radius: 4px;
                z-index: 10000;
            `;
            authNotice.textContent = 'Для работы с избранным и оценками требуется авторизация';
            document.body.appendChild(authNotice);
            
            setTimeout(() => authNotice.remove(), 5000);
        } else {
            console.log('✅ Пользователь авторизован');
        }
    }
    
    // Тестовые функции для отладки
    window.testProjectsIntegration = {
        selectProject: function(id, name) {
            CommunicationsManager.setSelectedItem(id, name, {author_id: 1});
        },
        getStatus: function() {
            return {
                communications: typeof CommunicationsManager,
                selected: CommunicationsManager ? 'функция есть' : 'нет'
            };
        }
    };
});

// Автоматический вызов при загрузке
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        // Скрипт уже загружен выше
    });
} else {
    // Документ уже загружен
    console.log('📄 Документ уже загружен, запускаем интеграцию');
}