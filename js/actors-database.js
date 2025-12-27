// actors-database.js - Обновленная база данных участников
const ActorsItemBase = (function() {
    const STORAGE_KEY = 'prostvor_actors_database';
    const STATUS_KEY = 'prostvor_last_actor_id';
    
    // Инициализация базы данных
    function init() {
        try {
            const actors = localStorage.getItem(STORAGE_KEY);
            if (!actors) {
                saveActors([]);
            }
            
            // Инициализируем счетчик ID
            if (!localStorage.getItem(STATUS_KEY)) {
                localStorage.setItem(STATUS_KEY, '100000001');
            }
            
            return true;
        } catch (error) {
            console.error('Ошибка инициализации базы данных участников:', error);
            return false;
        }
    }
    
    // Генерация 9-значного ID
    function generateId() {
        try {
            let lastId = parseInt(localStorage.getItem(STATUS_KEY)) || 100000001;
            const newId = lastId.toString().padStart(9, '0');
            lastId++;
            localStorage.setItem(STATUS_KEY, lastId.toString());
            return newId;
        } catch (error) {
            console.error('Ошибка генерации ID:', error);
            return Date.now().toString().slice(-9);
        }
    }
    
    // Валидация email
    function validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
    
    // Валидация телефона
    function validatePhone(phone) {
        if (!phone) return true;
        const phoneRegex = /^[\+]?[0-9\s\-\(\)]+$/;
        return phoneRegex.test(phone);
    }
    
    // Сохранение всех участников
    function saveActors(actors) {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(actors));
            return true;
        } catch (error) {
            console.error('Ошибка сохранения участников:', error);
            return false;
        }
    }
    
    // Получить всех участников
    function getAllActors() {
        try {
            const actors = localStorage.getItem(STORAGE_KEY);
            return actors ? JSON.parse(actors) : [];
        } catch (error) {
            console.error('Ошибка получения участников:', error);
            return [];
        }
    }
    
    // Найти участника по ID
    function findActorById(id) {
        const actors = getAllActors();
        return actors.find(actor => actor.id === id);
    }
    
    // Найти участника по email
    function findActorByEmail(email) {
        const actors = getAllActors();
        return actors.find(actor => actor.email.toLowerCase() === email.toLowerCase());
    }
    
    // Найти участника по псевдониму
    function findActorByNickname(nickname) {
        const actors = getAllActors();
        return actors.find(actor => actor.nickname.toLowerCase() === nickname.toLowerCase());
    }
    
    // Создать нового участника
    function createActor(data) {
        try {
            // Валидация данных
            if (!data.type || !['Человек', 'Сообщество', 'Организация'].includes(data.type)) {
                throw new Error('Неверный тип участника');
            }
            
            if (!data.nickname || data.nickname.trim().length === 0 || data.nickname.length > 12) {
                throw new Error('Псевдоним должен содержать 1-12 символов');
            }
            
            if (!data.email || !validateEmail(data.email)) {
                throw new Error('Введите корректный email');
            }
            
            if (data.telNumber && !validatePhone(data.telNumber)) {
                throw new Error('Введите корректный номер телефона');
            }
            
            if (!data.password || data.password.length < 6) {
                throw new Error('Пароль должен содержать не менее 6 символов');
            }
            
            // Проверка на существующего пользователя
            const existingEmail = findActorByEmail(data.email);
            if (existingEmail) {
                throw new Error('Пользователь с таким email уже существует');
            }
            
            const existingNickname = findActorByNickname(data.nickname);
            if (existingNickname) {
                throw new Error('Пользователь с таким псевдонимом уже существует');
            }
            
            // Создание объекта участника
            const actor = {
                id: generateId(),
                type: data.type,
                nickname: data.nickname.trim(),
                gender: data.type === 'Человек' ? data.gender : null,
                email: data.email.toLowerCase(),
                telNumber: data.telNumber || null,
                name: data.type === 'Человек' ? data.name || null : null,
                surname: data.type === 'Человек' ? data.surname || null : null,
                patronymic: data.type === 'Человек' ? data.patronymic || null : null,
                organizationName: data.type === 'Организация' ? data.organizationName || null : null,
                communityName: data.type === 'Сообщество' ? data.communityName || null : null,
                statusOfActor: data.statusOfActor || 'Участник',
                password: data.password,
                registrationDate: new Date().toISOString(),
                lastLogin: null,
                city: data.city || null
            };
            
            // Сохранение в базе данных
            const actors = getAllActors();
            actors.push(actor);
            saveActors(actors);
            
            return actor;
        } catch (error) {
            console.error('Ошибка создания участника:', error);
            throw error;
        }
        
         // Генерация случайного цвета рамки при регистрации
        const frameColors = [
            '#A8E40A', // основной зелёный сайта
            '#00B0F0', // голубой
            '#FF6B6B', // красный
            '#4ECDC4', // бирюзовый
            '#FFD166', // жёлтый
            '#06D6A0', // зелёный
            '#118AB2', // синий
            '#EF476F', // розовый
            '#9D4EDD', // фиолетовый
            '#FF9E00'  // оранжевый
        ];
        
        const randomColor = frameColors[Math.floor(Math.random() * frameColors.length)];
        
        const newActor = {
            id: generateId(),
            type: actorData.type || 'Человек',
            nickname: actorData.nickname,
            email: actorData.email,
            telNumber: actorData.telNumber || null,
            password: actorData.password,
            registrationDate: new Date().toISOString(),
            statusOfActor: actorData.statusOfActor || 'Участник',
            // Добавляем цвет рамки
            frameColor: randomColor,
            // Добавляем специфичные поля
            ...(actorData.type === 'Человек' && {
                gender: actorData.gender,
                name: actorData.name,
                surname: actorData.surname,
                patronymic: actorData.patronymic,
                city: actorData.city
            }),
            ...(actorData.type === 'Организация' && {
                organizationName: actorData.organizationName,
                city: actorData.city
            }),
            ...(actorData.type === 'Сообщество' && {
                communityName: actorData.communityName,
                city: actorData.city
            })
        };
    }
    
    // Аутентификация пользователя
    function authenticate(login, password) {
        try {
            const actors = getAllActors();
            
            // Ищем пользователя по email или nickname
            const actor = actors.find(a => 
                a.email.toLowerCase() === login.toLowerCase() || 
                a.nickname.toLowerCase() === login.toLowerCase()
            );
            
            if (!actor) {
                throw new Error('Пользователь не найден');
            }
            
            if (actor.password !== password) {
                throw new Error('Неверный пароль');
            }
            
            // Обновляем дату последнего входа
            actor.lastLogin = new Date().toISOString();
            const allActors = getAllActors();
            const index = allActors.findIndex(a => a.id === actor.id);
            if (index !== -1) {
                allActors[index] = actor;
                saveActors(allActors);
            }
            
            return actor;
        } catch (error) {
            console.error('Ошибка аутентификации:', error);
            throw error;
        }
    }
    
    // Обновить статус участника
    function updateActorStatus(id, status) {
        try {
            const validStatuses = [
                'Участник',
                'Участник проекта',
                'Администратор проекта',
                'Руководитель проекта',
                'Проектный куратор',
                'Региональный куратор направления',
                'Куратор направления',
                'Руководитель локального ТЦ',
                'Руководитель ТЦ'
            ];
            
            if (!validStatuses.includes(status)) {
                throw new Error('Неверный статус участника');
            }
            
            const actors = getAllActors();
            const actorIndex = actors.findIndex(actor => actor.id === id);
            
            if (actorIndex === -1) {
                throw new Error('Участник не найден');
            }
            
            actors[actorIndex].statusOfActor = status;
            saveActors(actors);
            
            return actors[actorIndex];
        } catch (error) {
            console.error('Ошибка обновления статуса:', error);
            throw error;
        }
    }
    
    // Обновить информацию об участнике
    function updateActor(id, updates) {
        try {
            const actors = getAllActors();
            const actorIndex = actors.findIndex(actor => actor.id === id);
            
            if (actorIndex === -1) {
                throw new Error('Участник не найден');
            }
            
            // Обновляем только разрешенные поля
            const allowedUpdates = [
                'nickname', 'gender', 'telNumber', 'name', 'surname', 
                'patronymic', 'organizationName', 'communityName', 'city'
            ];
            
            allowedUpdates.forEach(field => {
                if (updates[field] !== undefined) {
                    actors[actorIndex][field] = updates[field];
                }
            });
            
            saveActors(actors);
            
            return actors[actorIndex];
        } catch (error) {
            console.error('Ошибка обновления участника:', error);
            throw error;
        }
    }
    
    // Удалить участника
    function deleteActor(id) {
        try {
            const actors = getAllActors();
            const filteredActors = actors.filter(actor => actor.id !== id);
            saveActors(filteredActors);
            
            return true;
        } catch (error) {
            console.error('Ошибка удаления участника:', error);
            throw error;
        }
    }
    
    // Получить статистику
    function getStatistics() {
        const actors = getAllActors();
        const statistics = {
            total: actors.length,
            byType: {
                'Человек': 0,
                'Организация': 0,
                'Сообщество': 0
            },
            byStatus: {}
        };
        
        actors.forEach(actor => {
            statistics.byType[actor.type] = (statistics.byType[actor.type] || 0) + 1;
            statistics.byStatus[actor.statusOfActor] = (statistics.byStatus[actor.statusOfActor] || 0) + 1;
        });
        
        return statistics;
    }
    
    // Поиск участников
    function searchActors(query, filters = {}) {
        const actors = getAllActors();
        const lowerQuery = query ? query.toLowerCase() : '';
        
        return actors.filter(actor => {
            // Поиск по тексту
            const matchesText = !lowerQuery || 
                actor.nickname.toLowerCase().includes(lowerQuery) ||
                (actor.name && actor.name.toLowerCase().includes(lowerQuery)) ||
                (actor.surname && actor.surname.toLowerCase().includes(lowerQuery)) ||
                (actor.email && actor.email.toLowerCase().includes(lowerQuery)) ||
                (actor.organizationName && actor.organizationName.toLowerCase().includes(lowerQuery)) ||
                (actor.communityName && actor.communityName.toLowerCase().includes(lowerQuery));
            
            // Фильтрация по типу
            const matchesType = !filters.type || actor.type === filters.type;
            
            // Фильтрация по статусу
            const matchesStatus = !filters.status || actor.statusOfActor === filters.status;
            
            // Фильтрация по городу
            const matchesCity = !filters.city || actor.city === filters.city;
            
            return matchesText && matchesType && matchesStatus && matchesCity;
        });
    }
    
    // Инициализация при загрузке
    init();
    
    // Публичные методы
    return {
        getAllActors,
        findActorById,
        findActorByEmail,
        findActorByNickname,
        createActor,
        authenticate,
        updateActorStatus,
        updateActor,
        deleteActor,
        getStatistics,
        searchActors
    };
})();