#pragma once
#ifdef __cplusplus
extern "C" {
#endif

int  swifs_feed_score(int likes, int comments, int views, int age_minutes);
int  swifs_comment_score(int likes, int replies, int age_minutes);
int  swifs_hash_user(const char *username);
const char *swifs_core_version(void);

#ifdef __cplusplus
}
#endif
