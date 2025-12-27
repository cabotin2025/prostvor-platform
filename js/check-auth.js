// check-auth.js
(function() {
    // Проверка авторизации при загрузке страницы
    document.addEventListener('DOMContentLoaded', function() {
        // Проверяем авторизацию
        checkAuth();
        
        // Настраиваем кнопку входа
        setupEnterButton();
    });
    
    function checkAuth() {
        // Проверяем разными способами
        const currentUser = 
            sessionStorage.getItem('current_user') || 
            sessionStorage.getItem('prostvor_current_user') ||
            localStorage.getItem('current_user');
        
        if (currentUser) {
            try {
                const user = JSON.parse(currentUser);
                console.log('Пользователь авторизован:', user.nickname);
                
                // Обновляем UI для авторизованного пользователя
                updateUIForLoggedInUser(user);
                
                return true;
            } catch (error) {
                console.error('Ошибка парсинга пользователя:', error);
                return false;
            }
        }
        
        return false;
    }
    
    function setupEnterButton() {
        const enterButton = document.querySelector('.enter-button');
        if (!enterButton) return;
        
        // Проверяем, авторизован ли пользователь
        const isAuthenticated = checkAuth();
        
        if (isAuthenticated) {
            // Меняем иконку на профиль
            const img = enterButton.querySelector('img');
            if (img) {
                img.src = '../images/user-profile.svg';
                img.alt = 'Профиль пользователя';
            }
            
            // Добавляем обработчик для показа профиля
            enterButton.addEventListener('click', function(e) {
                e.preventDefault();
                showUserProfile();
            });
        } else {
            // Оставляем кнопку входа
            enterButton.addEventListener('click', function(e) {
                e.preventDefault();
                window.location.href = 'enter-reg.html';
            });
        }
    }
    
    function updateUIForLoggedInUser(user) {
        // Можно добавить логику обновления UI
        console.log('Обновление UI для пользователя:', user.nickname);
    }
    
    function showUserProfile() {
        const currentUser = sessionStorage.getItem('current_user');
        if (currentUser) {
            try {
                const user = JSON.parse(currentUser);
                alert(`Псевдоним: ${user.nickname}\nEmail: ${user.email || 'Не указан'}\nСтатус: ${user.statusOfActor || 'Участник'}`);
            } catch {
                alert('Ошибка получения данных пользователя');
            }
        }
    }
})();