<?php
declare(strict_types=1);

use Swifs\Core\Router;
use Swifs\Services\RankingService;

/** @var Router $router */

$router->get('/api/health', function () {
    echo json_encode(['status' => 'ok', 'service' => 'swifs', 'version' => '0.3.0-ui', 'time' => gmdate('c')]);
});

$router->get('/api/feed', function () {
    // 1. Load Mock Data (Later, change this to your DB query)
    $posts = require __DIR__ . '/../mocks/feed.php';

    // 2. Pass through the C++ equivalent ranking logic
    usort($posts, function($a, $b) {
        $scoreA = RankingService::calculateScore($a['likes'], $a['comments'], $a['views'], $a['age_minutes']);
        $scoreB = RankingService::calculateScore($b['likes'], $b['comments'], $b['views'], $b['age_minutes']);
        return $scoreB <=> $scoreA;
    });

    echo json_encode(['posts' => $posts]);
});

$router->get('/api/explore', function () {
    echo json_encode(require __DIR__ . '/../mocks/explore.php');
});

$router->get('/api/notifications', function () {
    echo json_encode(require __DIR__ . '/../mocks/notifications.php');
});

$router->get('/api/profile', function () {
    echo json_encode(require __DIR__ . '/../mocks/profile.php');
});
$router->post('/api/like', function () {
    $input = json_decode(file_get_contents('php://input'), true);
    // Later: INSERT INTO likes (user_id, post_id) VALUES (...)
    echo json_encode(['status' => 'success', 'action' => 'like', 'post_id' => $input['post_id'] ?? null, 'score' => $input['score'] ?? 0]);
});

$router->post('/api/save', function () {
    $input = json_decode(file_get_contents('php://input'), true);
    echo json_encode(['status' => 'success', 'action' => 'save', 'post_id' => $input['post_id'] ?? null]);
});

$router->post('/api/follow', function () {
    $input = json_decode(file_get_contents('php://input'), true);
    echo json_encode(['status' => 'success', 'action' => 'follow', 'username' => $input['username'] ?? null]);
});
