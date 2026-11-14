<?php
declare(strict_types=1);

return [
    'app' => [
        'name'     => 'Swifs',
        'version'  => '0.3.0-ui',
        'env'      => getenv('APP_ENV') ?: 'development',
        'debug'    => (getenv('APP_DEBUG') ?: 'true') === 'true',
        'base_url' => getenv('APP_URL') ?: 'http://localhost:8000',
    ],
];


