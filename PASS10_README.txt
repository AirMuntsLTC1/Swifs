SWIFS FIX PASS 10: notifications show what really happened (unzip, then migrate)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass10.zip
  supabase db push --remote          (applies 20261115000002_notifications_truth.sql)
  git add -A
  git commit -m "Pass 10: notifications match real follows, likes and messages"
  git push

WHY "kurt_xgd started following you" KEPT APPEARING
  1. The screen labelled EVERY notification "started following you", whatever its type.
     Likes and comments looked like follows.
  2. The follow notification came from a database trigger that created a row for every
     follow it saw, and nothing removed it when the follow was no longer true.
  3. The row showed "Message", which the app only shows when YOU follow that person.
     So the follow row was real in the database.

WHAT CHANGED
  Database (new migration):
  - Removes only the old notification triggers on follows and messages. The follower
    count trigger is kept.
  - A new follow row creates one follow notification. Unfollowing removes it.
  - A direct message creates one message notification per sender, with a short preview.
    Group messages are not added here.
  - Deletes existing follow notifications for people who no longer follow you, and like
    notifications where the person no longer likes the post.
  App:
  - Each row shows the right sentence: liked your post, commented on your post,
    sent you a message, and so on.
  - Follow rows only appear while that person still follows you.
  - Message rows show a Message button that opens the chat.
  - Likes and comments show no button.
