# Swifs fix pack

## Why the app did not load
1. The feed asked Supabase for `posts.views`, a column the database does not have.
   PostgREST rejects the whole query, so the feed fell back to cache or stayed empty.
   Explore, hashtags, saved posts and profile posts had the same bug.
2. User profiles asked for `profiles.bio`, which did not exist.
3. Realtime started before anyone signed in, so it never ran after a login.
   It also only listened to notifications.
4. The feed loaded 50 posts at once, showed only the first photo of each post,
   and used one fixed 4:5 box for all media.

## What changed
- Database: `supabase/migrations/20261114000001_feed_realtime_fix.sql` adds the missing
  columns, indexes, the realtime publication for every table the app uses, and an
  `increment_post_views` function.
- Feed: 10 posts per page, newest first, loads more as you scroll, and hides blocked users.
- Photo posts: Instagram-style swipeable carousel with dots and a 1/N counter.
  Each post uses its real photo ratio, between 4:5 and 1.91:1.
  Up to 10 photos or videos per post, checked on the phone and before upload.
- Uploads: thumbnails and content types now match the bytes. Real width and height are saved.
  A failed upload removes the half-made post.
- Realtime: one `RealtimeHub` starts on sign-in and stops on sign-out. The feed refreshes
  when posts, media, likes, comments, saves, follows or profiles change.
- Loading: skeleton shimmers replace spinners on the feed, media placeholders and bottom loader.
  New widgets live in `app/lib/core/widgets/swifs_skeleton.dart`:
  `FeedSkeleton`, `GridSkeleton`, `ListRowsSkeleton`, `SkeletonBox`, `SwifsSkeletonBox`.
- Startup: the auth gate uses the current session on the first frame.

## Install in Termux
  cd ~/swifs
  unzip -o ~/swifs_fix.zip
  Paste supabase/migrations/20261114000001_feed_realtime_fix.sql into Supabase > SQL Editor > Run.
  git add -A
  git commit -m "Fix feed loading, realtime, carousel, skeletons"
  git push

Your `app/lib/core/config/supabase_config.dart` and `supabase/.temp/` are NOT in this zip,
so your keys and local settings are kept.

## Still to do (not in this pack)
- About 22 spinners remain in messages, comments, notifications, explore, search, stories and
  profile screens. Swap them with the skeletons above the same way (`FeedSkeleton`, `GridSkeleton`,
  `ListRowsSkeleton`).
- Only the home feed listens to realtime so far. Messages, comments, notifications, profile and
  explore can subscribe with `RealtimeHub.instance.changes.listen((table) { ... })`.
- The PHP backend under `backend/` is mock data and is not called by the app. Supabase is the live backend.
- Build with `flutter analyze` before the APK. The fixes were written without a Flutter toolchain here.
