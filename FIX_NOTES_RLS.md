# Swifs: RLS, messages, shared posts, post viewer, video stories

## Order (Termux)
  cd ~/swifs && unzip -o ~/swifs_rls_media_fix.zip
  git add -A && git commit -m "RLS rewrite, messages, shared posts, video stories" && git push
  Then run supabase/migrations/20261114000002_rls_and_media_fix.sql in Supabase > SQL Editor (or: supabase db push --remote).

## Why messages and group creation failed
- Old policies combined with OR and some referenced tables in a way that broke group creation
  (the creator could not read a group right after making it).
- The app hid the real error ("Message didn't send"). Now the error text is shown.

## What changed
- RLS: every policy in public is replaced with one consistent set. Helper functions avoid policy recursion.
- Posts with no audience are public; blocked users are hidden on both sides.
- Uploads go to <your user id>/<post id>/..., matching the storage policy.
- Shared posts in chat: thumbnail, caption, username; tap slides into the post.
- Post viewer (Find, profiles, saved): heart, comment, share and bookmark, like the home feed.
- Video without a thumbnail shows a dark tile with a play icon, not a grey placeholder.
- Stories: picker includes videos (up to 15 s). Videos upload directly and play in the viewer.

## Known limits
- Video stories have no text or sticker layers yet, and the viewer still advances on its photo timer.
- Avatar upload is not implemented in the code, so avatars stay as they are.
- Old posts without a video thumbnail still show the dark tile, not a frame of the video.
