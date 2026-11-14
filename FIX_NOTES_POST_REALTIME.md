# Swifs: posting, previews, realtime, notifications

## Install (Termux)
  cd ~/swifs && unzip -o ~/swifs_posting_realtime_fix.zip
  git add -A && git commit -m "Parallel uploads, shared media preview, realtime reconnect, notification dedupe" && git push
  Run supabase/migrations/20261114000004_notifications_cleanup.sql in the Supabase SQL Editor.

## Check 1: which triggers create duplicate notifications
The report does not include trigger definitions. Run this in the SQL Editor and send me the result:

  select event_object_table as table_name, trigger_name, event_manipulation, action_statement
  from information_schema.triggers
  where trigger_schema = 'public'
  order by 1, 2;

  select proname, prosrc from pg_proc
  where proname in ('swifly_on_follow','swifly_notify','swifly_on_message','swifly_on_message_notify',
                    'swifly_on_like','swifly_on_comment','swifly_on_save','swifly_on_post');

## Check 2: native notification wiring (in Termux)
  grep -rn "showNotification" ~/swifs/android/app/src
If this prints nothing, MainActivity was never wired, so no native notification can be shown.

## Check 3: realtime status
Realtime status is printed in the debug log ("Realtime status: ..."). If it reports channelError or timedOut repeatedly, the project's Realtime service or the publication is the problem.

## Duplicate source files to delete (migrations/ is the canonical copy)
  git rm supabase/schema.sql supabase/messages_setup.sql supabase/stories_setup.sql \
         supabase/comment_likes.sql supabase/user_settings.sql supabase/message_menu_setup.sql
  git commit -m "Remove duplicate SQL, keep migrations"
(schema.sql is out of date: it refers to follows.follower_id, which the live database does not have.)
