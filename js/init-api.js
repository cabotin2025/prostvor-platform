/**
 * Инициализация API при загрузке страницы
 */

// Ждем загрузки DOM
document.addEventListener('DOMContentLoaded', function() {
    // Проверяем, есть ли API сервис
    if (!window.api) {
        console.error('API service not loaded!');
        return;
    }
    
    // Если пользователь авторизован, обновляем UI
    if (window.api.isAuthenticated()) {
        updateUIForAuthenticatedUser();
    } else {
        updateUIForGuest();
    }
    
    // Настраиваем глобальные обработчики ошибок API
    setupGlobalErrorHandling();
});

function updateUIForAuthenticatedUser() {
    const user = window.api.getCurrentUser();
    
    // Обновляем меню
    const authElements = document.querySelectorAll('.auth-only');
    const guestElements = document.querySelectorAll('.guest-only');
    
    authElements.forEach(el => el.style.display = 'block');
    guestElements.forEach(el => el.style.display = 'none');
    
    // Показываем имя пользователя
    const userNameElements = document.querySelectorAll('.user-name');
    userNameElements.forEach(el => {
        el.textContent = user.nickname || user.email;
    });
    
    // Загружаем данные если на нужной странице
    if (window.location.pathname.includes('Projects.html')) {
        loadProjectsData();
    } else if (window.location.pathname.includes('actors.html')) {
        loadActorsData();
    }
}

function updateUIForGuest() {
    const authElements = document.querySelectorAll('.auth-only');
    const guestElements = document.querySelectorAll('.guest-only');
    
    authElements.forEach(el => el.style.display = 'none');
    guestElements.forEach(el => el.style.display = 'block');
}

function setupGlobalErrorHandling() {
    // Глобальный обработчик ошибок API
    window.addEventListener('unhandledrejection', function(event) {
        if (event.reason && event.reason.message && event.reason.message.includes('401')) {
            // Неавторизован - редирект на вход
            window.location.href = '/pages/enter-reg.html';
        }
    });
}

// Функции загрузки данных для конкретных страниц
async function loadProjectsData() {
    try {
        const result = await window.api.getProjects();
        if (result && result.success) {
            window.dispatchEvent(new CustomEvent('projectsLoaded', { detail: result.projects }));
        }
    } catch (error) {
        console.error('Failed to load projects:', error);
    }
}

async function loadActorsData() {
    try {
        const result = await window.api.getActors();
        if (result && result.success) {
            window.dispatchEvent(new CustomEvent('actorsLoaded', { detail: result.actors }));
        }
    } catch (error) {
        console.error('Failed to load actors:', error);
    }
}