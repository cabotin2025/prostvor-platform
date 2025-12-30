// auth-updated.js - Обновленный модуль аутентификации с поддержкой ActorsDatabase
const AuthUpdated = (function() {
    // Конфигурация
    const config = {
        sessionKey: 'prostvor_auth_session',
        tokenKey: 'prostvor_auth_token',
        userKey: 'prostvor_current_user'
    };

    // Состояние аутентификации
    let authState = {
        isAuthenticated: false,
        currentUser: null,
        token: null
    };

    // Инициализация
    function init() {
        try {
            restoreSession();
            console.log('🔐 AuthUpdated инициализирован');
            return true;
        } catch (error) {
            console.error('Ошибка инициализации AuthUpdated:', error);
            return false;
        }
    }

    // Восстановление сессии
    function restoreSession() {
        try {
            const token = localStorage.getItem(config.tokenKey);
            const userData = sessionStorage.getItem(config.userKey);
            
            if (token && userData) {
                authState.token = token;
                authState.currentUser = JSON.parse(userData);
                authState.isAuthenticated = true;
                console.log('🔐 Сессия восстановлена:', authState.currentUser?.nickname);
                return true;
            }
        } catch (error) {
            console.error('Ошибка восстановления сессии:', error);
        }
        
        authState.isAuthenticated = false;
        authState.currentUser = null;
        authState.token = null;
        return false;
    }

    // Аутентификация пользователя
    function authenticate(login, password) {
        try {
            console.log('🔐 Попытка аутентификации:', login);
            
            // Проверяем доступность ActorsDatabase
            if (typeof ActorsDatabase === 'undefined') {
                throw new Error('База данных участников не загружена');
            }
            
            // Выполняем аутентификацию через ActorsDatabase
            const user = ActorsDatabase.authenticate(login, password);
            
            if (!user) {
                throw new Error('Ошибка аутентификации');
            }
            
            // Создаем токен (в реальном приложении получали бы с сервера)
            const token = generateToken(user.ActorID);
            
            // Подготавливаем данные пользователя для хранения
            const userData = {
                id: user.ActorID,
                nickname: user.ActorNikname,
                type: user.ActorType,
                status: Array.isArray(user.ActorStatus) ? user.ActorStatus[0] : user.ActorStatus,
                locacity: user.ActorLocacity,
                email: user.email || null,
                frameColor: user.frameColor || '#A8E40A',
                registrationDate: user.registrationDate,
                lastLogin: new Date().toISOString()
            };
            
            // Сохраняем сессию
            saveSession(token, userData);
            
            // Обновляем состояние
            authState.isAuthenticated = true;
            authState.currentUser = userData;
            authState.token = token;
            
            console.log('✅ Успешная аутентификация:', user.ActorNikname);
            return {
                success: true,
                user: userData,
                token: token
            };
            
        } catch (error) {
            console.error('❌ Ошибка аутентификации:', error.message);
            
            // Пробуем альтернативный метод (для обратной совместимости)
            return attemptLegacyAuth(login, password) || {
                success: false,
                error: error.message || 'Неверный логин или пароль'
            };
        }
    }

    // Альтернативный метод аутентификации (для обратной совместимости)
    function attemptLegacyAuth(login, password) {
        try {
            // Проверяем наличие локальных данных пользователей
            const users = getLocalUsers();
            const user = users.find(u => 
                (u.email && u.email.toLowerCase() === login.toLowerCase()) ||
                (u.nickname && u.nickname.toLowerCase() === login.toLowerCase())
            );
            
            if (user && user.password === password) {
                console.log('⚠️ Использована локальная аутентификация');
                
                const token = generateToken(user.id || 'local_' + Date.now());
                const userData = {
                    id: user.id || 'local_user',
                    nickname: user.nickname || login,
                    type: 'Человек',
                    status: 'Участник ТЦ',
                    locacity: user.city || 'Улан-Удэ',
                    email: user.email || null,
                    frameColor: user.frameColor || '#A8E40A',
                    registrationDate: user.registrationDate || new Date().toISOString(),
                    lastLogin: new Date().toISOString()
                };
                
                saveSession(token, userData);
                authState.isAuthenticated = true;
                authState.currentUser = userData;
                authState.token = token;
                
                return {
                    success: true,
                    user: userData,
                    token: token,
                    isLocal: true
                };
            }
        } catch (error) {
            console.warn('Локальная аутентификация не удалась:', error);
        }
        
        return null;
    }

    // Регистрация нового пользователя
    function register(registrationData) {
        try {
            console.log('📝 Попытка регистрации:', registrationData.email);
            
            // Проверяем доступность ActorsDatabase
            if (typeof ActorsDatabase === 'undefined') {
                throw new Error('База данных участников не загружена');
            }
            
            // Выполняем регистрацию через ActorsDatabase
            const user = ActorsDatabase.registerActor({
                email: registrationData.email,
                password: registrationData.password,
                nickname: registrationData.nickname || registrationData.email.split('@')[0],
                type: registrationData.type || 'Человек',
                locacity: registrationData.city || 'Улан-Удэ',
                name: registrationData.name,
                surname: registrationData.surname,
                phone: registrationData.phone
            });
            
            // Автоматическая аутентификация после регистрации
            return authenticate(registrationData.email, registrationData.password);
            
        } catch (error) {
            console.error('❌ Ошибка регистрации:', error);
            return {
                success: false,
                error: error.message || 'Ошибка регистрации'
            };
        }
    }

    // Выход из системы
    function logout() {
        try {
            const userName = authState.currentUser?.nickname;
            
            // Очищаем все данные аутентификации
            localStorage.removeItem(config.tokenKey);
            sessionStorage.removeItem(config.userKey);
            sessionStorage.removeItem('current_user');
            sessionStorage.removeItem('current_user_id');
            
            // Сбрасываем состояние
            authState.isAuthenticated = false;
            authState.currentUser = null;
            authState.token = null;
            
            console.log('👋 Пользователь вышел:', userName);
            
            // Перезагружаем страницу
            setTimeout(() => {
                window.location.reload();
            }, 500);
            
            return true;
        } catch (error) {
            console.error('Ошибка при выходе:', error);
            return false;
        }
    }

    // Получить текущего пользователя
    function getCurrentUser() {
        // Если пользователь уже в памяти, возвращаем его
        if (authState.currentUser) {
            return authState.currentUser;
        }
        
        // Пробуем восстановить из sessionStorage
        try {
            const userData = sessionStorage.getItem(config.userKey);
            if (userData) {
                authState.currentUser = JSON.parse(userData);
                authState.isAuthenticated = true;
                return authState.currentUser;
            }
        } catch (error) {
            console.warn('Не удалось восстановить пользователя:', error);
        }
        
        // Пробуем получить из старого формата (для обратной совместимости)
        try {
            const oldUserData = sessionStorage.getItem('current_user');
            if (oldUserData) {
                const oldUser = JSON.parse(oldUserData);
                const userData = {
                    id: oldUser.id || 'legacy_user',
                    nickname: oldUser.nickname || 'Пользователь',
                    type: oldUser.type || 'Человек',
                    status: oldUser.status || 'Участник ТЦ',
                    locacity: oldUser.city || 'Улан-Удэ',
                    email: oldUser.email || null,
                    frameColor: oldUser.frameColor || '#A8E40A'
                };
                
                // Сохраняем в новом формате
                sessionStorage.setItem(config.userKey, JSON.stringify(userData));
                authState.currentUser = userData;
                authState.isAuthenticated = true;
                
                return userData;
            }
        } catch (error) {
            console.warn('Не удалось преобразовать старого пользователя:', error);
        }
        
        return null;
    }

    // Проверить статус аутентификации
    function isAuthenticated() {
        return authState.isAuthenticated || !!getCurrentUser();
    }

    // Получить токен
    function getToken() {
        return authState.token || localStorage.getItem(config.tokenKey);
    }

    // Генерация токена (упрощенная)
    function generateToken(userId) {
        const timestamp = Date.now();
        const random = Math.random().toString(36).substring(2);
        return btoa(`${userId}_${timestamp}_${random}`).replace(/=/g, '');
    }

    // Сохранение сессии
    function saveSession(token, userData) {
        try {
            localStorage.setItem(config.tokenKey, token);
            sessionStorage.setItem(config.userKey, JSON.stringify(userData));
            
            // Также сохраняем для обратной совместимости
            sessionStorage.setItem('current_user', JSON.stringify({
                id: userData.id,
                nickname: userData.nickname,
                statusOfActor: userData.status,
                city: userData.locacity
            }));
            sessionStorage.setItem('current_user_id', userData.id);
            
            console.log('💾 Сессия сохранена:', userData.nickname);
            return true;
        } catch (error) {
            console.error('Ошибка сохранения сессии:', error);
            return false;
        }
    }

    // Получение локальных пользователей (для обратной совместимости)
    function getLocalUsers() {
        try {
            const users = localStorage.getItem('prostvor_local_users');
            return users ? JSON.parse(users) : [];
        } catch (error) {
            return [];
        }
    }

    // Сохранение локальных пользователей
    function saveLocalUser(userData) {
        try {
            const users = getLocalUsers();
            users.push(userData);
            localStorage.setItem('prostvor_local_users', JSON.stringify(users));
            return true;
        } catch (error) {
            console.error('Ошибка сохранения локального пользователя:', error);
            return false;
        }
    }

    // Валидация email
    function validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    // Валидация пароля
    function validatePassword(password) {
        if (!password || password.length < 6) {
            return { valid: false, error: 'Пароль должен содержать не менее 6 символов' };
        }
        return { valid: true, error: null };
    }

    // Обновить данные пользователя
    function updateUser(userId, updates) {
        try {
            if (typeof ActorsDatabase === 'undefined') {
                throw new Error('База данных участников не загружена');
            }
            
            const updatedUser = ActorsDatabase.updateActor(userId, updates);
            
            // Обновляем данные в сессии
            if (authState.currentUser && authState.currentUser.id === userId) {
                authState.currentUser = {
                    ...authState.currentUser,
                    ...updates
                };
                sessionStorage.setItem(config.userKey, JSON.stringify(authState.currentUser));
            }
            
            return {
                success: true,
                user: updatedUser
            };
            
        } catch (error) {
            console.error('Ошибка обновления пользователя:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Проверить существование пользователя по email
    function checkUserExists(email) {
        try {
            if (typeof ActorsDatabase !== 'undefined') {
                const users = ActorsDatabase.findActorsByEmail(email);
                return users.length > 0;
            }
            
            // Проверка в локальных данных
            const users = getLocalUsers();
            return users.some(u => u.email && u.email.toLowerCase() === email.toLowerCase());
            
        } catch (error) {
            console.warn('Ошибка проверки пользователя:', error);
            return false;
        }
    }

    // Публичные методы
    return {
        init,
        authenticate,
        register,
        logout,
        getCurrentUser,
        isAuthenticated,
        getToken,
        validateEmail,
        validatePassword,
        updateUser,
        checkUserExists,
        
        // Для отладки
        getState: () => ({ ...authState })
    };
})();

// Автоматическая инициализация
if (typeof document !== 'undefined') {
    document.addEventListener('DOMContentLoaded', function() {
        setTimeout(() => {
            AuthUpdated.init();
        }, 100);
    });
}

// Экспорт
if (typeof window !== 'undefined') {
    window.AuthUpdated = AuthUpdated;
}
