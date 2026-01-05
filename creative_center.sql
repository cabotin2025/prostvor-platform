-- ============================================
-- БАЗА ДАННЫХ ТВОРЧЕСКОГО ЦЕНТРА (PostgreSQL)
-- ============================================

-- Устанавливаем расширения
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- Для текстового поиска

-- ============================================
-- 1. БАЗОВЫЕ СПРАВОЧНИКИ
-- ============================================

-- Таблица типов участников
CREATE TABLE actor_types (
    actor_type_id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

INSERT INTO actor_types (actor_type_id, type) VALUES
(1, 'Человек'),
(2, 'Сообщество'),
(3, 'Организация');

-- Таблица статусов участников
CREATE TABLE actor_statuses (
    actor_status_id SERIAL PRIMARY KEY,
    status VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

INSERT INTO actor_statuses (actor_status_id, status) VALUES
(1, 'Руководитель ТЦ'),
(2, 'Куратор направления'),
(3, 'Проектный куратор'),
(4, 'Руководитель проекта'),
(5, 'Администратор проекта'),
(6, 'Участник проекта'),
(7, 'Участник ТЦ');

-- Таблица типов проектов
CREATE TABLE project_types (
    project_type_id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO project_types (project_type_id, type) VALUES
(1, 'Коммерческий'),
(2, 'Некоммерческий');

-- Таблица статусов проектов
CREATE TABLE project_statuses (
    project_status_id SERIAL PRIMARY KEY,
    status VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

INSERT INTO project_statuses (project_status_id, status) VALUES
(1, 'Инициация'),
(2, 'Проверка'),
(3, 'Формирование'),
(4, 'В работе'),
(5, 'Приостановлено'),
(6, 'Завершено');

-- Таблица типов событий
CREATE TABLE event_types (
    event_type_id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO event_types (event_type_id, type) VALUES
(1, 'Публичное'),
(2, 'Непубличное');

-- Таблица типов тем
CREATE TABLE theme_types (
    theme_type_id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO theme_types (theme_type_id, type) VALUES
(1, 'Публичная'),
(2, 'Проектная');

-- Таблица категорий идей
CREATE TABLE idea_categories (
    idea_category_id SERIAL PRIMARY KEY,
    category VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO idea_categories (idea_category_id, category) VALUES
(1, 'Возмездная'),
(2, 'Безвозмездная');

-- Таблица типов идей
CREATE TABLE idea_types (
    idea_type_id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO idea_types (idea_type_id, type) VALUES
(1, 'Коммерческая'),
(2, 'Некоммерческая');

-- Таблица типов задач
CREATE TABLE task_types (
    task_type_id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO task_types (task_type_id, type) VALUES
(1, 'Планируется'),
(2, 'В работе'),
(3, 'Приостановлено'),
(4, 'Завершено');

-- ============================================
-- 2. ОСНОВНЫЕ СУЩНОСТИ
-- ============================================

-- Основная таблица участников
CREATE TABLE actors (
    actor_id SERIAL PRIMARY KEY,
    nickname VARCHAR(100),
    actor_type_id INTEGER NOT NULL REFERENCES actor_types(actor_type_id),
    icon VARCHAR(255),
    keywords TEXT,
    account VARCHAR(12) UNIQUE,
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id),
    updated_by INTEGER REFERENCES actors(actor_id),
    CONSTRAINT unique_human_nickname 
        UNIQUE NULLS NOT DISTINCT (nickname, actor_type_id) 
        WHERE actor_type_id = 1
);

-- Таблица текущих статусов участников
CREATE TABLE actor_current_statuses (
    actor_current_status_id SERIAL PRIMARY KEY,
    actor_id INTEGER NOT NULL REFERENCES actors(actor_id),
    actor_status_id INTEGER NOT NULL REFERENCES actor_statuses(actor_status_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id),
    updated_by INTEGER REFERENCES actors(actor_id)
    -- Убрали UNIQUE, чтобы участник мог иметь несколько статусов
);

-- Таблица населенных пунктов
CREATE TABLE locations (
    location_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50),
    district VARCHAR(100),
    region VARCHAR(100),
    country VARCHAR(100),
    main_postcode VARCHAR(20),
    description TEXT,
    population INTEGER,
    attachment VARCHAR(255)
);

-- Таблица направлений творчества
CREATE TABLE directions (
    direction_id SERIAL PRIMARY KEY,
    type VARCHAR(100),
    subtype VARCHAR(100),
    title VARCHAR(150),
    description TEXT
);

-- Заполняем направления (первые 20 для примера)
INSERT INTO directions (direction_id, type, subtype, title, description) VALUES
(1, 'Аудиовизуальное искусство', 'Кино', 'Художественное кино', 'Создание фильмов с вымышленным сюжетом и актёрской игрой'),
(2, 'Аудиовизуальное искусство', 'Кино', 'Документальное кино', 'Создание фильмов, основанных на реальных событиях и фактах'),
(3, 'Аудиовизуальное искусство', 'Кино', 'Анимационное кино', 'Создание фильмов методом покадровой съёмки рисунков или кукол'),
(4, 'Аудиовизуальное искусство', 'Кино', 'Короткометражное кино', 'Создание фильмов небольшой продолжительности (до 30 минут)'),
(5, 'Аудиовизуальное искусство', 'Кино', 'Научно-популярное кино', 'Создание фильмов, объясняющих научные концепции и явления'),
(6, 'Аудиовизуальное искусство', 'Телевидение', 'Телесериал', 'Создание многосерийных телевизионных произведений'),
(7, 'Аудиовизуальное искусство', 'Телевидение', 'Телешоу', 'Создание развлекательных или информационных телепрограмм'),
(8, 'Аудиовизуальное искусство', 'Телевидение', 'Документальный сериал', 'Создание цикла документальных фильмов на одну тему'),
(9, 'Аудиовизуальное искусство', 'Музыкальные видео', 'Клип', 'Создание видеосопровождения к музыкальным композициям'),
(10, 'Аудиовизуальное искусство', 'Музыкальные видео', 'Концертная съёмка', 'Создание видеозаписей живых музыкальных выступлений'),
(11, 'Архитектура', 'Архитектурное проектирование', 'Жилая архитектура', 'Создание проектов жилых зданий и комплексов'),
(12, 'Архитектура', 'Архитектурное проектирование', 'Общественная архитектура', 'Создание проектов общественных зданий (музеи, театры)'),
(13, 'Архитектура', 'Архитектурное проектирование', 'Промышленная архитектура', 'Создание проектов промышленных зданий и сооружений'),
(14, 'Архитектура', 'Ландшафтная архитектура', 'Парковое проектирование', 'Создание проектов парков и зон отдыха'),
(15, 'Архитектура', 'Ландшафтная архитектура', 'Садовый дизайн', 'Создание проектов частных и общественных садов'),
(16, 'Архитектура', 'Интерьерный дизайн', 'Жилые интерьеры', 'Создание дизайн-проектов жилых помещений'),
(17, 'Архитектура', 'Интерьерный дизайн', 'Коммерческие интерьеры', 'Создание дизайн-проектов офисов, магазинов, ресторанов'),
(18, 'Дизайн', 'Графический дизайн', 'Брендинг', 'Создание визуальной идентификации компаний и продуктов'),
(19, 'Дизайн', 'Графический дизайн', 'Веб-дизайн', 'Создание визуального оформления и интерфейсов сайтов'),
(20, 'Дизайн', 'Графический дизайн', 'Дизайн упаковки', 'Создание дизайна упаковки для товаров и продуктов');

-- Таблица проектов
CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    full_title VARCHAR(200),
    description TEXT,
    author_id INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    director_id INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    tutor_id INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    project_status_id INTEGER REFERENCES project_statuses(project_status_id),
    start_date DATE,
    end_date DATE,
    project_type_id INTEGER REFERENCES project_types(project_type_id),
    account VARCHAR(12) UNIQUE,
    keywords TEXT,
    attachment VARCHAR(255),
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    CONSTRAINT chk_project_dates CHECK (start_date <= end_date)
);

-- Таблица идей
CREATE TABLE ideas (
    idea_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    short_description TEXT,
    full_description TEXT,
    detail_description TEXT,
    idea_category_id INTEGER REFERENCES idea_categories(idea_category_id),
    idea_type_id INTEGER REFERENCES idea_types(idea_type_id),
    actor_id INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    attachment VARCHAR(255),
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Таблица событий
CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    event_type_id INTEGER REFERENCES event_types(event_type_id),
    attachment VARCHAR(255),
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    CONSTRAINT chk_event_times CHECK (start_time <= end_time)
);

-- Таблица локальных событий
CREATE TABLE local_events (
    local_event_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    attachment VARCHAR(255),
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    CONSTRAINT chk_local_event_times CHECK (start_time <= end_time)
);

-- Таблица тем
CREATE TABLE themes (
    theme_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    theme_type_id INTEGER REFERENCES theme_types(theme_type_id),
    actor_id INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    attachment VARCHAR(255),
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- ============================================
-- 3. СВЯЗУЮЩИЕ ТАБЛИЦЫ
-- ============================================

-- Участники-Направления
CREATE TABLE actors_directions (
    actor_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    direction_id INTEGER NOT NULL REFERENCES directions(direction_id) ON DELETE CASCADE,
    PRIMARY KEY (actor_id, direction_id)
);

-- Участники-Локации
CREATE TABLE actors_locations (
    actor_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    location_id INTEGER NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
    PRIMARY KEY (actor_id, location_id)
);

-- Участники-Проекты
CREATE TABLE actors_projects (
    actor_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    project_id INTEGER NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    PRIMARY KEY (actor_id, project_id)
);

-- Идеи-Проекты
CREATE TABLE ideas_projects (
    idea_id INTEGER NOT NULL REFERENCES ideas(idea_id) ON DELETE CASCADE,
    project_id INTEGER NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    PRIMARY KEY (idea_id, project_id)
);

-- Проекты-Направления
CREATE TABLE projects_directions (
    project_id INTEGER NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    direction_id INTEGER NOT NULL REFERENCES directions(direction_id) ON DELETE CASCADE,
    PRIMARY KEY (project_id, direction_id)
);

-- Проекты-Локации
CREATE TABLE projects_locations (
    project_id INTEGER NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    location_id INTEGER NOT NULL REFERENCES locations(location_id) ON DELETE CASCADE,
    PRIMARY KEY (project_id, location_id)
);

-- Проекты-Локальные события
CREATE TABLE projects_local_events (
    project_id INTEGER NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    local_event_id INTEGER NOT NULL REFERENCES local_events(local_event_id) ON DELETE CASCADE,
    PRIMARY KEY (project_id, local_event_id)
);

-- Идеи-Направления
CREATE TABLE ideas_directions (
    idea_id INTEGER NOT NULL REFERENCES ideas(idea_id) ON DELETE CASCADE,
    direction_id INTEGER NOT NULL REFERENCES directions(direction_id) ON DELETE CASCADE,
    PRIMARY KEY (idea_id, direction_id)
);

-- Участники-События
CREATE TABLE actors_events (
    actor_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    event_id INTEGER NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    PRIMARY KEY (actor_id, event_id)
);

-- ============================================
-- 4. ФУНКЦИИ И РЕСУРСЫ
-- ============================================

-- Таблица функций в проектах
CREATE TABLE functions (
    function_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    keywords TEXT
);

-- Заполняем первые 20 функций
INSERT INTO functions (function_id, title, description) VALUES
(1, '3D-моделлер', 'Создает трёхмерные модели для игр, кино, архитектуры.'),
(2, '3D-моделлер игровой', 'Создает 3D-модели персонажей и объектов для игр.'),
(3, '3D-скалптор', 'Создает детализированные 3D-модели методом цифровой лепки.'),
(4, '3D-художник', 'Моделирует трёхмерные объекты, сцены, персонажей.'),
(5, '3D-художник (визуализатор)', 'Создает фотореалистичные визуализации для архитектуры и дизайна.'),
(6, 'Авиамоделист', 'Создает модели летательных аппаратов.'),
(7, 'Администратор', 'Управляет административными процессами, документацией.'),
(8, 'Актёр', 'Исполняет роли в спектаклях, фильмах.'),
(9, 'Актёр кино', 'Снимается в кино, сериалах, рекламе.'),
(10, 'Актёр массовки', 'Участвует в массовых сценах.'),
(11, 'Актер озвучивания', 'Озвучивает персонажей, рекламу, аудиокниги.'),
(12, 'Аналитик', 'Анализирует данные, тренды, эффективность проектов.'),
(13, 'Аниматор', 'Создает анимацию для кино, игр, мультфильмов.'),
(14, 'Аниматор 2D', 'Работает с двумерной анимацией.'),
(15, 'Аниматор 3D', 'Создает трёхмерную анимацию.'),
(16, 'Архитектор', 'Проектирует здания и сооружения.'),
(17, 'Арт-директор', 'Определяет визуальную стратегию проекта.'),
(18, 'Ассистент режиссёра', 'Помогает режиссёру на съёмках/репетициях.'),
(19, 'Бухгалтер', 'Ведёт финансовый учёт и отчётность.'),
(20, 'Ведущий', 'Ведёт мероприятия, концерты, церемонии.');

-- Функции-Направления
CREATE TABLE functions_directions (
    function_id INTEGER NOT NULL REFERENCES functions(function_id) ON DELETE CASCADE,
    direction_id INTEGER NOT NULL REFERENCES directions(direction_id) ON DELETE CASCADE,
    PRIMARY KEY (function_id, direction_id)
);

-- Проекты-Функции
CREATE TABLE projects_functions (
    project_id INTEGER NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    function_id INTEGER NOT NULL REFERENCES functions(function_id) ON DELETE CASCADE,
    PRIMARY KEY (project_id, function_id)
);

-- Таблица типов материальных ресурсов
CREATE TABLE matresource_types (
    matresource_type_id SERIAL PRIMARY KEY,
    category VARCHAR(100),
    sub_category VARCHAR(100),
    title VARCHAR(200)
);

-- Материальные ресурсы
CREATE TABLE matresources (
    matresource_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    matresource_type_id INTEGER REFERENCES matresource_types(matresource_type_id),
    attachment VARCHAR(255),
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Владельцы материальных ресурсов
CREATE TABLE matresource_owners (
    matresource_id INTEGER NOT NULL REFERENCES matresources(matresource_id) ON DELETE CASCADE,
    actor_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    PRIMARY KEY (matresource_id, actor_id)
);

-- Таблица типов финансовых ресурсов
CREATE TABLE finresource_types (
    finresource_type_id SERIAL PRIMARY KEY,
    type VARCHAR(100) NOT NULL UNIQUE
);

INSERT INTO finresource_types (finresource_type_id, type) VALUES
(1, 'Донаты'),
(2, 'Спонсорская помощь'),
(3, 'Целевое финансирование'),
(4, 'Государственное финансирование'),
(5, 'Муниципальное финансирование'),
(6, 'Средства Участника');

-- Финансовые ресурсы
CREATE TABLE finresources (
    finresource_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    finresource_type_id INTEGER REFERENCES finresource_types(finresource_type_id),
    attachment VARCHAR(255),
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Владельцы финансовых ресурсов
CREATE TABLE finresource_owners (
    finresource_id INTEGER NOT NULL REFERENCES finresources(finresource_id) ON DELETE CASCADE,
    actor_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    PRIMARY KEY (finresource_id, actor_id)
);

-- ============================================
-- 5. ШАБЛОНЫ
-- ============================================

CREATE TABLE templates (
    template_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    direction_id INTEGER REFERENCES directions(direction_id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Шаблоны-Функции
CREATE TABLE templates_functions (
    template_id INTEGER NOT NULL REFERENCES templates(template_id) ON DELETE CASCADE,
    function_id INTEGER NOT NULL REFERENCES functions(function_id) ON DELETE CASCADE,
    PRIMARY KEY (template_id, function_id)
);

-- Шаблоны-Материальные ресурсы
CREATE TABLE templates_matresources (
    template_id INTEGER NOT NULL REFERENCES templates(template_id) ON DELETE CASCADE,
    matresource_id INTEGER NOT NULL REFERENCES matresources(matresource_id) ON DELETE CASCADE,
    PRIMARY KEY (template_id, matresource_id)
);

-- Шаблоны-Финансовые ресурсы
CREATE TABLE templates_finresources (
    template_id INTEGER NOT NULL REFERENCES templates(template_id) ON DELETE CASCADE,
    finresource_id INTEGER NOT NULL REFERENCES finresources(finresource_id) ON DELETE CASCADE,
    PRIMARY KEY (template_id, finresource_id)
);

-- ============================================
-- 6. ЛОКАЦИИ И ПЛОЩАДКИ
-- ============================================

CREATE TABLE venue_types (
    venue_type_id SERIAL PRIMARY KEY,
    type VARCHAR(100) NOT NULL UNIQUE
);

INSERT INTO venue_types (venue_type_id, type) VALUES
(1, 'сценическая площадка'),
(2, 'офис'),
(3, 'зал'),
(4, 'помещение');

-- Локации (места проведения)
CREATE TABLE venues (
    venue_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    full_title VARCHAR(300),
    venue_type_id INTEGER REFERENCES venue_types(venue_type_id),
    description TEXT,
    actor_id INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    location_id INTEGER REFERENCES locations(location_id) ON DELETE SET NULL,
    attachment VARCHAR(255),
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Шаблоны-Локации
CREATE TABLE templates_venues (
    template_id INTEGER NOT NULL REFERENCES templates(template_id) ON DELETE CASCADE,
    venue_id INTEGER NOT NULL REFERENCES venues(venue_id) ON DELETE CASCADE,
    PRIMARY KEY (template_id, venue_id)
);

-- Типы сценических площадок
CREATE TABLE stage_types (
    stage_type_id SERIAL PRIMARY KEY,
    type VARCHAR(100) NOT NULL UNIQUE
);

INSERT INTO stage_types (stage_type_id, type) VALUES
(1, 'театральная'),
(2, 'концертная'),
(3, 'многофункциональная');

-- Архитектура площадок
CREATE TABLE stage_architecture (
    stage_architecture_id SERIAL PRIMARY KEY,
    architecture VARCHAR(100) NOT NULL UNIQUE
);

INSERT INTO stage_architecture (stage_architecture_id, architecture) VALUES
(1, 'просцениум (сцена коробка)'),
(2, 'амфитеатр (открытая сцена)'),
(3, 'трансформирующаяся сцена'),
(4, 'Black box (закрытый "черный ящик")');

-- Мобильность площадок
CREATE TABLE stage_mobility (
    stage_mobility_id SERIAL PRIMARY KEY,
    mobility VARCHAR(100) NOT NULL UNIQUE
);

INSERT INTO stage_mobility (stage_mobility_id, mobility) VALUES
(1, 'Стационарная'),
(2, 'Выездная (мобильная)'),
(3, 'Пространственная');

-- Сценические площадки
CREATE TABLE stages (
    stage_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    full_title VARCHAR(300),
    stage_type_id INTEGER REFERENCES stage_types(stage_type_id),
    stage_architecture_id INTEGER REFERENCES stage_architecture(stage_architecture_id),
    stage_mobility_id INTEGER REFERENCES stage_mobility(stage_mobility_id),
    capacity INTEGER CHECK (capacity > 0),
    width DECIMAL(8,2) CHECK (width > 0),
    depth DECIMAL(8,2) CHECK (depth > 0),
    height DECIMAL(8,2) CHECK (height >= 0),
    description TEXT,
    location_id INTEGER REFERENCES locations(location_id) ON DELETE SET NULL,
    attachment VARCHAR(255),
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Связь локаций и площадок
CREATE TABLE venues_stages (
    venue_id INTEGER NOT NULL REFERENCES venues(venue_id) ON DELETE CASCADE,
    stage_id INTEGER NOT NULL REFERENCES stages(stage_id) ON DELETE CASCADE,
    PRIMARY KEY (venue_id, stage_id)
);

-- Аудио оборудование
CREATE TABLE stage_audio (
    stage_audio_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    attachment VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Световое оборудование
CREATE TABLE stage_light (
    stage_light_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    attachment VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Видео оборудование
CREATE TABLE stage_video (
    stage_video_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    attachment VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Оборудование для эффектов
CREATE TABLE stage_effects (
    stage_effects_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    attachment VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Оснащение площадок оборудованием
CREATE TABLE stage_audio_set (
    stage_id INTEGER NOT NULL REFERENCES stages(stage_id) ON DELETE CASCADE,
    stage_audio_id INTEGER NOT NULL REFERENCES stage_audio(stage_audio_id) ON DELETE CASCADE,
    PRIMARY KEY (stage_id, stage_audio_id)
);

CREATE TABLE stage_light_set (
    stage_id INTEGER NOT NULL REFERENCES stages(stage_id) ON DELETE CASCADE,
    stage_light_id INTEGER NOT NULL REFERENCES stage_light(stage_light_id) ON DELETE CASCADE,
    PRIMARY KEY (stage_id, stage_light_id)
);

CREATE TABLE stage_video_set (
    stage_id INTEGER NOT NULL REFERENCES stages(stage_id) ON DELETE CASCADE,
    stage_video_id INTEGER NOT NULL REFERENCES stage_video(stage_video_id) ON DELETE CASCADE,
    PRIMARY KEY (stage_id, stage_video_id)
);

CREATE TABLE stage_effects_set (
    stage_id INTEGER NOT NULL REFERENCES stages(stage_id) ON DELETE CASCADE,
    stage_effects_id INTEGER NOT NULL REFERENCES stage_effects(stage_effects_id) ON DELETE CASCADE,
    PRIMARY KEY (stage_id, stage_effects_id)
);

-- ============================================
-- 7. ДЕТАЛЬНАЯ ИНФОРМАЦИЯ ОБ УЧАСТНИКАХ
-- ============================================

-- Персональная информация
CREATE TABLE persons (
    person_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    patronymic VARCHAR(100),
    last_name VARCHAR(100),
    gender VARCHAR(10) CHECK (gender IN ('муж.', 'жен.')),
    birth_date DATE CHECK (birth_date <= CURRENT_DATE),
    email VARCHAR(255) UNIQUE,
    email_2 VARCHAR(255),
    location_id INTEGER REFERENCES locations(location_id),
    post_code VARCHAR(20),
    address TEXT,
    phone_number VARCHAR(25),
    phone_number_2 VARCHAR(25),
    personal_info TEXT,
    web_page VARCHAR(255),
    whatsapp VARCHAR(25),
    viber VARCHAR(25),
    vk_page VARCHAR(255),
    ok_page VARCHAR(255),
    tt_page VARCHAR(255),
    tg_page VARCHAR(255),
    ig_page VARCHAR(255),
    fb_page VARCHAR(255),
    max_page VARCHAR(255),
    pp_number VARCHAR(20),
    pp_date DATE,
    pp_auth VARCHAR(200),
    inn VARCHAR(12) CHECK (inn ~ '^[0-9]{10,12}$'),
    snils VARCHAR(14) CHECK (snils ~ '^[0-9]{3}-[0-9]{3}-[0-9]{3} [0-9]{2}$'),
    bank_bik VARCHAR(9) CHECK (bank_bik ~ '^[0-9]{9}$'),
    bank_account VARCHAR(30),
    bank_info TEXT,
    ya_account VARCHAR(50),
    wm_account VARCHAR(50),
    pp_account VARCHAR(50),
    qiwi_account VARCHAR(50),
    attachment VARCHAR(255),
    actor_id INTEGER UNIQUE REFERENCES actors(actor_id) ON DELETE CASCADE,
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_email_2_format CHECK (email_2 IS NULL OR email_2 ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_phone_format CHECK (phone_number ~ '^\+?[0-9\s\-\(\)]+$')
);

-- Информация об организациях
CREATE TABLE organizations (
    organization_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    full_title VARCHAR(300),
    email VARCHAR(255) UNIQUE,
    email_2 VARCHAR(255),
    staff_name VARCHAR(100),
    staff_lastname VARCHAR(100),
    location_id INTEGER REFERENCES locations(location_id),
    post_code VARCHAR(20),
    address TEXT,
    phone_number VARCHAR(25),
    phone_number_2 VARCHAR(25),
    dir_name VARCHAR(100),
    dir_lastname VARCHAR(100),
    ogrn VARCHAR(13) CHECK (ogrn ~ '^[0-9]{13}$'),
    inn VARCHAR(10) CHECK (inn ~ '^[0-9]{10}$'),
    kpp VARCHAR(9) CHECK (kpp ~ '^[0-9]{9}$'),
    bank_title VARCHAR(200),
    bank_bik VARCHAR(9) CHECK (bank_bik ~ '^[0-9]{9}$'),
    bank_account VARCHAR(30),
    org_info TEXT,
    vk_page VARCHAR(255),
    ok_page VARCHAR(255),
    tt_page VARCHAR(255),
    tg_page VARCHAR(255),
    ig_page VARCHAR(255),
    fb_page VARCHAR(255),
    max_page VARCHAR(255),
    web_page VARCHAR(255),
    attachment VARCHAR(255),
    actor_id INTEGER UNIQUE REFERENCES actors(actor_id) ON DELETE CASCADE,
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    CONSTRAINT chk_org_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_org_email_2_format CHECK (email_2 IS NULL OR email_2 ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Информация о сообществах
CREATE TABLE communities (
    community_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    full_title VARCHAR(300),
    email VARCHAR(255) UNIQUE,
    email_2 VARCHAR(255),
    participant_name VARCHAR(100),
    participant_lastname VARCHAR(100),
    location_id INTEGER REFERENCES locations(location_id),
    post_code VARCHAR(20),
    address TEXT,
    phone_number VARCHAR(25),
    phone_number_2 VARCHAR(25),
    bank_title VARCHAR(200),
    bank_bik VARCHAR(9) CHECK (bank_bik ~ '^[0-9]{9}$'),
    bank_account VARCHAR(30),
    community_info TEXT,
    vk_page VARCHAR(255),
    ok_page VARCHAR(255),
    tt_page VARCHAR(255),
    tg_page VARCHAR(255),
    ig_page VARCHAR(255),
    fb_page VARCHAR(255),
    max_page VARCHAR(255),
    web_page VARCHAR(255),
    attachment VARCHAR(255),
    actor_id INTEGER UNIQUE REFERENCES actors(actor_id) ON DELETE CASCADE,
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    CONSTRAINT chk_community_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_community_email_2_format CHECK (email_2 IS NULL OR email_2 ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Таблица для учетных паролей
CREATE TABLE actor_credentials (
    actor_id INTEGER PRIMARY KEY REFERENCES actors(actor_id) ON DELETE CASCADE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 8. КОММЕНТАРИИ, ЗАМЕТКИ, СООБЩЕНИЯ
-- ============================================

-- Комментарии в темах
CREATE TABLE theme_comments (
    theme_comment_id SERIAL PRIMARY KEY,
    comment TEXT NOT NULL,
    theme_id INTEGER NOT NULL REFERENCES themes(theme_id) ON DELETE CASCADE,
    actor_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Заметки (общая таблица)
CREATE TABLE notes (
    note_id SERIAL PRIMARY KEY,
    note TEXT NOT NULL,
    author_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Заметки в проектах
CREATE TABLE projects_notes (
    note_id INTEGER NOT NULL REFERENCES notes(note_id) ON DELETE CASCADE,
    project_id INTEGER NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, project_id)
);

-- Заметки об участниках
CREATE TABLE actors_notes (
    note_id INTEGER NOT NULL REFERENCES notes(note_id) ON DELETE CASCADE,
    actor_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, actor_id)
);

-- Заметки об идеях
CREATE TABLE ideas_notes (
    note_id INTEGER NOT NULL REFERENCES notes(note_id) ON DELETE CASCADE,
    idea_id INTEGER NOT NULL REFERENCES ideas(idea_id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, idea_id)
);

-- Заметки о материальных ресурсах
CREATE TABLE matresources_notes (
    note_id INTEGER NOT NULL REFERENCES notes(note_id) ON DELETE CASCADE,
    matresource_id INTEGER NOT NULL REFERENCES matresources(matresource_id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, matresource_id)
);

-- Заметки о событиях
CREATE TABLE events_notes (
    note_id INTEGER NOT NULL REFERENCES notes(note_id) ON DELETE CASCADE,
    event_id INTEGER NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, event_id)
);

-- Услуги
CREATE TABLE services (
    service_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    attachment VARCHAR(255),
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Заметки об услугах
CREATE TABLE services_notes (
    note_id INTEGER NOT NULL REFERENCES notes(note_id) ON DELETE CASCADE,
    service_id INTEGER NOT NULL REFERENCES services(service_id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, service_id)
);

-- Сообщения
CREATE TABLE messages (
    message_id SERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    author_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Сообщения участникам
CREATE TABLE actors_messages (
    message_id INTEGER NOT NULL REFERENCES messages(message_id) ON DELETE CASCADE,
    actor_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    PRIMARY KEY (message_id, actor_id)
);

-- ============================================
-- 9. ЗАДАЧИ И УВЕДОМЛЕНИЯ
-- ============================================

-- Задачи
CREATE TABLE tasks (
    task_id SERIAL PRIMARY KEY,
    task TEXT NOT NULL,
    task_type_id INTEGER REFERENCES task_types(task_type_id),
    due_date DATE,
    priority INTEGER CHECK (priority BETWEEN 1 AND 5),
    deleted_at TIMESTAMPTZ, -- Для мягкого удаления
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Задачи-Участники
CREATE TABLE actors_tasks (
    task_id INTEGER NOT NULL REFERENCES tasks(task_id) ON DELETE CASCADE,
    actor_id INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, actor_id)
);

-- Проекты-Задачи
CREATE TABLE projects_tasks (
    task_id INTEGER NOT NULL REFERENCES tasks(task_id) ON DELETE CASCADE,
    project_id INTEGER NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, project_id)
);

-- Группы в проектах
CREATE TABLE project_groups (
    project_group_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    project_id INTEGER NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    actor_id INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- Задачи в группах проектов
CREATE TABLE group_tasks (
    task_id INTEGER NOT NULL REFERENCES tasks(task_id) ON DELETE CASCADE,
    project_group_id INTEGER NOT NULL REFERENCES project_groups(project_group_id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, project_group_id)
);

-- Уведомления
CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,
    notification TEXT NOT NULL,
    recipient INTEGER NOT NULL REFERENCES actors(actor_id) ON DELETE CASCADE,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL,
    updated_by INTEGER REFERENCES actors(actor_id) ON DELETE SET NULL
);

-- ============================================
-- 10. УЛУЧШЕННАЯ ИНДЕКСАЦИЯ
-- ============================================

-- Индексы для таблицы actors
CREATE INDEX idx_actors_account ON actors(account);
CREATE INDEX idx_actors_type ON actors(actor_type_id);
CREATE INDEX idx_actors_created_at ON actors(created_at);
CREATE INDEX idx_actors_deleted ON actors(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_actors_keywords_gin ON actors USING GIN(keywords gin_trgm_ops);

-- Индексы для таблицы projects
CREATE INDEX idx_projects_status ON projects(project_status_id);
CREATE INDEX idx_projects_type ON projects(project_type_id);
CREATE INDEX idx_projects_author ON projects(author_id);
CREATE INDEX idx_projects_dates ON projects(start_date, end_date);
CREATE INDEX idx_projects_deleted ON projects(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_projects_keywords_gin ON projects USING GIN(keywords gin_trgm_ops);
CREATE INDEX idx_projects_description_gin ON projects USING GIN(to_tsvector('russian', description));
CREATE INDEX idx_projects_title_gin ON projects USING GIN(to_tsvector('russian', title));

-- Индексы для таблицы persons
CREATE INDEX idx_persons_email ON persons(email);
CREATE INDEX idx_persons_actor ON persons(actor_id);
CREATE INDEX idx_persons_phone ON persons(phone_number);
CREATE INDEX idx_persons_deleted ON persons(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_persons_name_gin ON persons USING GIN(to_tsvector('russian', name || ' ' || last_name));

-- Индексы для таблицы events
CREATE INDEX idx_events_date ON events(date);
CREATE INDEX idx_events_type ON events(event_type_id);
CREATE INDEX idx_events_deleted ON events(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_events_title_gin ON events USING GIN(to_tsvector('russian', title));

-- Индексы для таблицы ideas
CREATE INDEX idx_ideas_actor ON ideas(actor_id);
CREATE INDEX idx_ideas_category ON ideas(idea_category_id);
CREATE INDEX idx_ideas_deleted ON ideas(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_ideas_title_gin ON ideas USING GIN(to_tsvector('russian', title));
CREATE INDEX idx_ideas_description_gin ON ideas USING GIN(to_tsvector('russian', full_description));

-- Индексы для связующих таблиц
CREATE INDEX idx_actors_projects_actor ON actors_projects(actor_id);
CREATE INDEX idx_actors_projects_project ON actors_projects(project_id);
CREATE INDEX idx_actors_directions_actor ON actors_directions(actor_id);
CREATE INDEX idx_projects_directions_project ON projects_directions(project_id);
CREATE INDEX idx_projects_locations_project ON projects_locations(project_id);

-- Индексы для полнотекстового поиска в directions
CREATE INDEX idx_directions_title_gin ON directions USING GIN(to_tsvector('russian', title));
CREATE INDEX idx_directions_description_gin ON directions USING GIN(to_tsvector('russian', description));

-- Индексы для tasks
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_deleted ON tasks(deleted_at) WHERE deleted_at IS NULL;

-- Индексы для notifications
CREATE INDEX idx_notifications_recipient ON notifications(recipient);
CREATE INDEX idx_notifications_read ON notifications(is_read);
CREATE INDEX idx_notifications_created ON notifications(created_at);

-- ============================================
-- 11. ОПТИМИЗИРОВАННЫЕ ТРИГГЕРЫ
-- ============================================

-- Функция для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Создаем триггеры только для основных таблиц
CREATE TRIGGER update_actors_updated_at
BEFORE UPDATE ON actors
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at
BEFORE UPDATE ON projects
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ideas_updated_at
BEFORE UPDATE ON ideas
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_events_updated_at
BEFORE UPDATE ON events
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_persons_updated_at
BEFORE UPDATE ON persons
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organizations_updated_at
BEFORE UPDATE ON organizations
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_communities_updated_at
BEFORE UPDATE ON communities
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_templates_updated_at
BEFORE UPDATE ON templates
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at
BEFORE UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Функция для мягкого удаления
CREATE OR REPLACE FUNCTION soft_delete_record()
RETURNS TRIGGER AS $$
BEGIN
    NEW.deleted_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Функция для проверки уникальности среди неудаленных записей
CREATE OR REPLACE FUNCTION check_unique_for_active_records()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверяем уникальность email среди активных пользователей
    IF TG_TABLE_NAME = 'persons' AND NEW.email IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM persons 
            WHERE email = NEW.email 
            AND deleted_at IS NULL 
            AND actor_id != NEW.actor_id
        ) THEN
            RAISE EXCEPTION 'Email % уже используется', NEW.email;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Триггер для проверки уникальности email
CREATE TRIGGER check_persons_email_unique
BEFORE INSERT OR UPDATE ON persons
FOR EACH ROW
EXECUTE FUNCTION check_unique_for_active_records();

-- ============================================
-- 12. ЗАПОЛНЕНИЕ ТЕСТОВЫМИ ДАННЫМИ
-- ============================================

-- Вставляем тестовые данные для населенных пунктов
INSERT INTO locations (location_id, name, type, region, country, population) VALUES
(1, 'Москва', 'город', 'Москва', 'Россия', 12678079),
(2, 'Санкт-Петербург', 'город', 'Санкт-Петербург', 'Россия', 5398064),
(3, 'Улан-Удэ', 'город', 'Бурятия', 'Россия', 437565),
(4, 'Иркутск', 'город', 'Иркутская область', 'Россия', 617264),
(5, 'Кяхта', 'город', 'Бурятия', 'Россия', 20013)
ON CONFLICT DO NOTHING;

-- Вставляем тестового участника (администратора)
INSERT INTO actors (actor_id, nickname, actor_type_id, account, created_by, updated_by) 
VALUES (1, 'Администратор системы', 1, '000000000001', 1, 1)
ON CONFLICT DO NOTHING;

-- Вставляем тестовую персону
INSERT INTO persons (name, last_name, email, actor_id, created_by, updated_by)
VALUES ('Иван', 'Иванов', 'admin@example.com', 1, 1, 1)
ON CONFLICT DO NOTHING;

-- Вставляем тестовый проект
INSERT INTO projects (title, full_title, description, author_id, project_status_id, project_type_id, account, created_by, updated_by)
VALUES (
    'Театральный фестиваль',
    'Международный театральный фестиваль современного искусства',
    'Организация и проведение ежегодного театрального фестиваля',
    1, 1, 2, '000000000001', 1, 1
)
ON CONFLICT DO NOTHING;

-- ============================================
-- 13. ПРЕДСТАВЛЕНИЯ (VIEWS) ДЛЯ УДОБНЫХ ЗАПРОСОВ
-- ============================================

-- Представление для просмотра активных участников с детальной информацией
CREATE VIEW vw_active_actors_details AS
SELECT 
    a.actor_id,
    a.nickname,
    at.type as actor_type,
    p.name,
    p.last_name,
    p.email,
    p.phone_number,
    l.name as location_name,
    a.created_at
FROM actors a
LEFT JOIN actor_types at ON a.actor_type_id = at.actor_type_id
LEFT JOIN persons p ON a.actor_id = p.actor_id AND p.deleted_at IS NULL
LEFT JOIN locations l ON p.location_id = l.location_id
WHERE a.deleted_at IS NULL;

-- Представление для просмотра активных проектов с участниками
CREATE VIEW vw_active_projects_summary AS
SELECT 
    p.project_id,
    p.title,
    p.full_title,
    ps.status as project_status,
    pt.type as project_type,
    a.nickname as author_name,
    COUNT(DISTINCT ap.actor_id) as participants_count,
    p.start_date,
    p.end_date
FROM projects p
LEFT JOIN project_statuses ps ON p.project_status_id = ps.project_status_id
LEFT JOIN project_types pt ON p.project_type_id = pt.project_type_id
LEFT JOIN actors a ON p.author_id = a.actor_id AND a.deleted_at IS NULL
LEFT JOIN actors_projects ap ON p.project_id = ap.project_id
WHERE p.deleted_at IS NULL
GROUP BY p.project_id, ps.status, pt.type, a.nickname;

-- Представление для просмотра активных событий
CREATE VIEW vw_active_events_calendar AS
SELECT 
    e.event_id,
    e.title,
    e.description,
    e.date,
    e.start_time,
    e.end_time,
    et.type as event_type,
    COUNT(DISTINCT ae.actor_id) as participants_count,
    e.created_at
FROM events e
LEFT JOIN event_types et ON e.event_type_id = et.event_type_id
LEFT JOIN actors_events ae ON e.event_id = ae.event_id
WHERE e.deleted_at IS NULL
GROUP BY e.event_id, et.type;

-- Представление для поиска по всем сущностям
CREATE VIEW vw_global_search AS
SELECT 
    'actor' as entity_type,
    actor_id as id,
    nickname as title,
    keywords as content,
    created_at
FROM actors 
WHERE deleted_at IS NULL
UNION ALL
SELECT 
    'project' as entity_type,
    project_id as id,
    title,
    description as content,
    created_at
FROM projects 
WHERE deleted_at IS NULL
UNION ALL
SELECT 
    'idea' as entity_type,
    idea_id as id,
    title,
    full_description as content,
    created_at
FROM ideas 
WHERE deleted_at IS NULL
UNION ALL
SELECT 
    'event' as entity_type,
    event_id as id,
    title,
    description as content,
    created_at
FROM events 
WHERE deleted_at IS NULL;

-- ============================================
-- 14. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================

-- Функция для подсчета участников проекта
CREATE OR REPLACE FUNCTION get_project_participants_count(project_id_param INTEGER)
RETURNS INTEGER AS $$
DECLARE
    participants_count INTEGER;
BEGIN
    SELECT COUNT(DISTINCT actor_id) 
    INTO participants_count
    FROM actors_projects 
    WHERE project_id = project_id_param;
    
    RETURN COALESCE(participants_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Функция для получения актуального статуса участника
CREATE OR REPLACE FUNCTION get_actor_current_status(actor_id_param INTEGER)
RETURNS TABLE(status_name VARCHAR, status_date TIMESTAMPTZ) AS $$
BEGIN
    RETURN QUERY
    SELECT as2.status, acs.created_at
    FROM actor_current_statuses acs
    JOIN actor_statuses as2 ON acs.actor_status_id = as2.actor_status_id
    WHERE acs.actor_id = actor_id_param
    ORDER BY acs.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Функция для поиска по ключевым словам
CREATE OR REPLACE FUNCTION search_by_keywords(search_query TEXT)
RETURNS TABLE(
    entity_type VARCHAR,
    entity_id INTEGER,
    title VARCHAR,
    relevance REAL
) AS $$
BEGIN
    RETURN QUERY
    WITH search_results AS (
        -- Поиск в проектах
        SELECT 
            'project' as entity_type,
            project_id as entity_id,
            title,
            ts_rank(to_tsvector('russian', COALESCE(title, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(keywords, '')), 
                    plainto_tsquery('russian', search_query)) as relevance
        FROM projects 
        WHERE deleted_at IS NULL
        
        UNION ALL
        
        -- Поиск в участниках
        SELECT 
            'actor' as entity_type,
            actor_id as entity_id,
            nickname as title,
            ts_rank(to_tsvector('russian', COALESCE(nickname, '') || ' ' || COALESCE(keywords, '')), 
                    plainto_tsquery('russian', search_query)) as relevance
        FROM actors 
        WHERE deleted_at IS NULL
        
        UNION ALL
        
        -- Поиск в идеях
        SELECT 
            'idea' as entity_type,
            idea_id as entity_id,
            title,
            ts_rank(to_tsvector('russian', COALESCE(title, '') || ' ' || COALESCE(full_description, '')), 
                    plainto_tsquery('russian', search_query)) as relevance
        FROM ideas 
        WHERE deleted_at IS NULL
    )
    SELECT *
    FROM search_results
    WHERE relevance > 0
    ORDER BY relevance DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 15. ОТЧЕТЫ И СТАТИСТИКА
-- ============================================

-- Представление для статистики по проектам
CREATE VIEW vw_projects_statistics AS
SELECT 
    EXTRACT(YEAR FROM p.created_at) as year,
    EXTRACT(MONTH FROM p.created_at) as month,
    pt.type as project_type,
    ps.status as project_status,
    COUNT(*) as projects_count,
    SUM(get_project_participants_count(p.project_id)) as total_participants,
    AVG(get_project_participants_count(p.project_id)) as avg_participants
FROM projects p
JOIN project_types pt ON p.project_type_id = pt.project_type_id
JOIN project_statuses ps ON p.project_status_id = ps.project_status_id
WHERE p.deleted_at IS NULL
GROUP BY GROUPING SETS (
    (EXTRACT(YEAR FROM p.created_at)),
    (EXTRACT(YEAR FROM p.created_at), EXTRACT(MONTH FROM p.created_at)),
    (pt.type),
    (ps.status),
    (EXTRACT(YEAR FROM p.created_at), pt.type, ps.status)
);

-- Представление для активности участников
CREATE VIEW vw_actors_activity AS
SELECT 
    a.actor_id,
    a.nickname,
    COUNT(DISTINCT p.project_id) as projects_count,
    COUNT(DISTINCT i.idea_id) as ideas_count,
    COUNT(DISTINCT e.event_id) as events_attended,
    MAX(p.created_at) as last_project_date,
    MAX(i.created_at) as last_idea_date
FROM actors a
LEFT JOIN projects p ON a.actor_id = p.author_id AND p.deleted_at IS NULL
LEFT JOIN ideas i ON a.actor_id = i.actor_id AND i.deleted_at IS NULL
LEFT JOIN actors_events ae ON a.actor_id = ae.actor_id
LEFT JOIN events e ON ae.event_id = e.event_id AND e.deleted_at IS NULL
WHERE a.deleted_at IS NULL
GROUP BY a.actor_id, a.nickname;

-- ============================================
-- 16. АРХИВАЦИЯ И ОЧИСТКА
-- ============================================

-- Функция для архивации старых записей
CREATE OR REPLACE FUNCTION archive_old_records(months_old INTEGER)
RETURNS INTEGER AS $$
DECLARE
    archived_count INTEGER;
BEGIN
    -- Архивируем старые завершенные проекты
    UPDATE projects 
    SET deleted_at = CURRENT_TIMESTAMP
    WHERE deleted_at IS NULL 
    AND project_status_id = 6 
    AND end_date < CURRENT_DATE - (months_old || ' months')::INTERVAL;
    
    GET DIAGNOSTICS archived_count = ROW_COUNT;
    
    RETURN archived_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- СООБЩЕНИЕ ОБ УСПЕШНОМ СОЗДАНИИ
-- ============================================

DO $$
DECLARE
    tables_count INTEGER;
    indexes_count INTEGER;
    views_count INTEGER;
BEGIN
    -- Подсчет объектов
    SELECT COUNT(*) INTO tables_count 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_type = 'BASE TABLE';
    
    SELECT COUNT(*) INTO indexes_count 
    FROM pg_indexes 
    WHERE schemaname = 'public';
    
    SELECT COUNT(*) INTO views_count 
    FROM information_schema.views 
    WHERE table_schema = 'public';
    
    RAISE NOTICE 'База данных успешно создана и оптимизирована!';
    RAISE NOTICE 'Количество таблиц: %', tables_count;
    RAISE NOTICE 'Количество индексов: %', indexes_count;
    RAISE NOTICE 'Количество представлений: %', views_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Основные улучшения:';
    RAISE NOTICE '  • Мягкое удаление (soft delete) для всех основных сущностей';
    RAISE NOTICE '  • Оптимизированные индексы для полнотекстового поиска';
    RAISE NOTICE '  • Каскадные ограничения для целостности данных';
    RAISE NOTICE '  • Проверки валидности данных (email, даты, телефоны)';
    RAISE NOTICE '  • Только основные триггеры для обновления updated_at';
    RAISE NOTICE '';
    RAISE NOTICE 'Тестовый аккаунт создан:';
    RAISE NOTICE '  Логин: admin@example.com';
    RAISE NOTICE '  Аккаунт: 000000000001';
END $$;
