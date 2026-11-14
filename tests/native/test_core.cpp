// Checks the C++ core against values worked out by hand (and the FNV-1a hashes checked with Python).
#include "swifs_core.h"
#include <cstdio>

static int failures = 0;

static void expect(long long actual, long long expected, const char *label) {
    if (actual != expected) {
        std::printf("FAIL %s: got %lld, expected %lld\n", label, actual, expected);
        ++failures;
    }
}

int main() {
    // Feed: (likes*3 + comments*5 + views) / (age + 1)
    expect(swifs_feed_score(124, 8, 1200, 120), 13, "feed alex post");   // 1612 / 121
    expect(swifs_feed_score(89, 12, 800, 300), 3, "feed mia post");      // 1127 / 301
    expect(swifs_feed_score(0, 0, 0, 0), 0, "feed empty");
    expect(swifs_feed_score(10, 0, 0, 0), 15, "feed age 0 counts as 1"); // 30 / 2

    // Comments: (likes*2 + replies*3) * 100 / (age + 1)
    expect(swifs_comment_score(2, 1, 60), 11, "comment with reply");     // 700 / 61
    expect(swifs_comment_score(0, 0, 5), 0, "comment no engagement");

    // FNV-1a hash of the username, top bit cleared
    expect(swifs_hash_user("alex"), 1705310533, "hash alex");
    expect(swifs_hash_user("you"), 1354289308, "hash you");
    expect(swifs_hash_user(""), 18652613, "hash empty");

    if (failures) {
        std::printf("%d failure(s)\n", failures);
        return 1;
    }
    std::printf("native core: all checks passed\n");
    return 0;
}
