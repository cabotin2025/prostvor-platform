@echo off
echo Prostvor Platform - Быстрый тест
echo.

cd /d C:\prostvor\prostvor-platform

echo 1. Проверка структуры...
if not exist "vendor\autoload.php" (
    echo ❌ vendor\autoload.php не найден
    goto error
)
if not exist "config\database.php" (
    echo ❌ config\database.php не найден
    goto error
)
if not exist "index.php" (
    echo ❌ index.php не найден
    goto error
)
echo ✅ Структура OK

echo.
echo 2. Проверка PHP расширений...
php -r "echo 'PHP: ' . phpversion() . '\n';"
php -r "echo 'PDO PostgreSQL: ' . (extension_loaded('pdo_pgsql') ? 'OK' : 'MISSING') . '\n';"

echo.
echo 3. Запуск теста БД...
echo Откройте: http://localhost:8001
start "" "http://localhost:8001"
php -S localhost:8001 test_db.php

:error
pause