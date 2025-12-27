// auth-updated.js - Модуль аутентификации
const AuthUpdated = (function() {
    // Конфигурация
    const config = {
        minPasswordLength: 6,
        currentUserKey: 'prostvor_current_user'
    };

    // Элементы DOM для страницы enter-reg.html
    const elements = {
        // Элементы для входа
        loginField: null,
        passwordField: null,
        rememberMeCheckbox: null,
        loginButton: null,
        forgotPasswordLink: null,
        
        // Элементы для регистрации
        regTypeSelect: null,
        regNickname: null,
        regEmail: null,
        regPhone: null,
        regPassword: null,
        regConfirmPassword: null,
        regAgreementCheckbox: null,
        regButton: null,
        agreementLink: null,
        
        // Дополнительные поля для разных типов
        regGender: null,
        regName: null,
        regSurname: null,
        regPatronymic: null,
        regOrganizationName: null,
        regCommunityName: null,
        regCity: null,
        
        // Общие
        notification: document.getElementById('notification'),
        
        // Элементы для отображения пользователя после входа
        userDisplay: null,
        logoutLink: null
    };

    // Инициализация модуля
    function init() {
        try {
            // Проверяем, авторизован ли пользователь
            const currentUser = getCurrentUser();
            
            if (currentUser) {
                // Если пользователь авторизован, обновляем UI
                updateUIForLoggedInUser(currentUser);
            } else if (window.location.pathname.includes('enter-reg')) {
                // Если на странице входа/регистрации и пользователь не авторизован
                setupElements();
                setupEventListeners();
                setupRegistrationForm();
                checkRememberedUser();
            }
        } catch (error) {
            console.error('Ошибка инициализации модуля аутентификации:', error);
        }
    }

    // Настройка элементов DOM
    function setupElements() {
        // Элементы для входа
        elements.loginField = document.getElementById('loginField');
        elements.passwordField = document.getElementById('passwordField');
        elements.rememberMeCheckbox = document.getElementById('rememberMeCheckbox');
        elements.loginButton = document.getElementById('loginButton');
        elements.forgotPasswordLink = document.getElementById('forgotPasswordLink');
        
        // Элементы для регистрации
        elements.regTypeSelect = document.querySelector('.gender-select');
        elements.regNickname = document.getElementById('regNickname');
        elements.regEmail = document.getElementById('regEmail');
        elements.regPhone = document.getElementById('regPhone');
        elements.regPassword = document.getElementById('regPassword');
        elements.regConfirmPassword = document.getElementById('regConfirmPassword');
        elements.regAgreementCheckbox = document.getElementById('regAgreementCheckbox');
        elements.regButton = document.getElementById('regButton');
        elements.agreementLink = document.getElementById('agreementLink');
        
        // Находим дополнительные элементы
        const container = document.querySelector('.auth-section:last-child');
        if (container) {
            // Поля для человека
            elements.regGender = container.querySelector('.gender-select');
            elements.regName = container.querySelector('input[name="name"]');
            elements.regPatronymic = container.querySelector('input[name="patronymic"]');
            elements.regSurname = container.querySelector('input[name="surname"]');
                        
            // Поля для организации/сообщества будут добавлены динамически
        }
    }

    // Настройка формы регистрации
function setupRegistrationForm() {
    if (!elements.regTypeSelect) return;
    
    // Обработчик изменения типа участника
    elements.regTypeSelect.addEventListener('change', function() {
        updateRegistrationForm(this.value);
    });
    
    // Инициализируем форму с выбранным типом
    updateRegistrationForm(elements.regTypeSelect.value);
}

// Обновление формы регистрации в зависимости от типа
function updateRegistrationForm(type) {
    const dynamicFields = document.getElementById('dynamicFields');
    if (!dynamicFields) return;
    
    // Очищаем предыдущие поля
    dynamicFields.innerHTML = '';
    
    switch(type) {
        case 'Человек':
            dynamicFields.innerHTML = `
                <div class="form-group">
                    <label class="form-label" for="regGender">Пол</label>
                    <div class="select-wrapper">
                        <select class="gender-select" id="regGender" name="gender">
                            <option value="муж.">Мужской</option>
                            <option value="жен.">Женский</option>
                        </select>
                    </div>
                </div>
                <div class="form-group">
                    <label class="form-label" for="regName">Имя</label>
                    <input type="text" class="form-input" id="regName" name="name" placeholder="Введите ваше имя">
                </div>
                <div class="form-group">
                    <label class="form-label" for="regPatronymic">Отчество</label>
                    <input type="text" class="form-input" id="regPatronymic" name="patronymic" placeholder="Введите ваше отчество">
                </div>
                <div class="form-group">
                    <label class="form-label" for="regSurname">Фамилия</label>
                    <input type="text" class="form-input" id="regSurname" name="surname" placeholder="Введите вашу фамилию">
                </div>
                <div class="form-group">
                    <label class="form-label" for="regCity">Город</label>
                    <input type="text" class="form-input" id="regCity" name="city" placeholder="Ваш город" list="citiesList">
                    <datalist id="citiesList">
                        <option value="Москва">
                        <option value="Санкт-Петербург">
                        <option value="Улан-Удэ">
                        <!-- Добавьте другие города -->
                    </datalist>
                </div>
            `;
            break;
            
        case 'Организация':
            dynamicFields.innerHTML = `
                <div class="form-group">
                    <label class="form-label" for="regOrganizationName">Название организации *</label>
                    <input type="text" class="form-input" id="regOrganizationName" name="organizationName" 
                           placeholder="Введите название организации" required>
                </div>
                <div class="form-group">
                    <label class="form-label" for="regCity">Город</label>
                    <input type="text" class="form-input" id="regCity" name="city" placeholder="Город организации" list="citiesList">
                    <datalist id="citiesList">
                        <option value="Москва">
                        <option value="Санкт-Pетербург">
                        <option value="Улан-Удэ">
                    </datalist>
                </div>
            `;
            break;
            
        case 'Сообщество':
            dynamicFields.innerHTML = `
                <div class="form-group">
                    <label class="form-label" for="regCommunityName">Название сообщества *</label>
                    <input type="text" class="form-input" id="regCommunityName" name="communityName" 
                           placeholder="Введите название сообщества" required>
                </div>
                <div class="form-group">
                    <label class="form-label" for="regCity">Город</label>
                    <input type="text" class="form-input" id="regCity" name="city" placeholder="Город сообщества" list="citiesList">
                    <datalist id="citiesList">
                        <option value="Москва">
                        <option value="Санкт-Петербург">
                        <option value="Улан-Удэ">
                    </datalist>
                </div>
            `;
            break;
    }
    
    // Обновляем ссылки на элементы
    setupElements();
}

// Добавим обработчик изменения типа участника
document.addEventListener('DOMContentLoaded', function() {
    const typeSelect = document.getElementById('regTypeSelect');
    if (typeSelect) {
        typeSelect.addEventListener('change', function() {
            updateRegistrationForm(this.value);
        });
        // Инициализируем форму с текущим значением
        updateRegistrationForm(typeSelect.value);
    }
});


    // Вспомогательная функция для добавления поля формы
    function addFormField(afterElement, id, label, type, options = []) {
        const formGroup = document.createElement('div');
        formGroup.className = 'form-group dynamic-field';
        
        const labelElement = document.createElement('label');
        labelElement.className = 'form-label';
        labelElement.textContent = label;
        labelElement.htmlFor = id;
        
        let inputElement;
        
        if (type === 'select') {
            inputElement = document.createElement('select');
            inputElement.className = 'form-input';
            inputElement.id = id;
            
            options.forEach(option => {
                const optionElement = document.createElement('option');
                optionElement.value = option.value;
                optionElement.textContent = option.text;
                inputElement.appendChild(optionElement);
            });
        } else {
            inputElement = document.createElement('input');
            inputElement.type = type;
            inputElement.className = 'form-input';
            inputElement.id = id;
            inputElement.placeholder = `Введите ${label.toLowerCase()}`;
        }
        
        formGroup.appendChild(labelElement);
        formGroup.appendChild(inputElement);
        
        afterElement.parentNode.insertBefore(formGroup, afterElement.nextSibling);
    }

    // Функция для добавления поля города
    function addCityField(afterElement) {
        const formGroup = document.createElement('div');
        formGroup.className = 'form-group dynamic-field';
        
        const labelElement = document.createElement('label');
        labelElement.className = 'form-label';
        labelElement.textContent = 'Город';
        labelElement.htmlFor = 'regCity';
        
        const inputElement = document.createElement('input');
        inputElement.type = 'text';
        inputElement.className = 'form-input';
        inputElement.id = 'regCity';
        inputElement.placeholder = 'Ваш город';
        inputElement.list = 'citiesList';
        
        const datalist = document.createElement('datalist');
        datalist.id = 'citiesList';
        
        // Добавляем популярные города
        const popularCities = [
            'Москва', 'Санкт-Петербург', 'Новосибирск', 'Екатеринбург', 
            'Казань', 'Нижний Новгород', 'Челябинск', 'Самара',
            'Омск', 'Ростов-на-Дону', 'Уфа', 'Красноярск',
            'Воронеж', 'Пермь', 'Волгоград', 'Улан-Удэ'
        ];
        
        popularCities.forEach(city => {
            const option = document.createElement('option');
            option.value = city;
            datalist.appendChild(option);
        });
        
        formGroup.appendChild(labelElement);
        formGroup.appendChild(inputElement);
        formGroup.appendChild(datalist);
        
        afterElement.parentNode.insertBefore(formGroup, afterElement.nextSibling);
    }

    // Настройка обработчиков событий
    function setupEventListeners() {
        // Кнопка входа
        if (elements.loginButton) {
            elements.loginButton.addEventListener('click', handleLogin);
        }
        
        // Кнопка регистрации
        if (elements.regButton) {
            elements.regButton.addEventListener('click', handleRegistration);
        }
        
        // Ссылка "Не помню пароль"
        if (elements.forgotPasswordLink) {
            elements.forgotPasswordLink.addEventListener('click', handleForgotPassword);
        }
        
        // Ссылка на соглашение
        if (elements.agreementLink) {
            elements.agreementLink.addEventListener('click', handleAgreementClick);
        }
        
        // Проверка паролей при вводе
        if (elements.regPassword && elements.regConfirmPassword) {
            elements.regPassword.addEventListener('input', validatePasswords);
            elements.regConfirmPassword.addEventListener('input', validatePasswords);
        }
    }

    // Проверка запомненного пользователя
    function checkRememberedUser() {
        try {
            const rememberMe = localStorage.getItem('prostvor_remember_me');
            const userData = localStorage.getItem('prostvor_user_data');
            
            if (rememberMe === 'true' && userData) {
                const user = JSON.parse(userData);
                
                if (elements.loginField) {
                    elements.loginField.value = user.login || '';
                }
                
                if (elements.passwordField) {
                    elements.passwordField.value = user.password || '';
                }
                
                if (elements.rememberMeCheckbox) {
                    elements.rememberMeCheckbox.checked = true;
                }
                
                showNotification('Данные для входа загружены', 'info');
            }
        } catch (error) {
            console.error('Ошибка при проверке запомненного пользователя:', error);
        }
    }

    // Обработка входа
    function handleLogin() {
        // Получаем значения полей
        const login = elements.loginField ? elements.loginField.value.trim() : '';
        const password = elements.passwordField ? elements.passwordField.value.trim() : '';
        const rememberMe = elements.rememberMeCheckbox ? elements.rememberMeCheckbox.checked : false;
                
        // Валидация
        if (!login || !password) {
            showNotification('Заполните все обязательные поля', 'warning');
            return;
        }
        
        try {
            // Используем новую базу данных участников
            const actor = ActorsItemBase.authenticate(login, password);
            
            if (actor) {
                // Успешный вход
                if (rememberMe) {
                    // Сохраняем данные для запоминания
                    localStorage.setItem('prostvor_remember_me', 'true');
                    localStorage.setItem('prostvor_user_data', JSON.stringify({
                        login: login,
                        password: password
                    }));
                } else {
                    // Удаляем сохраненные данные
                    localStorage.removeItem('prostvor_remember_me');
                    localStorage.removeItem('prostvor_user_data');
                }
                
                // Сохраняем текущую сессию
                setCurrentUser(actor);
                
                showNotification('Вход выполнен успешно!', 'success');
                
                setTimeout(() => {
                    // Перенаправляем на главную страницу
                    window.location.href = '../index.html';
                }, 1500);
            }
        } catch (error) {
            showNotification(error.message, 'error');
        }
    }

    // Обработка регистрации
    function handleRegistration() {
        // Получаем значения основных полей
        const type = elements.regTypeSelect ? elements.regTypeSelect.value : 'Человек';
        const nickname = elements.regNickname ? elements.regNickname.value.trim() : '';
        const email = elements.regEmail ? elements.regEmail.value.trim() : '';
        const phone = elements.regPhone ? elements.regPhone.value.trim() : '';
        const password = elements.regPassword ? elements.regPassword.value.trim() : '';
        const confirmPassword = elements.regConfirmPassword ? elements.regConfirmPassword.value.trim() : '';
        const agreementAccepted = elements.regAgreementCheckbox ? elements.regAgreementCheckbox.checked : false;
        
        // Валидация обязательных полей
        if (!nickname || !email || !password || !confirmPassword) {
            showNotification('Заполните все обязательные поля', 'warning');
            return;
        }
        
        // Проверка согласия с условиями
        if (!agreementAccepted) {
            showNotification('Необходимо согласиться с условиями регистрации', 'warning');
            return;
        }
        
        // Валидация email
        if (!validateEmail(email)) {
            showNotification('Введите корректный email', 'warning');
            return;
        }
        
        // Валидация пароля
        if (password.length < config.minPasswordLength) {
            showNotification(`Пароль должен содержать не менее ${config.minPasswordLength} символов`, 'warning');
            return;
        }
        
        if (password !== confirmPassword) {
            showNotification('Пароли не совпадают', 'error');
            return;
        }
        
       // Собираем данные в зависимости от типа
        const actorData = {
            type: type,
            nickname: nickname,
            email: email,
            telNumber: phone || null,
            password: password,
            statusOfActor: 'Участник' // По умолчанию
        };
        
        // Добавляем специфичные поля
        if (type === 'Человек') {
            actorData.gender = elements.regGender ? elements.regGender.value : null;
            actorData.name = elements.regName ? elements.regName.value.trim() : null;
            actorData.surname = elements.regSurname ? elements.regSurname.value.trim() : null;
            actorData.patronymic = elements.regPatronymic ? elements.regPatronymic.value.trim() : null;
            actorData.city = elements.regCity ? elements.regCity.value.trim() : null;
        } else if (type === 'Организация') {
            const orgName = elements.regOrganizationName ? elements.regOrganizationName.value.trim() : '';
            if (!orgName) {
                showNotification('Введите название организации', 'warning');
                return;
            }
            actorData.organizationName = orgName;
            actorData.city = elements.regCity ? elements.regCity.value.trim() : null;
        } else if (type === 'Сообщество') {
            const communityName = elements.regCommunityName ? elements.regCommunityName.value.trim() : '';
            if (!communityName) {
                showNotification('Введите название сообщества', 'warning');
                return;
            }
            actorData.communityName = communityName;
            actorData.city = elements.regCity ? elements.regCity.value.trim() : null;
        }
        
        try {
            // Используем новую базу данных участников
            const newActor = ActorsItemBase.createActor(actorData);
            
            // Автоматический вход после регистрации
            setCurrentUser(newActor);
            
            showNotification('Регистрация прошла успешно! Добро пожаловать на PROSTVOR!', 'success');
            
            // Перенаправление на главную страницу
            setTimeout(() => {
                window.location.href = '../index.html';
            }, 2000);
        } catch (error) {
            showNotification(error.message, 'error');
        }
    }

    // Обновление UI для авторизованного пользователя
    function updateUIForLoggedInUser(user) {
        // Находим кнопку входа в шапке
        const enterButton = document.querySelector('.enter-button');
        if (enterButton) {
            // Создаем новый элемент для отображения пользователя
            const userContainer = document.createElement('div');
            userContainer.className = 'user-display-container';
            
            const userDisplay = document.createElement('div');
            userDisplay.className = 'user-display';
            
            const nicknameSpan = document.createElement('span');
            nicknameSpan.className = 'user-nickname';
            nicknameSpan.textContent = user.nickname;
            
            const statusSpan = document.createElement('span');
            statusSpan.className = 'user-status';
            statusSpan.textContent = user.statusOfActor;
            
            userDisplay.appendChild(nicknameSpan);
            userDisplay.appendChild(statusSpan);
            
            const logoutLink = document.createElement('a');
            logoutLink.href = '#';
            logoutLink.className = 'logout-link';
            logoutLink.textContent = 'Выйти';
            logoutLink.style.color = '#00B0F0';
            logoutLink.addEventListener('click', handleLogout);
            
            userContainer.appendChild(userDisplay);
            userContainer.appendChild(logoutLink);
            
            // Заменяем кнопку входа
            enterButton.parentNode.replaceChild(userContainer, enterButton);
            
            // Сохраняем ссылки на элементы
            elements.userDisplay = userDisplay;
            elements.logoutLink = logoutLink;
            
            // Показываем боковые панели
            showSidebarPanels();
        }
    }

    // Обработка выхода
    function handleLogout(e) {
        e.preventDefault();
        logout();
    }

    // Валидация email
    function validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    // Валидация паролей
    function validatePasswords() {
        if (elements.regPassword && elements.regConfirmPassword) {
            const password = elements.regPassword.value;
            const confirmPassword = elements.regConfirmPassword.value;
            
            if (confirmPassword && password !== confirmPassword) {
                elements.regConfirmPassword.style.borderColor = '#F44336';
                elements.regPassword.style.borderColor = '#F44336';
            } else {
                elements.regConfirmPassword.style.borderColor = '#A8E40A';
                elements.regPassword.style.borderColor = '#A8E40A';
            }
        }
    }

    // Обработка восстановления пароля
    function handleForgotPassword(e) {
        e.preventDefault();
        window.location.href = 'RecoveryPass.html';
    }

    // Обработка клика по ссылке на соглашение
    function handleAgreementClick(e) {
        e.preventDefault();
        window.location.href = 'Agreement.html';
    }

    // Управление текущим пользователем
    function setCurrentUser(user) {
        try {
            sessionStorage.setItem(config.currentUserKey, JSON.stringify(user));
        } catch (error) {
            console.error('Ошибка сохранения пользователя:', error);
        }
    }

    function getCurrentUser() {
        try {
            const user = sessionStorage.getItem(config.currentUserKey);
            return user ? JSON.parse(user) : null;
        } catch (error) {
            console.error('Ошибка получения пользователя:', error);
            return null;
        }
    }

    function logout() {
        sessionStorage.removeItem(config.currentUserKey);
        localStorage.removeItem('prostvor_remember_me');
        localStorage.removeItem('prostvor_user_data');
        
        showNotification('Вы вышли из системы', 'info');
        
        // Перезагружаем страницу
        setTimeout(() => {
            window.location.reload();
        }, 1000);
    }

    // Функция для отображения боковых панелей
    function showSidebarPanels() {
        // Эта функция будет реализована в main.js
        if (typeof App !== 'undefined' && App.showSidebarPanels) {
            App.showSidebarPanels();
        }
    }

    // Показать уведомление
    function showNotification(message, type = 'info') {
        if (elements.notification) {
            elements.notification.textContent = message;
            elements.notification.className = `notification ${type} show`;
            
            setTimeout(() => {
                elements.notification.classList.remove('show');
            }, 3000);
        } else {
            alert(message);
        }
    }

    // Публичные методы
    return {
        init: init,
        getCurrentUser: getCurrentUser,
        logout: logout,
        isAuthenticated: function() {
            return !!getCurrentUser();
        },
        updateUIForLoggedInUser: updateUIForLoggedInUser
    };
})();

// Инициализация приложения после загрузки DOM
document.addEventListener('DOMContentLoaded', AuthUpdated.init);