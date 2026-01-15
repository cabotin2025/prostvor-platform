<?php
// api/test/simple.php - для отладки
header('Content-Type: application/json');

// Всегда возвращаем успех
echo json_encode([
    'success' => true,
    'message' => 'API работает',
    'timestamp' => time(),
    'data' => [
        'favorites_count' => 0,
        'ratings_count' => 0
    ]
]);
?>