<?php
declare(strict_types=1);

use Swifs\Core\Router;

/** @var Router $router */

$router->get('/api/health', function () {
    echo json_encode([
        'status'  => 'ok',
        'service' => 'swifs',
        'version' => '0.3.0-ui',
        'time'    => gmdate('c'),
    ]);
});

$router->get('/api/feed', function () {
    echo json_encode([
        'posts' => [
            ['id' => 'p1', 'user' => 'alex', 'caption' => 'Chasing sunsets 🌅 #swifs', 'likes' => 124, 'time' => '2h'],
            ['id' => 'p2', 'user' => 'mia',  'caption' => 'Coffee & code ☕️💻',      'likes' => 89,  'time' => '5h'],
        ],
    ]);
});

$router->get('/api/explore', function () {
    echo json_encode([
        'tags'  => ['#swifs', '#sunsets', '#coffee', '#code', '#travel', '#fitness', '#food', '#art'],
        'users' => [
            ['username' => 'alex', 'followers' => 1200],
            ['username' => 'mia',  'followers' => 980],
            ['username' => 'leo',  'followers' => 5400],
            ['username' => 'zara', 'followers' => 320],
        ],
    ]);
});

$router->get('/api/notifications', function () {
    echo json_encode([
        'items' => [
            ['type' => 'like',    'from' => 'alex', 'time' => '10m'],
            ['type' => 'comment', 'from' => 'mia',  'time' => '1h'],
            ['type' => 'follow',  'from' => 'leo',  'time' => '2h'],
            ['type' => 'like',    'from' => 'zara', 'time' => '5h'],
        ],
    ]);
});

$router->get('/api/profile', function () {
    echo json_encode([
        'username'     => 'you',
        'display_name' => 'Your Name',
        'bio'          => 'Building Swifs 🚀',
        'followers'    => 0,
        'following'    => 0,
        'posts'        => 0,
    ]);
});
