// projects-database.js
const projectsDatabase = [
    {
        ProjectID: 1,
        ProgectName: "Театр на воде",
        ProgectNameFull: "Проект создания уникального водного театрального пространства 'АкваСцена'",
        ProjectDescription: "Создание инновационного театрального пространства на воде с использованием современных технологий и экологических материалов. Проект включает строительство плавучей сцены, зрительного зала на 300 мест и репетиционных помещений.",
        DirectionID: 1,
        ProjectType: "Некоммерческий",
        ProjectStatus: "В работе",
        ProjectStartDate: "2024-06-15",
        ProjectEndDate: "2025-12-31",
        RequiredFunds: 15000000.00,
        CollectedFunds: 3500000.00,
        ProjectManagerID: 101,
        RequiredFunctions: [1, 3, 5, 7],
        RequiredResources: [1, 4, 6, 8]
    },
    {
        ProjectID: 2,
        ProgectName: "Кинофестиваль Сибири",
        ProgectNameFull: "Международный кинофестиваль 'Сибирский экран'",
        ProjectDescription: "Проведение ежегодного международного кинофестиваля, посвящённого культуре и традициям Сибири. Фестиваль включает конкурсную программу, мастер-классы от известных режиссёров и кинопоказы под открытым небом.",
        DirectionID: 2,
        ProjectType: "Коммерческий",
        ProjectStatus: "Формирование",
        ProjectStartDate: "2024-09-01",
        ProjectEndDate: "2025-08-31",
        RequiredFunds: 8000000.00,
        CollectedFunds: 1500000.00,
        ProjectManagerID: 102,
        RequiredFunctions: [2, 4, 6, 8],
        RequiredResources: [2, 5, 7, 9]
    },
    {
        ProjectID: 3,
        ProgectName: "Стрит-арт фестиваль",
        ProgectNameFull: "Городской фестиваль уличного искусства 'УрбанКолор'",
        ProjectDescription: "Организация масштабного фестиваля уличного искусства, включающего создание муралов, граффити-баттлы, мастер-классы по стрит-арту и лекции о городской культуре.",
        DirectionID: 3,
        ProjectType: "Некоммерческий",
        ProjectStatus: "Проверка",
        ProjectStartDate: "2024-11-01",
        ProjectEndDate: "2025-06-30",
        RequiredFunds: 3000000.00,
        CollectedFunds: 500000.00,
        ProjectManagerID: 103,
        RequiredFunctions: [3, 5, 9, 10],
        RequiredResources: [3, 6, 10, 12]
    },
    {
        ProjectID: 4,
        ProgectName: "Музыкальный продюсер",
        ProgectNameFull: "Цифровая платформа для молодых музыкальных продюсеров 'SoundLab'",
        ProjectDescription: "Создание онлайн-платформы для обучения, сотрудничества и продвижения молодых музыкальных продюсеров. Включает виртуальную студию, библиотеку семплов и систему менторства.",
        DirectionID: 4,
        ProjectType: "Коммерческий",
        ProjectStatus: "Инициация",
        ProjectStartDate: "2024-12-01",
        ProjectEndDate: "2025-11-30",
        RequiredFunds: 5000000.00,
        CollectedFunds: 0.00,
        ProjectManagerID: 104,
        RequiredFunctions: [1, 4, 7, 11],
        RequiredResources: [4, 8, 11, 13]
    },
    {
        ProjectID: 5,
        ProgectName: "Танцевальный перформанс",
        ProgectNameFull: "Интерактивный танцевальный перформанс 'Город в движении'",
        ProjectDescription: "Создание серии уличных танцевальных перформансов, вовлекающих зрителей в процесс. Проект сочетает современный танец, технологические инсталляции и элементы импровизации.",
        DirectionID: 5,
        ProjectType: "Некоммерческий",
        ProjectStatus: "Согласование",
        ProjectStartDate: "2025-01-15",
        ProjectEndDate: "2025-10-15",
        RequiredFunds: 2500000.00,
        CollectedFunds: 300000.00,
        ProjectManagerID: 105,
        RequiredFunctions: [2, 6, 8, 12],
        RequiredResources: [5, 9, 12, 14]
    },
    {
        ProjectID: 6,
        ProgectName: "Кулинарный театр",
        ProgectNameFull: "Театрализованное кулинарное шоу 'Вкус искусства'",
        ProjectDescription: "Создание уникального формата, сочетающего театральное представление с кулинарным мастер-классом. Зрители становятся участниками процесса приготовления блюд в театральной атмосфере.",
        DirectionID: 6,
        ProjectType: "Коммерческий",
        ProjectStatus: "Завершён",
        ProjectStartDate: "2024-03-10",
        ProjectEndDate: "2024-08-20",
        RequiredFunds: 1800000.00,
        CollectedFunds: 1800000.00,
        ProjectManagerID: 106,
        RequiredFunctions: [3, 7, 10, 13],
        RequiredResources: [6, 10, 13, 15]
    },
    {
        ProjectID: 7,
        ProgectName: "Литературный клуб",
        ProgectNameFull: "Литературно-дискуссионный клуб 'Слово и смысл'",
        ProjectDescription: "Организация регулярных встреч для обсуждения современной литературы, поэтических вечеров и мастер-классов от известных писателей. Формат включает онлайн- и офлайн-мероприятия.",
        DirectionID: 7,
        ProjectType: "Некоммерческий",
        ProjectStatus: "В работе",
        ProjectStartDate: "2024-02-20",
        ProjectEndDate: "2025-02-20",
        RequiredFunds: 1200000.00,
        CollectedFunds: 800000.00,
        ProjectManagerID: 107,
        RequiredFunctions: [4, 8, 11, 14],
        RequiredResources: [7, 11, 14, 16]
    },
    {
        ProjectID: 8,
        ProgectName: "Фотопроект Сибирь",
        ProgectNameFull: "Документально-художественный фотопроект 'Сибирь: лица и пространства'",
        ProjectDescription: "Создание масштабной фотовыставки, посвящённой жителям Сибири и их взаимодействию с уникальной природной средой. Проект включает экспедиции по регионам и публикацию фотоальбома.",
        DirectionID: 8,
        ProjectType: "Некоммерческий",
        ProjectStatus: "Формирование",
        ProjectStartDate: "2024-10-01",
        ProjectEndDate: "2025-09-30",
        RequiredFunds: 2800000.00,
        CollectedFunds: 700000.00,
        ProjectManagerID: 108,
        RequiredFunctions: [5, 9, 12, 15],
        RequiredResources: [8, 12, 15, 17]
    }
];

// Направления творческой деятельности
const directionsDatabase = [
    { DirectionID: 1, DirectionName: "Театр и перформанс" },
    { DirectionID: 2, DirectionName: "Кино и видео" },
    { DirectionID: 3, DirectionName: "Изобразительное искусство" },
    { DirectionID: 4, DirectionName: "Музыка и звук" },
    { DirectionID: 5, DirectionName: "Танец и хореография" },
    { DirectionID: 6, DirectionName: "Литература и поэзия" },
    { DirectionID: 7, DirectionName: "Дизайн и архитектура" },
    { DirectionID: 8, DirectionName: "Фотография" },
    { DirectionID: 9, DirectionName: "Цифровое искусство" },
    { DirectionID: 10, DirectionName: "Ремёсла и народное искусство" }
];

// Месяцы для поиска
const months = [
    "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
    "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
];