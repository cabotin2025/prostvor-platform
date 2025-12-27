// cities-database.js - Полная база данных населённых пунктов России
const RussianCitiesDatabase = (function() {
    // Основная база данных населённых пунктов
    const settlements = {
        // Города-миллионники
        'million_cities': [
            { name: 'Москва', population: 12678079, region: 'Москва', type: 'город', latitude: 55.7558, longitude: 37.6173 },
            { name: 'Санкт-Петербург', population: 5398064, region: 'Санкт-Петербург', type: 'город', latitude: 59.9343, longitude: 30.3351 },
            { name: 'Новосибирск', population: 1625631, region: 'Новосибирская область', type: 'город', latitude: 55.0084, longitude: 82.9357 },
            { name: 'Екатеринбург', population: 1493749, region: 'Свердловская область', type: 'город', latitude: 56.8389, longitude: 60.6057 },
            { name: 'Казань', population: 1257391, region: 'Татарстан', type: 'город', latitude: 55.8304, longitude: 49.0661 },
            { name: 'Нижний Новгород', population: 1244254, region: 'Нижегородская область', type: 'город', latitude: 56.2965, longitude: 43.9361 },
            { name: 'Челябинск', population: 1202371, region: 'Челябинская область', type: 'город', latitude: 55.1644, longitude: 61.4368 },
            { name: 'Самара', population: 1164900, region: 'Самарская область', type: 'город', latitude: 53.1959, longitude: 50.1002 },
            { name: 'Омск', population: 1125695, region: 'Омская область', type: 'город', latitude: 54.9885, longitude: 73.3242 },
            { name: 'Ростов-на-Дону', population: 1137704, region: 'Ростовская область', type: 'город', latitude: 47.2357, longitude: 39.7015 },
            { name: 'Уфа', population: 1125691, region: 'Башкортостан', type: 'город', latitude: 54.7355, longitude: 55.9917 },
            { name: 'Красноярск', population: 1095284, region: 'Красноярский край', type: 'город', latitude: 56.0153, longitude: 92.8932 },
            { name: 'Воронеж', population: 1057681, region: 'Воронежская область', type: 'город', latitude: 51.672, longitude: 39.1843 },
            { name: 'Пермь', population: 1048005, region: 'Пермский край', type: 'город', latitude: 58.0105, longitude: 56.2502 },
            { name: 'Волгоград', population: 1015586, region: 'Волгоградская область', type: 'город', latitude: 48.708, longitude: 44.5133 }
        ],

        // Крупные города (500к - 1 млн)
        'large_cities': [
            { name: 'Саратов', population: 901361, region: 'Саратовская область', type: 'город', latitude: 51.5924, longitude: 45.9608 },
            { name: 'Краснодар', population: 932629, region: 'Краснодарский край', type: 'город', latitude: 45.0355, longitude: 38.9753 },
            { name: 'Тольятти', population: 699429, region: 'Самарская область', type: 'город', latitude: 53.5088, longitude: 49.4191 },
            { name: 'Ижевск', population: 646277, region: 'Удмуртия', type: 'город', latitude: 56.8527, longitude: 53.2115 },
            { name: 'Барнаул', population: 630877, region: 'Алтайский край', type: 'город', latitude: 53.3563, longitude: 83.7616 },
            { name: 'Ульяновск', population: 624518, region: 'Ульяновская область', type: 'город', latitude: 54.3142, longitude: 48.4031 },
            { name: 'Владивосток', population: 603519, region: 'Приморский край', type: 'город', latitude: 43.1155, longitude: 131.8855 },
            { name: 'Ярославль', population: 608353, region: 'Ярославская область', type: 'город', latitude: 57.6261, longitude: 39.8845 },
            { name: 'Иркутск', population: 617264, region: 'Иркутская область', type: 'город', latitude: 52.2864, longitude: 104.2807 },
            { name: 'Тюмень', population: 847488, region: 'Тюменская область', type: 'город', latitude: 57.153, longitude: 65.5343 },
            { name: 'Махачкала', population: 603518, region: 'Дагестан', type: 'город', latitude: 42.9849, longitude: 47.5047 },
            { name: 'Хабаровск', population: 617441, region: 'Хабаровский край', type: 'город', latitude: 48.4802, longitude: 135.0719 },
            { name: 'Оренбург', population: 572819, region: 'Оренбургская область', type: 'город', latitude: 51.7682, longitude: 55.0967 },
            { name: 'Новокузнецк', population: 537480, region: 'Кемеровская область', type: 'город', latitude: 53.7576, longitude: 87.136 },
            { name: 'Кемерово', population: 552546, region: 'Кемеровская область', type: 'город', latitude: 55.3547, longitude: 86.0873 },
            { name: 'Рязань', population: 539789, region: 'Рязанская область', type: 'город', latitude: 54.6269, longitude: 39.6916 },
            { name: 'Томск', population: 572740, region: 'Томская область', type: 'город', latitude: 56.4846, longitude: 84.9482 },
            { name: 'Астрахань', population: 524371, region: 'Астраханская область', type: 'город', latitude: 46.3479, longitude: 48.0336 },
            { name: 'Пенза', population: 523726, region: 'Пензенская область', type: 'город', latitude: 53.2007, longitude: 45.0046 },
            { name: 'Набережные Челны', population: 532074, region: 'Татарстан', type: 'город', latitude: 55.7436, longitude: 52.3959 },
            { name: 'Липецк', population: 511207, region: 'Липецкая область', type: 'город', latitude: 52.6088, longitude: 39.5992 },
            { name: 'Тула', population: 473622, region: 'Тульская область', type: 'город', latitude: 54.193, longitude: 37.6175 },
            { name: 'Киров', population: 501468, region: 'Кировская область', type: 'город', latitude: 58.6035, longitude: 49.668 },
            { name: 'Чебоксары', population: 489498, region: 'Чувашия', type: 'город', latitude: 56.1463, longitude: 47.2549 },
            { name: 'Калининград', population: 489735, region: 'Калининградская область', type: 'город', latitude: 54.7104, longitude: 20.4522 },
            { name: 'Брянск', population: 402675, region: 'Брянская область', type: 'город', latitude: 53.2434, longitude: 34.3642 },
            { name: 'Курск', population: 450977, region: 'Курская область', type: 'город', latitude: 51.7304, longitude: 36.1926 },
            { name: 'Иваново', population: 401505, region: 'Ивановская область', type: 'город', latitude: 57.0004, longitude: 40.9739 },
            { name: 'Магнитогорск', population: 410594, region: 'Челябинская область', type: 'город', latitude: 53.3835, longitude: 59.0314 },
            { name: 'Улан-Удэ', population: 437565, region: 'Бурятия', type: 'город', latitude: 51.8335, longitude: 107.5841 },
            { name: 'Тверь', population: 420065, region: 'Тверская область', type: 'город', latitude: 56.8587, longitude: 35.9176 },
            { name: 'Ставрополь', population: 454488, region: 'Ставропольский край', type: 'город', latitude: 45.0445, longitude: 41.9691 },
            { name: 'Белгород', population: 391554, region: 'Белгородская область', type: 'город', latitude: 50.5953, longitude: 36.5873 },
            { name: 'Сочи', population: 411524, region: 'Краснодарский край', type: 'город', latitude: 43.5855, longitude: 39.7231 }
        ],

        // Средние города (100к - 500к)
        'medium_cities': [
            { name: 'Нижний Тагил', population: 349008, region: 'Свердловская область', type: 'город', latitude: 57.9101, longitude: 59.9813 },
            { name: 'Владимир', population: 357024, region: 'Владимирская область', type: 'город', latitude: 56.129, longitude: 40.4066 },
            { name: 'Архангельск', population: 349742, region: 'Архангельская область', type: 'город', latitude: 64.5393, longitude: 40.5187 },
            { name: 'Калуга', population: 331842, region: 'Калужская область', type: 'город', latitude: 54.5138, longitude: 36.2612 },
            { name: 'Сургут', population: 396443, region: 'Ханты-Мансийский АО', type: 'город', latitude: 61.2541, longitude: 73.3962 },
            { name: 'Чита', population: 349005, region: 'Забайкальский край', type: 'город', latitude: 52.0339, longitude: 113.4994 },
            { name: 'Симферополь', population: 332317, region: 'Крым', type: 'город', latitude: 44.9521, longitude: 34.1024 },
            { name: 'Смоленск', population: 325495, region: 'Смоленская область', type: 'город', latitude: 54.7826, longitude: 32.0453 },
            { name: 'Волжский', population: 321479, region: 'Волгоградская область', type: 'город', latitude: 48.7858, longitude: 44.7797 },
            { name: 'Саранск', population: 318841, region: 'Мордовия', type: 'город', latitude: 54.1874, longitude: 45.1839 },
            { name: 'Череповец', population: 317970, region: 'Вологодская область', type: 'город', latitude: 59.1211, longitude: 37.9034 },
            { name: 'Курган', population: 309285, region: 'Курганская область', type: 'город', latitude: 55.441, longitude: 65.3411 },
            { name: 'Орёл', population: 308838, region: 'Орловская область', type: 'город', latitude: 52.9704, longitude: 36.0635 },
            { name: 'Вологда', population: 313944, region: 'Вологодская область', type: 'город', latitude: 59.2205, longitude: 39.8915 },
            { name: 'Якутск', population: 330615, region: 'Якутия', type: 'город', latitude: 62.0273, longitude: 129.732 },
            { name: 'Владикавказ', population: 295830, region: 'Северная Осетия', type: 'город', latitude: 43.0246, longitude: 44.6818 },
            { name: 'Мурманск', population: 287847, region: 'Мурманская область', type: 'город', latitude: 68.9707, longitude: 33.075 },
            { name: 'Подольск', population: 302831, region: 'Московская область', type: 'город', latitude: 55.4312, longitude: 37.5457 },
            { name: 'Тамбов', population: 289701, region: 'Тамбовская область', type: 'город', latitude: 52.7212, longitude: 41.4523 },
            { name: 'Стерлитамак', population: 280233, region: 'Башкортостан', type: 'город', latitude: 53.6303, longitude: 55.9316 },
            { name: 'Грозный', population: 291687, region: 'Чечня', type: 'город', latitude: 43.3178, longitude: 45.6949 },
            { name: 'Петрозаводск', population: 278551, region: 'Карелия', type: 'город', latitude: 61.789, longitude: 34.3597 },
            { name: 'Кострома', population: 277648, region: 'Костромская область', type: 'город', latitude: 57.7677, longitude: 40.9264 },
            { name: 'Нижневартовск', population: 278725, region: 'Ханты-Мансийский АО', type: 'город', latitude: 60.9397, longitude: 76.5694 },
            { name: 'Новороссийск', population: 273278, region: 'Краснодарский край', type: 'город', latitude: 44.7239, longitude: 37.7688 },
            { name: 'Йошкар-Ола', population: 266675, region: 'Марий Эл', type: 'город', latitude: 56.6344, longitude: 47.8999 },
            { name: 'Химки', population: 257128, region: 'Московская область', type: 'город', latitude: 55.8887, longitude: 37.4304 },
            { name: 'Таганрог', population: 248664, region: 'Ростовская область', type: 'город', latitude: 47.2095, longitude: 38.9351 },
            { name: 'Сыктывкар', population: 245083, region: 'Коми', type: 'город', latitude: 61.6688, longitude: 50.8354 },
            { name: 'Комсомольск-на-Амуре', population: 238505, region: 'Хабаровский край', type: 'город', latitude: 50.5503, longitude: 137.01 },
            { name: 'Нальчик', population: 239200, region: 'Кабардино-Балкария', type: 'город', latitude: 43.4853, longitude: 43.6071 },
            { name: 'Шахты', population: 226452, region: 'Ростовская область', type: 'город', latitude: 47.7085, longitude: 40.216 },
            { name: 'Дзержинск', population: 227326, region: 'Нижегородская область', type: 'город', latitude: 56.2376, longitude: 43.4597 },
            { name: 'Орск', population: 229255, region: 'Оренбургская область', type: 'город', latitude: 51.2293, longitude: 58.4752 },
            { name: 'Братск', population: 231602, region: 'Иркутская область', type: 'город', latitude: 56.1514, longitude: 101.6342 },
            { name: 'Энгельс', population: 227049, region: 'Саратовская область', type: 'город', latitude: 51.4855, longitude: 46.1268 },
            { name: 'Ангарск', population: 226374, region: 'Иркутская область', type: 'город', latitude: 52.5441, longitude: 103.919 },
            { name: 'Благовещенск', population: 241437, region: 'Амурская область', type: 'город', latitude: 50.2907, longitude: 127.5272 },
            { name: 'Старый Оскол', population: 223921, region: 'Белгородская область', type: 'город', latitude: 51.2981, longitude: 37.835 },
            { name: 'Великий Новгород', population: 225019, region: 'Новгородская область', type: 'город', latitude: 58.5256, longitude: 31.2743 },
            { name: 'Королёв', population: 225299, region: 'Московская область', type: 'город', latitude: 55.9163, longitude: 37.8545 },
            { name: 'Мытищи', population: 255429, region: 'Московская область', type: 'город', latitude: 55.9105, longitude: 37.7364 },
            { name: 'Псков', population: 209840, region: 'Псковская область', type: 'город', latitude: 57.8193, longitude: 28.3318 },
            { name: 'Люберцы', population: 207349, region: 'Московская область', type: 'город', latitude: 55.6784, longitude: 37.8937 },
            { name: 'Бийск', population: 200629, region: 'Алтайский край', type: 'город', latitude: 52.5393, longitude: 85.2139 },
            { name: 'Южно-Сахалинск', population: 200636, region: 'Сахалинская область', type: 'город', latitude: 46.9591, longitude: 142.738 },
            { name: 'Армавир', population: 187177, region: 'Краснодарский край', type: 'город', latitude: 44.9892, longitude: 41.1233 },
            { name: 'Рыбинск', population: 188678, region: 'Ярославская область', type: 'город', latitude: 58.0485, longitude: 38.8584 },
            { name: 'Прокопьевск', population: 194084, region: 'Кемеровская область', type: 'город', latitude: 53.8605, longitude: 86.7183 },
            { name: 'Северодвинск', population: 182077, region: 'Архангельская область', type: 'город', latitude: 64.5625, longitude: 39.8182 },
            { name: 'Абакан', population: 184769, region: 'Хакасия', type: 'город', latitude: 53.7226, longitude: 91.4435 },
            { name: 'Норильск', population: 182701, region: 'Красноярский край', type: 'город', latitude: 69.349, longitude: 88.201 },
            { name: 'Сызрань', population: 165725, region: 'Самарская область', type: 'город', latitude: 53.1558, longitude: 48.4745 },
            { name: 'Волгодонск', population: 171471, region: 'Ростовская область', type: 'город', latitude: 47.5164, longitude: 42.1984 },
            { name: 'Каменск-Уральский', population: 164192, region: 'Свердловская область', type: 'город', latitude: 56.4149, longitude: 61.9189 },
            { name: 'Златоуст', population: 164349, region: 'Челябинская область', type: 'город', latitude: 55.1713, longitude: 59.6726 },
            { name: 'Электросталь', population: 152607, region: 'Московская область', type: 'город', latitude: 55.7842, longitude: 38.4446 },
            { name: 'Альметьевск', population: 158429, region: 'Татарстан', type: 'город', latitude: 54.9014, longitude: 52.2971 },
            { name: 'Миасс', population: 151856, region: 'Челябинская область', type: 'город', latitude: 55.045, longitude: 60.1073 },
            { name: 'Керчь', population: 151996, region: 'Крым', type: 'город', latitude: 45.3561, longitude: 36.4674 },
            { name: 'Копейск', population: 147806, region: 'Челябинская область', type: 'город', latitude: 55.1166, longitude: 61.6181 },
            { name: 'Новочеркасск', population: 168766, region: 'Ростовская область', type: 'город', latitude: 47.4116, longitude: 40.1039 },
            { name: 'Батайск', population: 126988, region: 'Ростовская область', type: 'город', latitude: 47.1394, longitude: 39.7519 },
            { name: 'Кисловодск', population: 127521, region: 'Ставропольский край', type: 'город', latitude: 43.9052, longitude: 42.7168 },
            { name: 'Хасавюрт', population: 141259, region: 'Дагестан', type: 'город', latitude: 43.2505, longitude: 46.5852 },
            { name: 'Назрань', population: 122350, region: 'Ингушетия', type: 'город', latitude: 43.2167, longitude: 44.7664 },
            { name: 'Серпухов', population: 125473, region: 'Московская область', type: 'город', latitude: 54.9225, longitude: 37.4136 },
            { name: 'Димитровград', population: 116055, region: 'Ульяновская область', type: 'город', latitude: 54.2169, longitude: 49.6264 },
            { name: 'Майкоп', population: 143385, region: 'Адыгея', type: 'город', latitude: 44.6098, longitude: 40.1006 },
            { name: 'Одинцово', population: 180530, region: 'Московская область', type: 'город', latitude: 55.678, longitude: 37.2637 },
            { name: 'Нефтеюганск', population: 128159, region: 'Ханты-Мансийский АО', type: 'город', latitude: 61.0883, longitude: 72.6164 },
            { name: 'Новошахтинск', population: 108345, region: 'Ростовская область', type: 'город', latitude: 47.7579, longitude: 39.9364 },
            { name: 'Елец', population: 104349, region: 'Липецкая область', type: 'город', latitude: 52.6202, longitude: 38.5003 },
            { name: 'Реутов', population: 106990, region: 'Московская область', type: 'город', latitude: 55.7583, longitude: 37.8617 },
            { name: 'Железнодорожный', population: 103931, region: 'Московская область', type: 'город', latitude: 55.744, longitude: 38.0168 },
            { name: 'Кызыл', population: 116015, region: 'Тыва', type: 'город', latitude: 51.7191, longitude: 94.4378 },
            { name: 'Новомосковск', population: 125647, region: 'Тульская область', type: 'город', latitude: 54.0103, longitude: 38.2846 },
            { name: 'Уссурийск', population: 172942, region: 'Приморский край', type: 'город', latitude: 43.7973, longitude: 131.952 },
            { name: 'Сергиев Посад', population: 101756, region: 'Московская область', type: 'город', latitude: 56.3104, longitude: 38.1336 },
            { name: 'Арзамас', population: 104547, region: 'Нижегородская область', type: 'город', latitude: 55.3948, longitude: 43.8399 },
            { name: 'Элиста', population: 103749, region: 'Калмыкия', type: 'город', latitude: 46.308, longitude: 44.2558 },
            { name: 'Ногинск', population: 102267, region: 'Московская область', type: 'город', latitude: 55.8546, longitude: 38.4419 },
            { name: 'Орехово-Зуево', population: 118309, region: 'Московская область', type: 'город', latitude: 55.8039, longitude: 38.9818 },
            { name: 'Каспийск', population: 116340, region: 'Дагестан', type: 'город', latitude: 42.8917, longitude: 47.6367 },
            { name: 'Дербент', population: 123720, region: 'Дагестан', type: 'город', latitude: 42.0588, longitude: 48.29 },
            { name: 'Раменское', population: 114537, region: 'Московская область', type: 'город', latitude: 55.567, longitude: 38.2303 },
            { name: 'Обнинск', population: 115029, region: 'Калужская область', type: 'город', latitude: 55.0944, longitude: 36.6122 },
            { name: 'Октябрьский', population: 115557, region: 'Башкортостан', type: 'город', latitude: 54.4815, longitude: 53.471 },
            { name: 'Красногорск', population: 175812, region: 'Московская область', type: 'город', latitude: 55.8314, longitude: 37.3315 },
            { name: 'Климовск', population: 56138, region: 'Московская область', type: 'город', latitude: 55.3637, longitude: 37.5319 },
            { name: 'Черкесск', population: 116733, region: 'Карачаево-Черкесия', type: 'город', latitude: 44.2269, longitude: 42.0468 },
            { name: 'Муром', population: 109072, region: 'Владимирская область', type: 'город', latitude: 55.5764, longitude: 42.0426 },
            { name: 'Северск', population: 106648, region: 'Томская область', type: 'город', latitude: 56.6031, longitude: 84.8809 },
            { name: 'Ачинск', population: 105259, region: 'Красноярский край', type: 'город', latitude: 56.2684, longitude: 90.4992 },
            { name: 'Новотроицк', population: 87617, region: 'Оренбургская область', type: 'город', latitude: 51.203, longitude: 58.3267 },
            { name: 'Ессентуки', population: 113056, region: 'Ставропольский край', type: 'город', latitude: 44.0444, longitude: 42.8609 },
            { name: 'Домодедово', population: 152404, region: 'Московская область', type: 'город', latitude: 55.4364, longitude: 37.7666 },
            { name: 'Жуковский', population: 107560, region: 'Московская область', type: 'город', latitude: 55.5953, longitude: 38.1203 },
            { name: 'Геленджик', population: 80204, region: 'Краснодарский край', type: 'город', latitude: 44.5631, longitude: 38.079 },
            { name: 'Салехард', population: 50761, region: 'Ямало-Ненецкий АО', type: 'город', latitude: 66.5299, longitude: 66.6146 },
            { name: 'Минеральные Воды', population: 74112, region: 'Ставропольский край', type: 'город', latitude: 44.2089, longitude: 43.1385 },
            { name: 'Ленинск-Кузнецкий', population: 96139, region: 'Кемеровская область', type: 'город', latitude: 54.6605, longitude: 86.1736 },
            { name: 'Канск', population: 88871, region: 'Красноярский край', type: 'город', latitude: 56.2047, longitude: 95.7055 },
            { name: 'Находка', population: 139931, region: 'Приморский край', type: 'город', latitude: 42.824, longitude: 132.892 },
            { name: 'Кузнецк', population: 82276, region: 'Пензенская область', type: 'город', latitude: 53.1166, longitude: 46.6007 },
            { name: 'Киселевск', population: 87295, region: 'Кемеровская область', type: 'город', latitude: 54.006, longitude: 86.6367 },
            { name: 'Белово', population: 72402, region: 'Кемеровская область', type: 'город', latitude: 54.4224, longitude: 86.2978 },
            { name: 'Воткинск', population: 97471, region: 'Удмуртия', type: 'город', latitude: 57.0541, longitude: 53.9872 },
            { name: 'Гатчина', population: 94377, region: 'Ленинградская область', type: 'город', latitude: 59.5651, longitude: 30.1282 },
            { name: 'Мичуринск', population: 90451, region: 'Тамбовская область', type: 'город', latitude: 52.8913, longitude: 40.5105 },
            { name: 'Кстово', population: 66335, region: 'Нижегородская область', type: 'город', latitude: 56.1473, longitude: 44.1979 },
            { name: 'Тобольск', population: 100352, region: 'Тюменская область', type: 'город', latitude: 58.1981, longitude: 68.2536 },
            { name: 'Ухта', population: 92612, region: 'Коми', type: 'город', latitude: 63.5634, longitude: 53.6833 },
            { name: 'Серов', population: 94688, region: 'Свердловская область', type: 'город', latitude: 59.6047, longitude: 60.5787 },
            { name: 'Великие Луки', population: 90848, region: 'Псковская область', type: 'город', latitude: 56.3394, longitude: 30.5451 },
            { name: 'Будённовск', population: 60896, region: 'Ставропольский край', type: 'город', latitude: 44.7839, longitude: 44.1659 },
            { name: 'Балашов', population: 74057, region: 'Саратовская область', type: 'город', latitude: 51.5469, longitude: 43.1665 },
            { name: 'Юрга', population: 79693, region: 'Кемеровская область', type: 'город', latitude: 55.7251, longitude: 84.8991 },
            { name: 'Асбест', population: 57317, region: 'Свердловская область', type: 'город', latitude: 57.0053, longitude: 61.4589 },
            { name: 'Александров', population: 57053, region: 'Владимирская область', type: 'город', latitude: 56.3919, longitude: 38.7111 },
            { name: 'Лысьва', population: 60712, region: 'Пермский край', type: 'город', latitude: 58.0995, longitude: 57.8086 },
            { name: 'Ступино', population: 66942, region: 'Московская область', type: 'город', latitude: 54.8869, longitude: 38.0788 },
            { name: 'Туапсе', population: 61571, region: 'Краснодарский край', type: 'город', latitude: 44.0945, longitude: 39.0821 },
            { name: 'Кирово-Чепецк', population: 68626, region: 'Кировская область', type: 'город', latitude: 58.555, longitude: 50.0167 },
            { name: 'Павловский Посад', population: 65098, region: 'Московская область', type: 'город', latitude: 55.7807, longitude: 38.6596 },
            { name: 'Кропоткин', population: 75858, region: 'Краснодарский край', type: 'город', latitude: 45.4375, longitude: 40.5756 },
            { name: 'Лесосибирск', population: 61139, region: 'Красноярский край', type: 'город', latitude: 58.2218, longitude: 92.5035 },
            { name: 'Чайковский', population: 75856, region: 'Пермский край', type: 'город', latitude: 56.7686, longitude: 54.1148 },
            { name: 'Минусинск', population: 68007, region: 'Красноярский край', type: 'город', latitude: 53.7101, longitude: 91.6873 },
            { name: 'Бор', population: 76032, region: 'Нижегородская область', type: 'город', latitude: 56.3565, longitude: 44.0645 },
            { name: 'Балаково', population: 184466, region: 'Саратовская область', type: 'город', latitude: 52.0223, longitude: 47.7828 },
            { name: 'Щёлково', population: 134211, region: 'Московская область', type: 'город', latitude: 55.9249, longitude: 37.9724 },
            { name: 'Ревда', population: 60200, region: 'Свердловская область', type: 'город', latitude: 56.7987, longitude: 59.9071 },
            { name: 'Чапаевск', population: 70228, region: 'Самарская область', type: 'город', latitude: 52.9789, longitude: 49.7135 },
            { name: 'Зеленодольск', population: 99137, region: 'Татарстан', type: 'город', latitude: 55.8463, longitude: 48.5013 },
            { name: 'Славянск-на-Кубани', population: 63784, region: 'Краснодарский край', type: 'город', latitude: 45.2585, longitude: 38.1245 },
            { name: 'Долгопрудный', population: 120907, region: 'Московская область', type: 'город', latitude: 55.9387, longitude: 37.5201 },
            { name: 'Лобня', population: 88220, region: 'Московская область', type: 'город', latitude: 56.0322, longitude: 37.4614 },
            { name: 'Междуреченск', population: 96174, region: 'Кемеровская область', type: 'город', latitude: 53.6866, longitude: 88.0704 },
            { name: 'Анжеро-Судженск', population: 66583, region: 'Кемеровская область', type: 'город', latitude: 56.0787, longitude: 86.0203 },
            { name: 'Елабуга', population: 73630, region: 'Татарстан', type: 'город', latitude: 55.7567, longitude: 52.0544 },
            { name: 'Ишим', population: 65442, region: 'Тюменская область', type: 'город', latitude: 56.1128, longitude: 69.4902 },
            { name: 'Фрязино', population: 60580, region: 'Московская область', type: 'город', latitude: 55.9594, longitude: 38.045 },
            { name: 'Лениногорск', population: 60993, region: 'Татарстан', type: 'город', latitude: 54.5986, longitude: 52.4428 },
            { name: 'Троицк', population: 61466, region: 'Московская область', type: 'город', latitude: 55.4849, longitude: 37.3073 },
            { name: 'Бердск', population: 102608, region: 'Новосибирская область', type: 'город', latitude: 54.7582, longitude: 83.1077 },
            { name: 'Кстово', population: 66335, region: 'Нижегородская область', type: 'город', latitude: 56.1473, longitude: 44.1979 },
            { name: 'Ивантеевка', population: 76312, region: 'Московская область', type: 'город', latitude: 55.9712, longitude: 37.9208 },
            { name: 'Апатиты', population: 54926, region: 'Мурманская область', type: 'город', latitude: 67.5671, longitude: 33.3934 },
            { name: 'Усть-Илимск', population: 79570, region: 'Иркутская область', type: 'город', latitude: 58.0004, longitude: 102.6619 },
            { name: 'Снежинск', population: 50619, region: 'Челябинская область', type: 'город', latitude: 56.0852, longitude: 60.7325 },
            { name: 'Когалым', population: 61441, region: 'Ханты-Мансийский АО', type: 'город', latitude: 62.2655, longitude: 74.4791 },
            { name: 'Саров', population: 93357, region: 'Нижегородская область', type: 'город', latitude: 54.9228, longitude: 43.3448 },
            { name: 'Новый Уренгой', population: 118033, region: 'Ямало-Ненецкий АО', type: 'город', latitude: 66.0833, longitude: 76.6333 },
            { name: 'Ноябрьск', population: 100188, region: 'Ямало-Ненецкий АО', type: 'город', latitude: 63.2018, longitude: 75.4508 },
            { name: 'Железногорск', population: 82795, region: 'Красноярский край', type: 'город', latitude: 56.2529, longitude: 93.5321 },
            { name: 'Камчатский', population: 1795, region: 'Камчатский край', type: 'посёлок', latitude: 53.153, longitude: 158.381 }
        ],

        // Малые города и посёлки (до 100к)
        'small_settlements': [
            { name: 'Дубна', population: 74183, region: 'Московская область', type: 'город', latitude: 56.744, longitude: 37.1666 },
            { name: 'Пущино', population: 19778, region: 'Московская область', type: 'город', latitude: 54.8324, longitude: 37.621 },
            { name: 'Реж', population: 36578, region: 'Свердловская область', type: 'город', latitude: 57.3719, longitude: 61.3833 },
            { name: 'Верхняя Пышма', population: 71335, region: 'Свердловская область', type: 'город', latitude: 56.9675, longitude: 60.5828 },
            { name: 'Лесной', population: 49660, region: 'Свердловская область', type: 'город', latitude: 58.6348, longitude: 59.7985 },
            { name: 'Новоуральск', population: 80390, region: 'Свердловская область', type: 'город', latitude: 57.2472, longitude: 60.0957 },
            { name: 'Заречный', population: 28112, region: 'Свердловская область', type: 'город', latitude: 56.8103, longitude: 61.3254 },
            { name: 'Качканар', population: 37307, region: 'Свердловская область', type: 'город', latitude: 58.7053, longitude: 59.484 },
            { name: 'Краснотурьинск', population: 55875, region: 'Свердловская область', type: 'город', latitude: 59.7737, longitude: 60.1847 },
            { name: 'Кушва', population: 27305, region: 'Свердловская область', type: 'город', latitude: 58.2825, longitude: 59.7333 },
            { name: 'Лангепас', population: 42701, region: 'Ханты-Мансийский АО', type: 'город', latitude: 61.2537, longitude: 75.1808 },
            { name: 'Мегион', population: 52887, region: 'Ханты-Мансийский АО', type: 'город', latitude: 61.0319, longitude: 76.1025 },
            { name: 'Радужный', population: 43399, region: 'Ханты-Мансийский АО', type: 'город', latitude: 62.1343, longitude: 77.4584 },
            { name: 'Советский', population: 31138, region: 'Ханты-Мансийский АО', type: 'посёлок', latitude: 61.3706, longitude: 63.5661 },
            { name: 'Урай', population: 41315, region: 'Ханты-Мансийский АО', type: 'город', latitude: 60.1296, longitude: 64.804 },
            { name: 'Югорск', population: 38238, region: 'Ханты-Мансийский АО', type: 'город', latitude: 61.3122, longitude: 63.3367 },
            { name: 'Лабытнанги', population: 25501, region: 'Ямало-Ненецкий АО', type: 'город', latitude: 66.6597, longitude: 66.3836 },
            { name: 'Муравленко', population: 29269, region: 'Ямало-Ненецкий АО', type: 'город', latitude: 63.7949, longitude: 74.4948 },
            { name: 'Губкинский', population: 23340, region: 'Ямало-Ненецкий АО', type: 'город', latitude: 64.4343, longitude: 76.5026 },
            { name: 'Тарко-Сале', population: 20372, region: 'Ямало-Ненецкий АО', type: 'город', latitude: 64.9119, longitude: 77.7611 },
            { name: 'Анадырь', population: 13045, region: 'Чукотский АО', type: 'город', latitude: 64.7365, longitude: 177.474 },
            { name: 'Билибино', population: 5546, region: 'Чукотский АО', type: 'город', latitude: 68.0583, longitude: 166.444 },
            { name: 'Певек', population: 4015, region: 'Чукотский АО', type: 'город', latitude: 69.7008, longitude: 170.299 },
            { name: 'Мирный', population: 27292, region: 'Архангельская область', type: 'город', latitude: 62.764, longitude: 40.335 },
            { name: 'Няндома', population: 18473, region: 'Архангельская область', type: 'город', latitude: 61.6656, longitude: 40.2064 },
            { name: 'Онега', population: 16964, region: 'Архангельская область', type: 'город', latitude: 63.9164, longitude: 38.0875 },
            { name: 'Шенкурск', population: 4600, region: 'Архангельская область', type: 'город', latitude: 62.1056, longitude: 42.8997 },
            { name: 'Белозерск', population: 8375, region: 'Вологодская область', type: 'город', latitude: 60.0308, longitude: 37.7892 },
            { name: 'Вытегра', population: 10206, region: 'Вологодская область', type: 'город', latitude: 61.0059, longitude: 36.4481 },
            { name: 'Кириллов', population: 7735, region: 'Вологодская область', type: 'город', latitude: 59.8593, longitude: 38.381 },
            { name: 'Никольск', population: 7996, region: 'Вологодская область', type: 'город', latitude: 59.5353, longitude: 45.4556 },
            { name: 'Тотьма', population: 9785, region: 'Вологодская область', type: 'город', latitude: 59.9735, longitude: 42.7649 },
            { name: 'Устюжна', population: 8664, region: 'Вологодская область', type: 'город', latitude: 58.8384, longitude: 36.4415 },
            { name: 'Бабаево', population: 11599, region: 'Вологодская область', type: 'город', latitude: 59.3893, longitude: 35.9378 },
            { name: 'Белогорск', population: 66425, region: 'Амурская область', type: 'город', latitude: 50.9214, longitude: 128.473 },
            { name: 'Завитинск', population: 10614, region: 'Амурская область', type: 'город', latitude: 50.1075, longitude: 129.441 },
            { name: 'Зея', population: 23071, region: 'Амурская область', type: 'город', latitude: 53.7333, longitude: 127.267 },
            { name: 'Райчихинск', population: 17674, region: 'Амурская область', type: 'город', latitude: 49.7944, longitude: 129.411 },
            { name: 'Свободный', population: 53927, region: 'Амурская область', type: 'город', latitude: 51.3613, longitude: 128.121 },
            { name: 'Сковородино', population: 7057, region: 'Амурская область', type: 'город', latitude: 53.985, longitude: 123.943 },
            { name: 'Тында', population: 32269, region: 'Амурская область', type: 'город', latitude: 55.154, longitude: 124.724 },
            { name: 'Шимановск', population: 18163, region: 'Амурская область', type: 'город', latitude: 52.0053, longitude: 127.677 },
            { name: 'Архара', population: 7932, region: 'Амурская область', type: 'посёлок', latitude: 49.4206, longitude: 130.084 },
            { name: 'Белокуриха', population: 15061, region: 'Алтайский край', type: 'город', latitude: 51.9961, longitude: 84.9842 },
            { name: 'Горняк', population: 11608, region: 'Алтайский край', type: 'город', latitude: 50.9939, longitude: 81.4644 },
            { name: 'Змеиногорск', population: 10125, region: 'Алтайский край', type: 'город', latitude: 51.1579, longitude: 82.1873 },
            { name: 'Камень-на-Оби', population: 41807, region: 'Алтайский край', type: 'город', latitude: 53.7915, longitude: 81.3546 },
            { name: 'Славгород', population: 27905, region: 'Алтайский край', type: 'город', latitude: 53.0046, longitude: 78.6595 },
            { name: 'Яровое', population: 16424, region: 'Алтайский край', type: 'город', latitude: 52.9272, longitude: 78.582 },
            { name: 'Алейск', population: 28528, region: 'Алтайский край', type: 'город', latitude: 52.4921, longitude: 82.7794 },
            { name: 'Баргузин', population: 4578, region: 'Бурятия', type: 'посёлок', latitude: 53.6178, longitude: 109.634 },
            { name: 'Закаменск', population: 11330, region: 'Бурятия', type: 'город', latitude: 50.3727, longitude: 103.286 },
            { name: 'Кяхта', population: 20013, region: 'Бурятия', type: 'город', latitude: 50.3466, longitude: 106.447 },
            { name: 'Северобайкальск', population: 23265, region: 'Бурятия', type: 'город', latitude: 55.6356, longitude: 109.317 },
            { name: 'Бабушкин', population: 4368, region: 'Бурятия', type: 'город', latitude: 51.7125, longitude: 105.864 },
            { name: 'Гусиноозёрск', population: 23182, region: 'Бурятия', type: 'город', latitude: 51.2866, longitude: 106.523 },
            { name: 'Александровск-Сахалинский', population: 8854, region: 'Сахалинская область', type: 'город', latitude: 50.8975, longitude: 142.157 },
            { name: 'Долинск', population: 11796, region: 'Сахалинская область', type: 'город', latitude: 47.3256, longitude: 142.794 },
            { name: 'Корсаков', population: 33941, region: 'Сахалинская область', type: 'город', latitude: 46.6325, longitude: 142.779 },
            { name: 'Курильск', population: 2070, region: 'Сахалинская область', type: 'город', latitude: 45.2273, longitude: 147.88 },
            { name: 'Макаров', population: 6788, region: 'Сахалинская область', type: 'город', latitude: 48.6236, longitude: 142.78 },
            { name: 'Невельск', population: 10608, region: 'Сахалинская область', type: 'город', latitude: 46.6808, longitude: 141.863 },
            { name: 'Оха', population: 20391, region: 'Сахалинская область', type: 'город', latitude: 53.5739, longitude: 142.942 },
            { name: 'Поронайск', population: 16017, region: 'Сахалинская область', type: 'город', latitude: 49.2219, longitude: 143.096 },
            { name: 'Северо-Курильск', population: 2374, region: 'Сахалинская область', type: 'город', latitude: 50.6905, longitude: 156.124 },
            { name: 'Томари', population: 4313, region: 'Сахалинская область', type: 'город', latitude: 47.7658, longitude: 142.068 },
            { name: 'Углегорск', population: 8042, region: 'Сахалинская область', type: 'город', latitude: 49.0725, longitude: 142.033 },
            { name: 'Холмск', population: 25677, region: 'Сахалинская область', type: 'город', latitude: 47.0405, longitude: 142.041 },
            { name: 'Амдерма', population: 556, region: 'Ненецкий АО', type: 'посёлок', latitude: 69.7575, longitude: 61.6658 },
            { name: 'Нарьян-Мар', population: 23399, region: 'Ненецкий АО', type: 'город', latitude: 67.6381, longitude: 53.0069 },
            { name: 'Карабулак', population: 43037, region: 'Ингушетия', type: 'город', latitude: 43.3053, longitude: 44.9056 },
            { name: 'Малгобек', population: 36480, region: 'Ингушетия', type: 'город', latitude: 43.5087, longitude: 44.5903 },
            { name: 'Магас', population: 15256, region: 'Ингушетия', type: 'город', latitude: 43.1667, longitude: 44.8167 },
            { name: 'Аргун', population: 41622, region: 'Чечня', type: 'город', latitude: 43.2917, longitude: 45.8725 },
            { name: 'Гудермес', population: 64514, region: 'Чечня', type: 'город', latitude: 43.3507, longitude: 46.1033 },
            { name: 'Урус-Мартан', population: 63255, region: 'Чечня', type: 'город', latitude: 43.1256, longitude: 45.5419 },
            { name: 'Шали', population: 55654, region: 'Чечня', type: 'город', latitude: 43.1481, longitude: 45.9019 }
        ]
    };

    // Получить все населённые пункты
    function getAllSettlements() {
        const allSettlements = [];
        Object.values(settlements).forEach(category => {
            allSettlements.push(...category);
        });
        return allSettlements;
    }

    // Поиск населённого пункта по названию
    function findSettlementByName(name) {
        const allSettlements = getAllSettlements();
        return allSettlements.find(settlement => 
            settlement.name.toLowerCase() === name.toLowerCase()
        );
    }

    // Поиск населённых пунктов по региону
    function findSettlementsByRegion(region) {
        const allSettlements = getAllSettlements();
        return allSettlements.filter(settlement => 
            settlement.region.toLowerCase().includes(region.toLowerCase())
        );
    }

    // Получить населённые пункты по типу
    function getSettlementsByType(type) {
        const allSettlements = getAllSettlements();
        return allSettlements.filter(settlement => 
            settlement.type === type
        );
    }

    // Получить топ-N крупнейших городов
    function getTopCities(limit = 50) {
        const allSettlements = getAllSettlements();
        return allSettlements
            .filter(s => s.type === 'город')
            .sort((a, b) => b.population - a.population)
            .slice(0, limit);
    }

    // Поиск с автодополнением
    function searchSettlements(query, limit = 20) {
        const allSettlements = getAllSettlements();
        const lowerQuery = query.toLowerCase();
        
        return allSettlements
            .filter(settlement => 
                settlement.name.toLowerCase().includes(lowerQuery) ||
                settlement.region.toLowerCase().includes(lowerQuery)
            )
            .sort((a, b) => {
                // Приоритет точному совпадению по названию
                if (a.name.toLowerCase() === lowerQuery) return -1;
                if (b.name.toLowerCase() === lowerQuery) return 1;
                
                // Затем по населению
                return b.population - a.population;
            })
            .slice(0, limit);
    }

    // Получить города по федеральному округу
    function getCitiesByFederalDistrict(district) {
        const districts = {
            'central': ['Москва', 'Воронеж', 'Ярославль', 'Рязань', 'Липецк', 'Тула', 'Курск', 'Тверь', 'Иваново'],
            'northwest': ['Санкт-Петербург', 'Архангельск', 'Вологда', 'Калининград', 'Мурманск', 'Петрозаводск'],
            'south': ['Ростов-на-Дону', 'Краснодар', 'Сочи', 'Волгоград', 'Астрахань', 'Ставрополь'],
            'volga': ['Казань', 'Нижний Новгород', 'Самара', 'Уфа', 'Пермь', 'Саратов'],
            'ural': ['Екатеринбург', 'Челябинск', 'Тюмень', 'Магнитогорск'],
            'siberian': ['Новосибирск', 'Омск', 'Красноярск', 'Иркутск', 'Барнаул'],
            'far_eastern': ['Владивосток', 'Хабаровск', 'Якутск', 'Благовещенск']
        };

        const districtCities = districts[district] || [];
        return getAllSettlements().filter(settlement => 
            districtCities.includes(settlement.name)
        );
    }

    // Публичные методы
    return {
        getAllSettlements,
        findSettlementByName,
        findSettlementsByRegion,
        getSettlementsByType,
        getTopCities,
        searchSettlements,
        getCitiesByFederalDistrict,
        getAllCities: getAllSettlements,

        // Проверка, является ли строка валидным населённым пунктом
        isValidSettlement: function(name) {
            const allSettlements = getAllSettlements();
            return allSettlements.some(settlement => 
                settlement.name.toLowerCase() === name.toLowerCase()
            );
        }

        // Для обратной совместимости
        ,getAllCities: getAllSettlements
    };
})();