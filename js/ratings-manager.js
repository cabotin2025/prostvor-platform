// Менеджер оценок
const RatingsManager = (function() {
    // Получение всех оценок
    function getRatings() {
        try {
            return JSON.parse(localStorage.getItem('user_ratings')) || [];
        } catch (error) {
            console.error('Ошибка загрузки оценок:', error);
            return [];
        }
    }

    // Сохранение всех оценок
    function saveRatings(ratings) {
        try {
            localStorage.setItem('user_ratings', JSON.stringify(ratings));
        } catch (error) {
            console.error('Ошибка сохранения оценок:', error);
        }
    }

    // Проверка, оценен ли элемент
    function hasRating(itemId, itemType) {
        const ratings = getRatings();
        return ratings.some(rating => 
            rating.itemId === itemId && rating.itemType === itemType
        );
    }

    // Добавление/удаление оценки
    function toggleRating(itemId, itemType, itemName) {
        const ratings = getRatings();
        const existingIndex = ratings.findIndex(rating => 
            rating.itemId === itemId && rating.itemType === itemType
        );
        
        if (existingIndex > -1) {
            // Удаляем оценку
            ratings.splice(existingIndex, 1);
            saveRatings(ratings);
            return false;
        } else {
            // Добавляем оценку
            ratings.push({
                itemId,
                itemType,
                name: itemName,
                date: new Date().toISOString(),
                value: 1 // Положительная оценка
            });
            saveRatings(ratings);
            return true;
        }
    }

    // Получение оценки элемента
    function getRating(itemId, itemType) {
        const ratings = getRatings();
        return ratings.find(rating => 
            rating.itemId === itemId && rating.itemType === itemType
        );
    }

    // Получение количества оценок пользователя
    function getUserRatingsCount() {
        return getRatings().length;
    }

    // Получение оценок по типу
    function getRatingsByType(itemType) {
        const ratings = getRatings();
        return ratings.filter(rating => rating.itemType === itemType);
    }

    // Глобальные оценки (для всех пользователей)
    function getGlobalRatings(itemId, itemType) {
        try {
            const globalRatings = JSON.parse(localStorage.getItem('global_ratings')) || {};
            const key = `${itemType}_${itemId}`;
            return globalRatings[key] || { count: 0, average: 0 };
        } catch (error) {
            return { count: 0, average: 0 };
        }
    }

    function addGlobalRating(itemId, itemType, value) {
        try {
            const globalRatings = JSON.parse(localStorage.getItem('global_ratings')) || {};
            const key = `${itemType}_${itemId}`;
            
            if (!globalRatings[key]) {
                globalRatings[key] = { count: 0, total: 0, average: 0 };
            }
            
            globalRatings[key].count++;
            globalRatings[key].total += value;
            globalRatings[key].average = globalRatings[key].total / globalRatings[key].count;
            
            localStorage.setItem('global_ratings', JSON.stringify(globalRatings));
        } catch (error) {
            console.error('Ошибка добавления глобальной оценки:', error);
        }
    }

    function removeGlobalRating(itemId, itemType, value) {
        try {
            const globalRatings = JSON.parse(localStorage.getItem('global_ratings')) || {};
            const key = `${itemType}_${itemId}`;
            
            if (globalRatings[key]) {
                globalRatings[key].count--;
                globalRatings[key].total -= value;
                
                if (globalRatings[key].count > 0) {
                    globalRatings[key].average = globalRatings[key].total / globalRatings[key].count;
                } else {
                    delete globalRatings[key];
                }
                
                localStorage.setItem('global_ratings', JSON.stringify(globalRatings));
            }
        } catch (error) {
            console.error('Ошибка удаления глобальной оценки:', error);
        }
    }

    return {
        getRatings,
        hasRating,
        toggleRating,
        getRating,
        getUserRatingsCount,
        getRatingsByType,
        getGlobalRatings,
        addGlobalRating,
        removeGlobalRating
    };
})();