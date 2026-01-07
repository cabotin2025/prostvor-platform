<?php
// ============================================
// PROSTVOR PLATFORM - УНИВЕРСАЛЬНЫЙ МАРШРУТИЗАТОР
// Версия 2.0 - Полная поддержка существующего фронтенда
// ============================================

// Для разработки - показываем ошибки
error_reporting(E_ALL);
ini_set('display_errors', 1);

// ============================================
// 1. ОСНОВНЫЕ НАСТРОЙКИ И КОНСТАНТЫ
// ============================================
define('APP_ROOT', __DIR__);
define('PUBLIC_DIR', APP_ROOT);
define('API_DIR', APP_ROOT . '/api');

// ============================================
// 2. CORS И БАЗОВЫЕ ЗАГОЛОВКИ
// ============================================
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, PATCH");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept, Origin");
header("Access-Control-Allow-Credentials: true");
header("Access-Control-Max-Age: 3600");

// Обработка preflight запросов
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// ============================================
// 3. ПОЛУЧЕНИЕ ПАРАМЕТРОВ ЗАПРОСА
// ============================================
$request_uri = $_SERVER['REQUEST_URI'];
$request_method = $_SERVER['REQUEST_METHOD'];

// Получаем чистый путь
$parsed_url = parse_url($request_uri);
$path = $parsed_url['path'] ?? '/';
$query = $parsed_url['query'] ?? '';

// Убираем начальный и конечный слэши
$path = trim($path, '/');

// Логирование для отладки
if (isset($_GET['debug'])) {
    error_log("[{$request_method}] /{$path}" . ($query ? "?{$query}" : ""));
}

// ============================================
// 4. СПИСОК ФАЙЛОВ, КОТОРЫЕ СУЩЕСТВУЮТ В ФРОНТЕНДЕ
// (из вашего репозитория)
// ============================================
$existing_frontend_files = [
    // Главные файлы
    '' => 'index.html',
    'index.html' => 'index.html',
    'index' => 'index.html',
    
    // Страницы
    'pages/Ideas.html' => 'pages/Ideas.html',
    'pages/ProjectKanban.html' => 'pages/ProjectKanban.html',
    'pages/ProjectMain.html' => 'pages/ProjectMain.html',
    'pages/ProjectMedia.html' => 'pages/ProjectMedia.html',
    'pages/Projects.html' => 'pages/Projects.html',
    'pages/RecoveryPass.html' => 'pages/RecoveryPass.html',
    'pages/actors.html' => 'pages/actors.html',
    'pages/enter-reg.html' => 'pages/enter-reg.html',
    
    // API тестовые страницы
    'test-simple.html' => 'test-simple.html',
    'test-static.html' => 'test-static.html',
    
    // CSS файлы
    'css/style.css' => 'css/style.css',
    
    // JS файлы
    'js/auth-updated.js' => 'js/auth-updated.js',
    'js/actors-database.js' => 'js/actors-database.js',
    'js/check-auth.js' => 'js/check-auth.js',
    'js/communications-icons.js' => 'js/communications-icons.js',
    'js/functions-database.js' => 'js/functions-database.js',
    'js/locacity-database.js' => 'js/locacity-database.js',
    'js/main-updated.js' => 'js/main-updated.js',
    'js/messages-manager.js' => 'js/messages-manager.js',
    'js/notes-manager.js' => 'js/notes-manager.js',
    'js/notifications-database.js' => 'js/notifications-database.js',
    'js/notifications-panel.js' => 'js/notifications-panel.js',
    'js/projects-database.js' => 'js/projects-database.js',
    'js/projects-main.js' => 'js/projects-main.js',
    'js/ratings-manager.js' => 'js/ratings-manager.js',
    'js/resources-database.js' => 'js/resources-database.js',
    'js/tasks-base.js' => 'js/tasks-base.js',
    'js/tasks-database.js' => 'js/tasks-database.js',
    'js/tasks-panel-updated.js' => 'js/tasks-panel-updated.js',
    
    // API сервис
    'js/api-service.js' => 'js/api-service.js',
];

// ============================================
// 5. ПРОВЕРКА И ОТДАЧА СТАТИЧЕСКИХ ФАЙЛОВ
// ============================================
// Если запрос к известному фронтенд-файлу
if (isset($existing_frontend_files[$path])) {
    $file_to_serve = $existing_frontend_files[$path];
    $file_path = PUBLIC_DIR . '/' . $file_to_serve;
    
    if (file_exists($file_path)) {
        serveStaticFile($file_path);
        exit;
    }
}

// Также проверяем прямое существование файла
if ($path && file_exists(PUBLIC_DIR . '/' . $path)) {
    serveStaticFile(PUBLIC_DIR . '/' . $path);
    exit;
}

// ============================================
// 6. API МАРШРУТИЗАЦИЯ
// ============================================
// Все запросы, начинающиеся с /api/ обрабатываем как API
if (strpos($path, 'api/') === 0) {
    // Устанавливаем JSON заголовки для API
    header('Content-Type: application/json; charset=utf-8');
    
    // Подключаем зависимости
    if (file_exists(APP_ROOT . '/vendor/autoload.php')) {
        require_once APP_ROOT . '/vendor/autoload.php';
    }
    
    if (file_exists(APP_ROOT . '/config/database.php')) {
        require_once APP_ROOT . '/config/database.php';
    }
    
    // Убираем 'api/' из пути для маршрутизации
    $api_path = substr($path, 4); // Убираем 'api/'
    
    // Определяем маршруты API
    $api_routes = [
        'GET' => [
            '' => 'handle_api_root',
            'test' => 'handle_api_test',
            'debug' => 'handle_api_debug',
            'projects' => 'api/projects/index.php',
            'actors' => 'api/actors/index.php',
            'test-auth' => 'handle_test_auth',
        ],
        'POST' => [
            'auth/login' => 'api/auth/login.php',
            'auth/register' => 'api/auth/register.php',
            'auth/logout' => 'handle_api_logout',
            'projects' => 'api/projects/create.php',
            'projects/create' => 'api/projects/create.php',
        ],
        'PUT' => [
            'projects/{id}' => 'api/projects/update.php',
            'actors/{id}' => 'api/actors/update.php',
        ],
        'DELETE' => [
            'projects/{id}' => 'api/projects/delete.php',
            'actors/{id}' => 'api/actors/delete.php',
        ]
    ];
    
    // Обрабатываем API запрос
    handle_api_request($request_method, $api_path, $api_routes);
    exit;
}

// ============================================
// 7. КОРНЕВОЙ ENDPOINT (GET /)
// ============================================
if ($path === '' || $path === 'index.php') {
    // Если запросили корень - отдаем index.html
    if (file_exists(PUBLIC_DIR . '/index.html')) {
        serveStaticFile(PUBLIC_DIR . '/index.html');
    } else {
        // Или показываем информацию об API
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'app' => 'Prostvor Platform API',
            'version' => '2.0',
            'status' => 'running',
            'frontend' => 'Available at /index.html',
            'api_endpoints' => [
                'GET /api/test' => 'Test endpoint',
                'GET /api/debug' => 'System information',
                'POST /api/auth/login' => 'Authentication',
                'GET /api/projects' => 'Projects list (requires auth)',
                'GET /api/actors' => 'Actors list (requires auth)'
            ],
            'static_files' => 'All frontend files are served directly'
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    }
    exit;
}

// ============================================
// 8. ЕСЛИ НИЧЕГО НЕ ПОДОШЛО - 404
// ============================================
http_response_code(404);

// Пробуем отдать 404.html если существует
if (file_exists(PUBLIC_DIR . '/404.html')) {
    serveStaticFile(PUBLIC_DIR . '/404.html');
} else {
    // Или JSON ошибку для API-like запросов
    if (strpos($path, 'api/') === 0 || strpos($_SERVER['HTTP_ACCEPT'] ?? '', 'application/json') !== false) {
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'error' => 'Not Found',
            'message' => 'The requested resource was not found on this server.',
            'path' => '/' . $path,
            'method' => $request_method,
            'timestamp' => date('c')
        ], JSON_UNESCAPED_UNICODE);
    } else {
        // Или простой HTML для браузера
        echo '<!DOCTYPE html>
        <html>
        <head><title>404 Not Found</title></head>
        <body>
            <h1>404 - Страница не найдена</h1>
            <p>Запрошенный ресурс <strong>/' . htmlspecialchars($path) . '</strong> не существует.</p>
            <p><a href="/">Вернуться на главную</a></p>
        </body>
        </html>';
    }
}
exit;

// ============================================
// ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ============================================

/**
 * Отдает статический файл с правильным Content-Type
 */
function serveStaticFile($file_path) {
    if (!file_exists($file_path)) {
        http_response_code(404);
        echo 'File not found';
        return;
    }
    
    $extension = strtolower(pathinfo($file_path, PATHINFO_EXTENSION));
    
    $mime_types = [
        // HTML
        'html' => 'text/html; charset=utf-8',
        'htm' => 'text/html; charset=utf-8',
        
        // CSS
        'css' => 'text/css; charset=utf-8',
        
        // JavaScript
        'js' => 'application/javascript; charset=utf-8',
        'mjs' => 'application/javascript; charset=utf-8',
        
        // Изображения
        'png' => 'image/png',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'svg' => 'image/svg+xml',
        'webp' => 'image/webp',
        'ico' => 'image/x-icon',
        
        // Шрифты
        'woff' => 'font/woff',
        'woff2' => 'font/woff2',
        'ttf' => 'font/ttf',
        'eot' => 'application/vnd.ms-fontobject',
        
        // Другие
        'json' => 'application/json; charset=utf-8',
        'xml' => 'application/xml',
        'pdf' => 'application/pdf',
        'zip' => 'application/zip',
        'txt' => 'text/plain; charset=utf-8',
        'csv' => 'text/csv; charset=utf-8',
    ];
    
    // Устанавливаем Content-Type
    if (isset($mime_types[$extension])) {
        header('Content-Type: ' . $mime_types[$extension]);
    } else {
        // Бинарный файл по умолчанию
        header('Content-Type: application/octet-stream');
    }
    
    // Кэширование для статических файлов
    $cache_time = 3600 * 24 * 30; // 30 дней
    header('Cache-Control: public, max-age=' . $cache_time);
    header('Expires: ' . gmdate('D, d M Y H:i:s', time() + $cache_time) . ' GMT');
    header('Pragma: cache');
    
    // Отдаем файл
    readfile($file_path);
}

/**
 * Обработка API запросов
 */
function handle_api_request($method, $path, $routes) {
    // Проверяем наличие метода в маршрутах
    if (!isset($routes[$method])) {
        http_response_code(405);
        echo json_encode([
            'error' => 'Method Not Allowed',
            'message' => "Method {$method} not allowed for this endpoint",
            'allowed_methods' => array_keys($routes)
        ], JSON_UNESCAPED_UNICODE);
        return;
    }
    
    // Ищем точное совпадение
    if (isset($routes[$method][$path])) {
        $handler = $routes[$method][$path];
        execute_api_handler($handler);
        return;
    }
    
    // Ищем совпадение с параметрами (например, projects/{id})
    foreach ($routes[$method] as $route => $handler) {
        if (strpos($route, '{') !== false) {
            // Заменяем {id} на regex
            $pattern = preg_replace('/\{[^}]+\}/', '([^/]+)', $route);
            $pattern = str_replace('/', '\/', $pattern);
            
            if (preg_match('/^' . $pattern . '$/', $path, $matches)) {
                // Извлекаем параметры
                preg_match_all('/\{([^}]+)\}/', $route, $param_names);
                $params = [];
                
                for ($i = 0; $i < count($param_names[1]); $i++) {
                    $params[$param_names[1][$i]] = $matches[$i + 1] ?? null;
                }
                
                // Сохраняем параметры в GET для использования в обработчике
                foreach ($params as $key => $value) {
                    $_GET[$key] = $value;
                }
                
                execute_api_handler($handler);
                return;
            }
        }
    }
    
    // Если не нашли маршрут
    http_response_code(404);
    echo json_encode([
        'error' => 'Endpoint Not Found',
        'message' => "API endpoint '{$path}' not found",
        'method' => $method,
        'available_endpoints' => array_keys($routes[$method])
    ], JSON_UNESCAPED_UNICODE);
}

/**
 * Выполнение обработчика API
 */
function execute_api_handler($handler) {
    if (is_callable($handler)) {
        $handler();
    } elseif (is_string($handler)) {
        if ($handler === 'handle_api_root') {
            handle_api_root();
        } elseif ($handler === 'handle_api_test') {
            handle_api_test();
        } elseif ($handler === 'handle_api_debug') {
            handle_api_debug();
        } elseif ($handler === 'handle_test_auth') {
            handle_test_auth();
        } elseif ($handler === 'handle_api_logout') {
            handle_api_logout();
        } elseif (file_exists(APP_ROOT . '/' . $handler)) {
            require_once APP_ROOT . '/' . $handler;
        } else {
            http_response_code(500);
            echo json_encode([
                'error' => 'Internal Server Error',
                'message' => "Handler '{$handler}' not found"
            ], JSON_UNESCAPED_UNICODE);
        }
    } else {
        http_response_code(500);
        echo json_encode([
            'error' => 'Internal Server Error',
            'message' => 'Invalid handler configuration'
        ], JSON_UNESCAPED_UNICODE);
    }
}

// ============================================
// БАЗОВЫЕ ОБРАБОТЧИКИ API
// ============================================

/**
 * Корневой endpoint API
 */
function handle_api_root() {
    echo json_encode([
        'app' => 'Prostvor Platform API',
        'version' => '2.0',
        'status' => 'running',
        'timestamp' => date('Y-m-d H:i:s'),
        'documentation' => [
            'GET /api/test' => 'Test endpoint',
            'GET /api/debug' => 'System information',
            'POST /api/auth/login' => 'Authentication',
            'POST /api/auth/register' => 'Registration',
            'GET /api/projects' => 'Projects (requires auth)',
            'GET /api/actors' => 'Actors (requires auth)'
        ]
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
}

/**
 * Тестовый endpoint API
 */
function handle_api_test() {
    echo json_encode([
        'status' => 'success',
        'message' => 'Prostvor Platform API is working correctly!',
        'timestamp' => date('Y-m-d H:i:s'),
        'data' => [
            'server' => $_SERVER['SERVER_SOFTWARE'] ?? 'PHP Development Server',
            'php_version' => phpversion(),
            'memory_usage' => round(memory_get_usage(true) / 1024 / 1024, 2) . ' MB',
            'api_version' => '2.0'
        ]
    ], JSON_UNESCAPED_UNICODE);
}

/**
 * Debug информация
 */
function handle_api_debug() {
    echo json_encode([
        'server' => [
            'php_version' => phpversion(),
            'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'N/A',
            'request_method' => $_SERVER['REQUEST_METHOD'],
            'request_uri' => $_SERVER['REQUEST_URI'],
            'script_name' => $_SERVER['SCRIPT_NAME'] ?? 'N/A',
            'remote_addr' => $_SERVER['REMOTE_ADDR'] ?? 'N/A'
        ],
        'extensions' => [
            'pdo' => extension_loaded('pdo'),
            'pdo_pgsql' => extension_loaded('pdo_pgsql'),
            'json' => extension_loaded('json'),
            'openssl' => extension_loaded('openssl'),
            'mbstring' => extension_loaded('mbstring')
        ],
        'environment' => [
            'app_root' => APP_ROOT,
            'public_dir' => PUBLIC_DIR,
            'api_dir' => API_DIR,
            'composer_autoload' => file_exists(APP_ROOT . '/vendor/autoload.php') ? 'Available' : 'Not found',
            'database_config' => file_exists(APP_ROOT . '/config/database.php') ? 'Available' : 'Not found'
        ],
        'memory' => [
            'usage' => memory_get_usage(true),
            'peak_usage' => memory_get_peak_usage(true),
            'limit' => ini_get('memory_limit')
        ]
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
}

/**
 * Тест аутентификации
 */
function handle_test_auth() {
    // Проверяем авторизацию
    $headers = getallheaders();
    $auth_header = $headers['Authorization'] ?? $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    
    if (strpos($auth_header, 'Bearer ') === 0) {
        $token = substr($auth_header, 7);
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Token is present',
            'token_present' => true,
            'token_length' => strlen($token),
            'note' => 'Token validation requires JWT library'
        ], JSON_UNESCAPED_UNICODE);
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'No authorization token provided',
            'token_present' => false,
            'required_format' => 'Authorization: Bearer {token}'
        ], JSON_UNESCAPED_UNICODE);
    }
}

/**
 * Logout endpoint
 */
function handle_api_logout() {
    // В реальном приложении здесь была бы инвалидация токена
    echo json_encode([
        'status' => 'success',
        'message' => 'Logout successful (client should remove token)'
    ], JSON_UNESCAPED_UNICODE);
}