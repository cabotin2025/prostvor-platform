// Было:
if (!window.api) {
    console.error('API service not loaded!');
    return;
}

// Стало:
if (!window.prostvorAPI) {
    console.warn('ProstvorAPI не загружен, но продолжаем');
    // Можно продолжить без API
}