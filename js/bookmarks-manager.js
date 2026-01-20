/**
 * Менеджер закладок для тем
 */
class BookmarksManager {
    constructor() {
        this.apiBase = '/api/bookmarks';
    }
    
    /**
     * Сохранить/обновить закладку
     * @param {number} themeId - ID темы
     * @param {number|null} discussionId - ID последнего прочитанного комментария
     * @returns {Promise<Object>}
     */
    async saveBookmark(themeId, discussionId = null) {
        try {
            const response = await fetch(`${this.apiBase}/save.php`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${localStorage.getItem('token')}`
                },
                body: JSON.stringify({
                    theme_id: themeId,
                    discussion_id: discussionId
                })
            });
            
            return await response.json();
        } catch (error) {
            console.error('Ошибка сохранения закладки:', error);
            return { success: false, error: 'Ошибка сети' };
        }
    }
    
    /**
     * Получить закладку для темы
     * @param {number} themeId - ID темы
     * @returns {Promise<Object>}
     */
    async getBookmark(themeId) {
        try {
            const response = await fetch(`${this.apiBase}/get.php?theme_id=${themeId}`, {
                headers: {
                    'Authorization': `Bearer ${localStorage.getItem('token')}`
                }
            });
            
            return await response.json();
        } catch (error) {
            console.error('Ошибка получения закладки:', error);
            return { success: false, error: 'Ошибка сети' };
        }
    }
    
    /**
     * Получить список всех закладок пользователя
     * @returns {Promise<Object>}
     */
    async getUserBookmarks() {
        try {
            const response = await fetch(`${this.apiBase}/list.php`, {
                headers: {
                    'Authorization': `Bearer ${localStorage.getItem('token')}`
                }
            });
            
            return await response.json();
        } catch (error) {
            console.error('Ошибка получения списка закладок:', error);
            return { success: false, error: 'Ошибка сети' };
        }
    }
    
    /**
     * Создать кнопку закладки для вставки на страницу темы
     * @param {number} themeId - ID темы
     * @param {HTMLElement} container - Контейнер для кнопки
     */
    async createBookmarkButton(themeId, container) {
        // Получаем текущее состояние закладки
        const bookmarkState = await this.getBookmark(themeId);
        
        // Создаем элемент кнопки
        const button = document.createElement('button');
        button.className = 'bookmark-btn';
        button.dataset.themeId = themeId;
        button.innerHTML = `
            <i class="bookmark-icon ${bookmarkState.success ? 'bookmarked' : ''}"></i>
            <span>${bookmarkState.success ? 'В закладках' : 'Добавить в закладки'}</span>
        `;
        
        // Обработчик клика
        button.addEventListener('click', async () => {
            // Получаем ID текущего комментария (если на странице обсуждения)
            const currentDiscussionId = this.getCurrentDiscussionId();
            
            const result = await this.saveBookmark(themeId, currentDiscussionId);
            
            if (result.success) {
                button.classList.toggle('bookmarked');
                const span = button.querySelector('span');
                span.textContent = button.classList.contains('bookmarked') 
                    ? 'В закладках' 
                    : 'Добавить в закладки';
                
                // Показываем уведомление
                this.showNotification(result.message || 'Закладка сохранена');
            }
        });
        
        // Добавляем кнопку в контейнер
        container.appendChild(button);
    }
    
    /**
     * Получить ID текущего комментария (если пользователь просматривает обсуждение)
     * @returns {number|null}
     */
    getCurrentDiscussionId() {
        // Реализация зависит от структуры страницы
        // Пример: если комментарии имеют data-discussion-id
        const activeDiscussion = document.querySelector('.discussion-item.active');
        return activeDiscussion ? parseInt(activeDiscussion.dataset.discussionId) : null;
    }
    
    /**
     * Показать уведомление
     * @param {string} message 
     */
    showNotification(message) {
        // Простая реализация уведомления
        const notification = document.createElement('div');
        notification.className = 'bookmark-notification';
        notification.textContent = message;
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: #4CAF50;
            color: white;
            padding: 12px 20px;
            border-radius: 4px;
            z-index: 1000;
            animation: slideIn 0.3s ease;
        `;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }
}

// Глобальный экземпляр менеджера
window.bookmarksManager = new BookmarksManager();