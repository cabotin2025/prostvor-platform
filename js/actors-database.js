// actors-database.js - База данных участников в формате таблицы "actors"
const ActorsDatabase = (function() {
    const STORAGE_KEY = 'prostvor_actors_database';
    const ID_COUNTER_KEY = 'prostvor_last_actor_id';
    
    // Статусы участников из таблицы "actors"
    const ACTOR_STATUSES = [
        'Руководитель ТЦ',
        'Куратор направления', 
        'Проектный куратор',
        'Руководитель проекта',
        'Администратор проекта',
        'Участник проекта',
        'Участник ТЦ'
    ];
    
    // Типы участников из таблицы "actors"
    const ACTOR_TYPES = ['Человек', 'Сообщество', 'Организация'];
    
    // Основная база данных участников
    let actors = [];
    
    // Цвета рамок для аватаров (случайный выбор при регистрации)
    const FRAME_COLORS = [
        '#A8E40A', '#00B0F0', '#FF6B6B', '#4ECDC4', '#FFD166',
        '#06D6A0', '#118AB2', '#EF476F', '#9D4EDD', '#FF9E00'
    ];
    
    // =============== ИНИЦИАЛИЗАЦИЯ ===============
    
    /**
     * Инициализация базы данных
     * @returns {boolean} Успешность инициализации
     */
    function init() {
        try {
            const stored = localStorage.getItem(STORAGE_KEY);
            if (stored) {
                actors = JSON.parse(stored);
            } else {
                // Начальные данные
                actors = [
                    {
                        ActorID: '100000001',
                        ActorNikname: 'Администратор',
                        ActorStatus: ['Руководитель ТЦ'],
                        ActorType: 'Человек',
                        ActorDirection: [1, 2, 3], // Пример: ID направлений
                        ActorLocacity: 'Улан-Удэ',
                        ActorKeywords: 'админ, управление, администрирование',
                        ActorAccount: '123456789012',
                        frameColor: '#A8E40A',
                        registrationDate: '2024-01-01T00:00:00.000Z'
                    },
                    {
                        ActorID: '100000002',
                        ActorNikname: 'ДизайнерПро',
                        ActorStatus: ['Участник проекта'],
                        ActorType: 'Человек',
                        ActorDirection: [18, 19, 20], // Графический дизайн
                        ActorLocacity: 'Москва',
                        ActorKeywords: 'дизайн, графика, UI/UX',
                        ActorAccount: '234567890123',
                        frameColor: '#00B0F0',
                        registrationDate: '2024-02-15T10:30:00.000Z'
                    },
                    {
                        ActorID: '100000003',
                        ActorNikname: 'Киностудия',
                        ActorType: 'Организация',
                        ActorStatus: ['Руководитель проекта'],
                        ActorDirection: [1, 2, 4, 5], // Кино, телевидение
                        ActorLocacity: 'Санкт-Петербург',
                        ActorKeywords: 'кино, производство, видео',
                        ActorAccount: '345678901234',
                        registrationDate: '2024-03-20T14:45:00.000Z'
                    }
                ];
                saveToStorage();
            }
            
            // Инициализация счетчика ID
            if (!localStorage.getItem(ID_COUNTER_KEY)) {
                localStorage.setItem(ID_COUNTER_KEY, '100000004');
            }
            
            console.log(`✅ ActorsDatabase инициализирована. Участников: ${actors.length}`);
            return true;
        } catch (error) {
            console.error('❌ Ошибка инициализации ActorsDatabase:', error);
            actors = [];
            return false;
        }
    }
    
    // =============== СЛУЖЕБНЫЕ ФУНКЦИИ ===============
    
    /**
     * Сохранение данных в localStorage
     */
    function saveToStorage() {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(actors));
        } catch (error) {
            console.error('Ошибка сохранения данных:', error);
        }
    }
    
    /**
     * Генерация нового ActorID
     * @returns {string} Новый ID участника
     */
    function generateActorID() {
        try {
            let lastId = parseInt(localStorage.getItem(ID_COUNTER_KEY)) || 100000004;
            const newId = lastId.toString();
            lastId++;
            localStorage.setItem(ID_COUNTER_KEY, lastId.toString());
            return newId;
        } catch (error) {
            console.error('Ошибка генерации ActorID:', error);
            return Date.now().toString().slice(-9);
        }
    }
    
    /**
     * Генерация номера счёта (12 цифр)
     * @returns {string} Номер счёта
     */
    function generateAccountNumber() {
        return Math.floor(100000000000 + Math.random() * 900000000000).toString();
    }
    
    /**
     * Получение случайного цвета рамки
     * @returns {string} HEX-цвет
     */
    function getRandomFrameColor() {
        return FRAME_COLORS[Math.floor(Math.random() * FRAME_COLORS.length)];
    }
    
    /**
     * Валидация email
     * @param {string} email - Email для проверки
     * @returns {boolean} Валидность email
     */
    function validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
    
    /**
     * Валидация данных участника
     * @param {Object} actorData - Данные участника
     * @returns {Object} Результат валидации {valid: boolean, errors: Array}
     */
    function validateActorData(actorData) {
        const errors = [];
        
        // Проверка типа
        if (!actorData.ActorType || !ACTOR_TYPES.includes(actorData.ActorType)) {
            errors.push(`Неверный ActorType. Допустимые: ${ACTOR_TYPES.join(', ')}`);
        }
        
        // Проверка псевдонима
        if (!actorData.ActorNikname || actorData.ActorNikname.trim().length === 0) {
            errors.push('ActorNikname обязателен');
        } else if (actorData.ActorNikname.length > 50) {
            errors.push('ActorNikname не более 50 символов');
        }
        
        // Проверка статусов
        if (actorData.ActorStatus && Array.isArray(actorData.ActorStatus)) {
            actorData.ActorStatus.forEach(status => {
                if (!ACTOR_STATUSES.includes(status)) {
                    errors.push(`Неверный статус: ${status}`);
                }
            });
        } else if (actorData.ActorStatus && !ACTOR_STATUSES.includes(actorData.ActorStatus)) {
            errors.push(`Неверный статус: ${actorData.ActorStatus}`);
        }
        
        // Проверка уникальности псевдонима
        if (actorData.ActorNikname) {
            const existing = findActorByNickname(actorData.ActorNikname);
            if (existing && existing.ActorID !== actorData.ActorID) {
                errors.push('Участник с таким псевдонимом уже существует');
            }
        }
        
        // Проверка email (если есть)
        if (actorData.email && !validateEmail(actorData.email)) {
            errors.push('Неверный формат email');
        }
        
        return {
            valid: errors.length === 0,
            errors: errors
        };
    }
    
    // =============== ОСНОВНЫЕ МЕТОДЫ CRUD ===============
    
    /**
     * Получить всех участников
     * @returns {Array} Массив всех участников
     */
    function getAllActors() {
        return [...actors];
    }
    
    /**
     * Найти участника по ID
     * @param {string|number} actorId - ID участника
     * @returns {Object|null} Объект участника или null
     */
    function findActorById(actorId) {
        return actors.find(actor => actor.ActorID === actorId.toString());
    }
    
    /**
     * Найти участника по псевдониму
     * @param {string} nickname - Псевдоним участника
     * @returns {Object|null} Объект участника или null
     */
    function findActorByNickname(nickname) {
        return actors.find(actor => 
            actor.ActorNikname.toLowerCase() === nickname.toLowerCase()
        );
    }
    
    /**
     * Найти участников по email
     * @param {string} email - Email участника
     * @returns {Array} Массив участников с таким email
     */
    function findActorsByEmail(email) {
        return actors.filter(actor => 
            actor.email && actor.email.toLowerCase() === email.toLowerCase()
        );
    }
    
    /**
     * Создать нового участника
     * @param {Object} actorData - Данные нового участника
     * @returns {Object} Созданный участник
     */
    function createActor(actorData) {
        try {
            // Валидация данных
            const validation = validateActorData(actorData);
            if (!validation.valid) {
                throw new Error(validation.errors.join(', '));
            }
            
            // Создание объекта участника
            const newActor = {
                ActorID: generateActorID(),
                ActorNikname: actorData.ActorNikname.trim(),
                ActorStatus: Array.isArray(actorData.ActorStatus) ? 
                    actorData.ActorStatus : [actorData.ActorStatus || 'Участник ТЦ'],
                ActorType: actorData.ActorType,
                ActorDirection: actorData.ActorDirection || [],
                ActorLocacity: actorData.ActorLocacity || null,
                ActorKeywords: actorData.ActorKeywords || '',
                ActorAccount: actorData.ActorAccount || generateAccountNumber(),
                frameColor: getRandomFrameColor(),
                registrationDate: new Date().toISOString(),
                lastLogin: null
            };
            
            // Дополнительные поля в зависимости от типа
            if (actorData.ActorType === 'Человек') {
                newActor.gender = actorData.gender || null;
                newActor.name = actorData.name || null;
                newActor.surname = actorData.surname || null;
                newActor.patronymic = actorData.patronymic || null;
                newActor.birthDate = actorData.birthDate || null;
            } else if (actorData.ActorType === 'Организация') {
                newActor.organizationName = actorData.organizationName || null;
                newActor.inn = actorData.inn || null;
                newActor.ogrn = actorData.ogrn || null;
            } else if (actorData.ActorType === 'Сообщество') {
                newActor.communityName = actorData.communityName || null;
                newActor.memberCount = actorData.memberCount || null;
            }
            
            // Контактные данные (если предоставлены)
            if (actorData.email) newActor.email = actorData.email.toLowerCase();
            if (actorData.phone) newActor.phone = actorData.phone;
            if (actorData.telegram) newActor.telegram = actorData.telegram;
            if (actorData.vk) newActor.vk = actorData.vk;
            
            // Добавление в базу
            actors.push(newActor);
            saveToStorage();
            
            console.log(`✅ Создан новый участник: ${newActor.ActorNikname} (ID: ${newActor.ActorID})`);
            return newActor;
            
        } catch (error) {
            console.error('❌ Ошибка создания участника:', error);
            throw error;
        }
    }
    
    /**
     * Обновить данные участника
     * @param {string} actorId - ID участника
     * @param {Object} updates - Обновляемые поля
     * @returns {Object} Обновлённый участник
     */
    function updateActor(actorId, updates) {
        try {
            const actorIndex = actors.findIndex(actor => actor.ActorID === actorId.toString());
            
            if (actorIndex === -1) {
                throw new Error(`Участник с ID ${actorId} не найден`);
            }
            
            // Создаём копию для валидации
            const tempActor = { ...actors[actorIndex], ...updates };
            const validation = validateActorData(tempActor);
            
            if (!validation.valid) {
                throw new Error(validation.errors.join(', '));
            }
            
            // Обновление разрешённых полей
            const allowedFields = [
                'ActorNikname', 'ActorStatus', 'ActorType', 'ActorDirection',
                'ActorLocacity', 'ActorKeywords', 'frameColor',
                'email', 'phone', 'telegram', 'vk', 'lastLogin'
            ];
            
            // Поля в зависимости от типа
            if (actors[actorIndex].ActorType === 'Человек') {
                allowedFields.push('gender', 'name', 'surname', 'patronymic', 'birthDate');
            } else if (actors[actorIndex].ActorType === 'Организация') {
                allowedFields.push('organizationName', 'inn', 'ogrn');
            } else if (actors[actorIndex].ActorType === 'Сообщество') {
                allowedFields.push('communityName', 'memberCount');
            }
            
            allowedFields.forEach(field => {
                if (updates[field] !== undefined) {
                    actors[actorIndex][field] = updates[field];
                }
            });
            
            // Обновляем дату последнего изменения
            actors[actorIndex].updatedAt = new Date().toISOString();
            
            saveToStorage();
            console.log(`✅ Обновлён участник: ${actors[actorIndex].ActorNikname} (ID: ${actorId})`);
            
            return actors[actorIndex];
            
        } catch (error) {
            console.error('❌ Ошибка обновления участника:', error);
            throw error;
        }
    }
    
    /**
     * Обновить статус участника
     * @param {string} actorId - ID участника
     * @param {string|Array} status - Новый статус
     * @returns {Object} Обновлённый участник
     */
    function updateActorStatus(actorId, status) {
        try {
            const statusArray = Array.isArray(status) ? status : [status];
            
            // Валидация статусов
            statusArray.forEach(s => {
                if (!ACTOR_STATUSES.includes(s)) {
                    throw new Error(`Неверный статус: ${s}. Допустимые: ${ACTOR_STATUSES.join(', ')}`);
                }
            });
            
            return updateActor(actorId, { ActorStatus: statusArray });
            
        } catch (error) {
            console.error('❌ Ошибка обновления статуса:', error);
            throw error;
        }
    }
    
    /**
     * Добавить направление участнику
     * @param {string} actorId - ID участника
     * @param {number} directionId - ID направления
     * @returns {Object} Обновлённый участник
     */
    function addActorDirection(actorId, directionId) {
        try {
            const actor = findActorById(actorId);
            if (!actor) {
                throw new Error(`Участник с ID ${actorId} не найден`);
            }
            
            const currentDirections = Array.isArray(actor.ActorDirection) ? actor.ActorDirection : [];
            
            if (!currentDirections.includes(directionId)) {
                currentDirections.push(directionId);
                return updateActor(actorId, { ActorDirection: currentDirections });
            }
            
            return actor;
            
        } catch (error) {
            console.error('❌ Ошибка добавления направления:', error);
            throw error;
        }
    }
    
    /**
     * Удалить участника
     * @param {string} actorId - ID участника
     * @returns {boolean} Успешность удаления
     */
    function deleteActor(actorId) {
        try {
            const initialLength = actors.length;
            actors = actors.filter(actor => actor.ActorID !== actorId.toString());
            
            if (actors.length === initialLength) {
                throw new Error(`Участник с ID ${actorId} не найден`);
            }
            
            saveToStorage();
            console.log(`✅ Удалён участник с ID: ${actorId}`);
            
            return true;
            
        } catch (error) {
            console.error('❌ Ошибка удаления участника:', error);
            throw error;
        }
    }
    
    // =============== ПОИСК И ФИЛЬТРАЦИЯ ===============
    
    /**
     * Поиск участников по параметрам
     * @param {Object} searchParams - Параметры поиска
     * @returns {Array} Найденные участники
     */
    function searchActors(searchParams = {}) {
        let results = [...actors];
        
        // Фильтрация по псевдониму
        if (searchParams.nickname) {
            const nicknameLower = searchParams.nickname.toLowerCase();
            results = results.filter(actor => 
                actor.ActorNikname.toLowerCase().includes(nicknameLower)
            );
        }
        
        // Фильтрация по типу
        if (searchParams.type) {
            results = results.filter(actor => actor.ActorType === searchParams.type);
        }
        
        // Фильтрация по статусу
        if (searchParams.status) {
            results = results.filter(actor => {
                if (Array.isArray(actor.ActorStatus)) {
                    return actor.ActorStatus.includes(searchParams.status);
                }
                return actor.ActorStatus === searchParams.status;
            });
        }
        
        // Фильтрация по местоположению
        if (searchParams.locacity) {
            results = results.filter(actor => 
                actor.ActorLocacity && 
                actor.ActorLocacity.toLowerCase() === searchParams.locacity.toLowerCase()
            );
        }
        
        // Фильтрация по направлению
        if (searchParams.directionId) {
            results = results.filter(actor => 
                Array.isArray(actor.ActorDirection) && 
                actor.ActorDirection.includes(searchParams.directionId)
            );
        }
        
        // Фильтрация по ключевым словам
        if (searchParams.keywords) {
            const keywords = searchParams.keywords.toLowerCase().split(',').map(k => k.trim());
            results = results.filter(actor => {
                if (!actor.ActorKeywords) return false;
                const actorKeywords = actor.ActorKeywords.toLowerCase();
                return keywords.every(keyword => actorKeywords.includes(keyword));
            });
        }
        
        // Сортировка
        if (searchParams.sortBy) {
            const sortField = searchParams.sortBy;
            const sortOrder = searchParams.sortOrder === 'desc' ? -1 : 1;
            
            results.sort((a, b) => {
                if (a[sortField] < b[sortField]) return -1 * sortOrder;
                if (a[sortField] > b[sortField]) return 1 * sortOrder;
                return 0;
            });
        }
        
        // Пагинация
        if (searchParams.limit) {
            const offset = searchParams.offset || 0;
            results = results.slice(offset, offset + searchParams.limit);
        }
        
        return results;
    }
    
    /**
     * Получить участников по статусу
     * @param {string} status - Статус участника
     * @returns {Array} Участники с указанным статусом
     */
    function getActorsByStatus(status) {
        return actors.filter(actor => {
            if (Array.isArray(actor.ActorStatus)) {
                return actor.ActorStatus.includes(status);
            }
            return actor.ActorStatus === status;
        });
    }
    
    /**
     * Получить участников по типу
     * @param {string} type - Тип участника
     * @returns {Array} Участники указанного типа
     */
    function getActorsByType(type) {
        return actors.filter(actor => actor.ActorType === type);
    }
    
    /**
     * Получить участников по местоположению
     * @param {string} locacity - Название населённого пункта
     * @returns {Array} Участники в указанном населённом пункте
     */
    function getActorsByLocacity(locacity) {
        return actors.filter(actor => 
            actor.ActorLocacity && 
            actor.ActorLocacity.toLowerCase() === locacity.toLowerCase()
        );
    }
    
    /**
     * Получить участников по направлению
     * @param {number} directionId - ID направления
     * @returns {Array} Участники с указанным направлением
     */
    function getActorsByDirection(directionId) {
        return actors.filter(actor => 
            Array.isArray(actor.ActorDirection) && 
            actor.ActorDirection.includes(directionId)
        );
    }
    
    // =============== СТАТИСТИКА И АНАЛИТИКА ===============
    
    /**
     * Получить статистику по участникам
     * @returns {Object} Статистика
     */
    function getStatistics() {
        const stats = {
            total: actors.length,
            byType: {},
            byStatus: {},
            byLocacity: {},
            registrationsByMonth: {},
            activeCount: 0
        };
        
        // Текущая дата (30 дней назад)
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        
        actors.forEach(actor => {
            // По типу
            stats.byType[actor.ActorType] = (stats.byType[actor.ActorType] || 0) + 1;
            
            // По статусу
            if (Array.isArray(actor.ActorStatus)) {
                actor.ActorStatus.forEach(status => {
                    stats.byStatus[status] = (stats.byStatus[status] || 0) + 1;
                });
            } else {
                stats.byStatus[actor.ActorStatus] = (stats.byStatus[actor.ActorStatus] || 0) + 1;
            }
            
            // По местоположению
            if (actor.ActorLocacity) {
                stats.byLocacity[actor.ActorLocacity] = (stats.byLocacity[actor.ActorLocacity] || 0) + 1;
            }
            
            // Регистрации по месяцам
            if (actor.registrationDate) {
                const date = new Date(actor.registrationDate);
                const monthKey = `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}`;
                stats.registrationsByMonth[monthKey] = (stats.registrationsByMonth[monthKey] || 0) + 1;
            }
            
            // Активные участники (заходили последние 30 дней)
            if (actor.lastLogin && new Date(actor.lastLogin) > thirtyDaysAgo) {
                stats.activeCount++;
            }
        });
        
        return stats;
    }
    
    /**
     * Получить самых активных участников
     * @param {number} limit - Количество участников
     * @returns {Array} Самые активные участники
     */
    function getMostActiveActors(limit = 10) {
        return actors
            .filter(actor => actor.lastLogin)
            .sort((a, b) => new Date(b.lastLogin) - new Date(a.lastLogin))
            .slice(0, limit);
    }
    
    /**
     * Получить последних зарегистрированных участников
     * @param {number} limit - Количество участников
     * @returns {Array} Последние участники
     */
    function getRecentlyRegisteredActors(limit = 10) {
        return actors
            .filter(actor => actor.registrationDate)
            .sort((a, b) => new Date(b.registrationDate) - new Date(a.registrationDate))
            .slice(0, limit);
    }
    
    // =============== АВТОРИЗАЦИЯ И СЕССИИ ===============
    
    /**
     * Аутентификация участника (упрощённая версия)
     * @param {string} login - Логин (email или псевдоним)
     * @param {string} password - Пароль
     * @returns {Object} Объект участника или ошибка
     */
    function authenticate(login, password) {
        try {
            // В реальном приложении здесь было бы хеширование пароля
            // Для демо ищем по email или псевдониму
            const actor = actors.find(a => 
                (a.email && a.email.toLowerCase() === login.toLowerCase()) ||
                a.ActorNikname.toLowerCase() === login.toLowerCase()
            );
            
            if (!actor) {
                throw new Error('Участник не найден');
            }
            
            // В реальном приложении: проверка хеша пароля
            // Для демо: просто проверяем наличие поля password
            if (actor.password && actor.password !== password) {
                throw new Error('Неверный пароль');
            }
            
            // Обновляем дату последнего входа
            updateActor(actor.ActorID, { 
                lastLogin: new Date().toISOString() 
            });
            
            console.log(`✅ Успешная аутентификация: ${actor.ActorNikname}`);
            return actor;
            
        } catch (error) {
            console.error('❌ Ошибка аутентификации:', error);
            throw error;
        }
    }
    
    /**
     * Регистрация нового участника
     * @param {Object} registrationData - Данные для регистрации
     * @returns {Object} Зарегистрированный участник
     */
    function registerActor(registrationData) {
        try {
            // Проверка обязательных полей
            if (!registrationData.email || !registrationData.password) {
                throw new Error('Email и пароль обязательны');
            }
            
            // Проверка уникальности email
            const existingEmail = findActorsByEmail(registrationData.email);
            if (existingEmail.length > 0) {
                throw new Error('Email уже используется');
            }
            
            // Создание участника
            const actorData = {
                ActorNikname: registrationData.nickname || registrationData.email.split('@')[0],
                ActorType: registrationData.type || 'Человек',
                ActorStatus: ['Участник ТЦ'],
                email: registrationData.email,
                password: registrationData.password, // В реальном приложении - хеш
                ActorLocacity: registrationData.locacity || null,
                ...registrationData
            };
            
            return createActor(actorData);
            
        } catch (error) {
            console.error('❌ Ошибка регистрации:', error);
            throw error;
        }
    }
    
    // =============== ЭКСПОРТ И ИНИЦИАЛИЗАЦИЯ ===============
    
    // Автоматическая инициализация при загрузке
    init();
    
    // Публичный интерфейс
    return {
        // Основные методы
        getAllActors,
        findActorById,
        findActorByNickname,
        findActorsByEmail,
        createActor,
        updateActor,
        updateActorStatus,
        addActorDirection,
        deleteActor,
        
        // Поиск и фильтрация
        searchActors,
        getActorsByStatus,
        getActorsByType,
        getActorsByLocacity,
        getActorsByDirection,
        
        // Статистика и аналитика
        getStatistics,
        getMostActiveActors,
        getRecentlyRegisteredActors,
        
        // Авторизация
        authenticate,
        registerActor,
        
        // Вспомогательные методы
        validateActorData,
        
        // Константы
        ACTOR_STATUSES,
        ACTOR_TYPES,
        FRAME_COLORS
    };
})();

// Экспорт для использования в браузере
if (typeof window !== 'undefined') {
    window.ActorsDatabase = ActorsDatabase;
}

// Экспорт для Node.js
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ActorsDatabase;
}

// Сообщение о загрузке
console.log('🎭 ActorsDatabase загружена. Используйте ActorsDatabase.methodName()');
