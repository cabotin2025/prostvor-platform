// Пример обновления для загрузки проектов
async function loadProjectsList() {
    try {
        const result = await window.api.getProjects();
        
        if (result && result.success) {
            displayProjects(result.projects);
            updateProjectStats(result.count);
        } else {
            showError('Не удалось загрузить проекты');
        }
    } catch (error) {
        console.error('Error loading projects:', error);
        showError('Ошибка подключения к серверу');
    }
}

function displayProjects(projects) {
    const container = document.getElementById('projects-container');
    if (!container) return;
    
    container.innerHTML = '';
    
    projects.forEach(project => {
        const projectCard = createProjectCard(project);
        container.appendChild(projectCard);
    });
}

function createProjectCard(project) {
    // Ваша существующая логика создания карточки проекта
    const card = document.createElement('div');
    card.className = 'project-card';
    card.innerHTML = `
        <h3>${project.title}</h3>
        <p>${project.description || ''}</p>
        <div class="project-meta">
            <span>Статус: ${project.project_status}</span>
            <span>Автор: ${project.author_name}</span>
        </div>
    `;
    
    return card;
}