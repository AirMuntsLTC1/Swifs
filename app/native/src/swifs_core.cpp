#include "swifs_core.h"
#include <cstdint>

int swifs_feed_score(int likes, int comments, int views, int age_minutes) {
    int64_t engagement = (int64_t)likes * 3 + (int64_t)comments * 5 + views;
    if (age_minutes < 1) age_minutes = 1;
    return (int)(engagement / (age_minutes + 1));
}

int swifs_comment_score(int likes, int replies, int age_minutes) {
    int64_t engagement = (int64_t)(likes * 2 + replies * 3) * 100;
    if (age_minutes < 1) age_minutes = 1;
    return (int)(engagement / (age_minutes + 1));
}

int swifs_hash_user(const char *username) {
    if (!username) return 0;
    uint32_t h = 2166136261u;
    for (const char *p = username; *p; ++p) {
        h ^= (uint8_t)*p;
        h *= 16777619u;
    }
    return (int)(h & 0x7FFFFFFF);
}

const char *swifs_core_version(void) { return "0.1.0"; }
