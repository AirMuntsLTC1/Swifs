<?php
declare(strict_types=1);
namespace Swifs\Services;

class RankingService {
    // This matches your C++ swifs_feed_score function exactly
    public static function calculateScore(int $likes, int $comments, int $views, int $ageMinutes): int {
        $engagement = ($likes * 3) + ($comments * 5) + $views;
        if ($ageMinutes < 1) $ageMinutes = 1;
        return (int)($engagement / ($ageMinutes + 1));
    }
}

