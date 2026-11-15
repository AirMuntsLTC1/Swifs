SWIFS: realtime + messages refresh fix

Changes (3 files, overwrite in place):
  app/lib/core/notifications/realtime_notification_service.dart
  app/lib/features/messages/messages_screen.dart
  app/lib/features/messages/thread_screen.dart

What changed
  1. Realtime: 'messages' is bound once per event type (it was counted twice).
  2. Realtime: a dropped connection retries after 3, 6, 12, 24, 48, then 60 seconds
     (was every 3 seconds, forever). The retry wait resets once connected.
  3. Realtime: 'resume' is sent only when a connection comes back after a drop or a
     foreground restart. Close events from our own shutdown are ignored.
  4. Messages list and chat threads rebuild only when what is shown actually changes.
     A reload with the same data does nothing. Ages ("3m") refresh once every 30 s,
     and only redraw when a label's text changes.
  5. Native notifications: no change needed. Phone and server already share the tag
     (message-<id>, activity-<id>), so one event shows once.

No database migration. No new packages.

Apply
  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-realtime-fix.zip
  git add -A
  git commit -m "Realtime: bounded retries, single message binding, rebuild only on change"
  git push
