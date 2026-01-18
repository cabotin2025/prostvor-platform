// Обработчик для выпадающего меню "Создать новый Проект"
        document.addEventListener('DOMContentLoaded', function() {
            // Находим все пункты "Создать новый Проект" в выпадающих меню
            const dropdownItems = document.querySelectorAll('.dropdown-item');
            dropdownItems.forEach(item => {
                if (item.textContent.trim() === 'Создать новый Проект') {
                    item.addEventListener('click', function(e) {
                        e.preventDefault();
                        handleCreateProjectFromMenu();
                    });
                }
            });
            
            function handleCreateProjectFromMenu() {
                // Проверяем авторизацию
                const currentUser = sessionStorage.getItem('current_user');
                
                if (!currentUser) {
                    // Пользователь не авторизован
                    if (typeof AppUpdatedPanels !== 'undefined' && AppUpdatedPanels.showNotification) {
                        AppUpdatedPanels.showNotification('Создавать Проекты могут только авторизованные Участники', 'warning');
                    } else if (typeof showNotification === 'function') {
                        showNotification('Создавать Проекты могут только авторизованные Участники', 'warning');
                    } else {
                        alert('Создавать Проекты могут только авторизованные Участники');
                    }
                    return;
                }
                
                // Пользователь авторизован - переходим на страницу создания проекта
                window.location.href = 'ProjectMain.html';
            }
        });