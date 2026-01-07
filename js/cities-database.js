// cities-database.js - заглушка
console.log('📍 cities-database.js загружен (заглушка)');
window.CitiesDatabase = {
    searchCities: function(query) {
        console.log('Поиск городов:', query);
        return ['Москва', 'Санкт-Петербург', 'Улан-Удэ'];
    }
};