// Менеджер избранного
const FavoritesManager = (function() {
    // Получение избранного
    function getFavorites() {
        try {
            return JSON.parse(localStorage.getItem('user_favorites')) || [];
        } catch (error) {
            console.error('Ошибка загрузки избранного:', error);
            return [];
        }
    }

    // Сохранение избранного
    function saveFavorites(favorites) {
        try {
            localStorage.setItem('user_favorites', JSON.stringify(favorites));
        } catch (error) {
            console.error('Ошибка сохранения избранного:', error);
        }
    }

    // Проверка, находится ли элемент в избранном
    function isFavorite(itemId, itemType) {
        const favorites = getFavorites();
        return favorites.some(fav => 
            fav.itemId === itemId && fav.itemType === itemType
        );
    }

    // Добавление/удаление из избранного
    function toggleFavorite(itemId, itemType, itemName) {
        const favorites = getFavorites();
        const existingIndex = favorites.findIndex(fav => 
            fav.itemId === itemId && fav.itemType === itemType
        );
        
        if (existingIndex > -1) {
            // Удаляем из избранного
            favorites.splice(existingIndex, 1);
            saveFavorites(favorites);
            return false;
        } else {
            // Добавляем в избранное
            favorites.push({
                itemId,
                itemType,
                name: itemName,
                date: new Date().toISOString()
            });
            saveFavorites(favorites);
            return true;
        }
    }

    // Удаление из избранного
    function removeFavorite(itemId, itemType) {
        const favorites = getFavorites();
        const filteredFavorites = favorites.filter(fav => 
            !(fav.itemId === itemId && fav.itemType === itemType)
        );
        saveFavorites(filteredFavorites);
    }

    // Получение количества избранных элементов
    function getFavoritesCount() {
        return getFavorites().length;
    }

    // Получение избранного по типу
    function getFavoritesByType(itemType) {
        const favorites = getFavorites();
        return favorites.filter(fav => fav.itemType === itemType);
    }

    // Очистка всего избранного
    function clearFavorites() {
        saveFavorites([]);
    }

    return {
        getFavorites,
        isFavorite,
        toggleFavorite,
        removeFavorite,
        getFavoritesCount,
        getFavoritesByType,
        clearFavorites
    };
})();